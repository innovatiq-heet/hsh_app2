# Prompt: Amenities Management (replaces Room Keys) — backend (`HAMS_WEB`)

> Paste everything below the line into the backend chat (repo `HAMS_WEB`, Node + Express + MySQL, TypeScript).

---

Build **Amenities Management**: a generic engine for every physical asset the hostel owns (keys, furniture, fans, lights, ACs, geysers, taps, coolers, routers, fire extinguishers, and anything added later). It replaces the Room Keys module, and every existing key must be migrated without losing data.

**Nothing may be hard-coded per kind of asset.** Categories and amenity types are rows the admin creates. A new kind (e.g. "Solar Panel" under Electrical) must work with no code change.

The Flutter app (`hsh_app2`) will be built against the contract in section 4. Implement it exactly. If you change a path, field, value or status code, list every change at the end of your reply.

Read `AGENTS.md` first and follow this repo's patterns:
- module layout: `src/modules/amenities/` with `amenities.routes.ts` and `amenities.service.ts`, split further if large;
- auth middleware, validation in the service, and the `{ success, data }` / `{ success, message }` responses;
- migrations in `src/config/db.ts` that tolerate re-runs;
- e2e tests in `tests/e2e/`.

The existing `src/modules/roomKeys/` is the closest example (batch create, actions, append-only logs).

## 0. Deliver in phases (one commit each, each fully working)

1. **Core:**
   - categories, types, locations;
   - individual assets and bulk stock, with assignments, returns, transfers and status changes;
   - lifecycle events and activity;
   - search and filters, the dashboard, student amenities;
   - Room Keys migration and the `/room-keys` adapter.
2. **Maintenance and attachments.**
3. **QR:** the by-code lookup is in phase 1. Phase 3 adds the label sheet and report-issue polish.

## 1. Rules (must hold)

1. **Access:** every endpoint uses `verifyOperator` (operator / platform-admin, i.e. admins and wardens). Everyone else gets `401` or `403`.
2. **Student identity:** numeric `students.id` only. Accept a positive integer without a leading zero; reject bank codes, `student_code`, `"0768"` and `HSH-…` with `400`. Assigning to a student needs an existing student. Warn but allow a student who is not an active resident; return `warning` in the reply.
3. **Append-only history:** `amenity_events` and closed assignments, maintenance records and attachments are never updated in place or deleted. Edits write an `edited` event with `{field: [old, new]}`. "Delete" means retire (assets) or deactivate (categories, types, locations). Attachments are soft-deleted.
4. **Audit:** every row stores `created_by_*` / `updated_by_*` (user id and name) taken from the token, never from the body. Every action writes one event in the **same transaction** as the change.
5. **Partial updates:** every `PUT` changes only the fields present.
6. **Stock never goes negative:** bulk assigns and moves lock the type's stock rows (`SELECT … FOR UPDATE`) inside a transaction, and refuse with `409` when not enough is available.
7. **Asset codes:** `HSH-<PREFIX>-<5 digits>`, for example `HSH-FAN-00124`.
   - **Numbering:** per prefix, from a counter row updated in the same transaction, so codes are never reused, even after retire.
   - **Prefix:** 2–6 characters `A–Z`/`0–9`, unique across types, and frozen once the type has assets.
8. **Money** is `DECIMAL(12,2)` and sent as a string (`"4500.00"`). **Calendar dates** (purchase, install, warranty, expected return) are `DATE` and sent as `YYYY-MM-DD`. **Timestamps** are ISO-8601 UTC.
9. **Validation:** clear `400` messages. Text limits: name 120, description and notes 1000, serial 80, vendor 120.

## 2. Tables (`src/config/db.ts`)

```text
amenity_categories   id, name (unique among active), description, icon (Material icon name, nullable), color (#RRGGBB, nullable),
                     sort_order, is_active, created_*/updated_* (at, by_user_id, by_name)
amenity_types        id, category_id, name, code_prefix (unique), description, tracking ENUM('individual','bulk'),
                     unit (e.g. pcs, set, pair), default_expected_life_months NULL, maintenance_interval_days NULL,
                     assignable_to_students BOOL, is_active, created_*/updated_*
amenity_code_counters prefix PK, last_number
amenity_locations    id, parent_id NULL, kind ENUM('building','wing','floor','room','area'), name, room_number NULL
                     (rooms only; normalized trimmed upper-case like room keys, unique among active rooms), sort_order, is_active, created_*/updated_*
amenity_assets       id, type_id, asset_code (unique), label NULL, serial_number NULL (not unique: door-key copies share a number),
                     status ENUM('active','issue_reported','inspection_required','under_repair','damaged','lost','retired'),
                     `condition` ENUM('new','good','fair','poor','unusable'), purchase_date, installation_date, purchase_cost,
                     vendor, warranty_expiry, expected_life_months, notes, home_location_id NULL (store / where it belongs),
                     legacy_room_key_id NULL UNIQUE, created_*/updated_*
amenity_stock_moves  id, type_id, quantity (>0), from_state NULL, to_state, -- states: available, assigned, under_repair, damaged, lost, retired
                     (NULL from_state = new stock), assignment_id NULL, unit_cost NULL, purchase_date NULL, vendor NULL, note, at, by_*
amenity_assignments  id, asset_id NULL | type_id NULL (bulk), quantity (1 for assets), student_id NULL | location_id NULL (exactly one),
                     room_number NULL (student's room when assigned), assigned_at, assigned_by_*, condition_at_assignment,
                     expected_return_date NULL, returned_quantity, closed_at NULL, closed_by_*, close_reason ENUM('returned','transferred','lost','damaged') NULL,
                     condition_at_return NULL, notes, return_note
amenity_events       id, asset_id NULL, type_id (always), assignment_id NULL, maintenance_id NULL,
                     event ENUM('created','purchased','installed','assigned','returned','transferred','status_changed','condition_changed',
                                'issue_reported','maintenance_started','maintenance_completed','edited','retired','found','stock_added','stock_moved','migrated'),
                     happened_on DATE NULL (may be backdated, e.g. purchase), data JSON (from/to, quantities, diffs), note, at, by_user_id, by_name
amenity_maintenance  id, asset_id NULL | type_id + quantity (bulk), issue, reported_by_name, reported_by_student_id NULL, reported_at,
                     location_id NULL (snapshot), technician, vendor, status ENUM('reported','inspection_required','in_progress','completed','unrepairable','cancelled'),
                     started_at NULL, completed_at NULL, cost DECIMAL(12,2) NULL, parts_replaced TEXT NULL, notes, created_*/updated_*
amenity_attachments  id, entity_type ENUM('asset','type','maintenance','assignment'), entity_id, kind ENUM('photo','invoice','warranty','manual','before','after','other'),
                     file_name, mime, size_bytes, storage_path, is_deleted, uploaded_at, uploaded_by_*
```

Index the columns you filter by: status, type, location, student, asset_code, serial_number and dates. An asset has **at most one open assignment**; enforce it in the service with a row lock.

## 3. Derived values (computed, never stored)

- **Asset placement:** `in_store` (no open assignment), `with_student`, or `installed` (open assignment to a location).
- **Bulk counts per type:** the sum of stock moves into each state minus the moves out. `total` is all states except `retired`.
- **Warranty:** `expired` (before today IST), `expiring` (within 30 days), `active`, or `none`.
- **Next maintenance due:** the last `maintenance_completed` (or the installation / purchase date) plus `maintenance_interval_days`. **Due** when that date is today or earlier.
- **Replacement due:** `installation_date` (else `purchase_date`) plus the expected life. Age is shown in months.
- **Asset value:** active assets' `purchase_cost`, plus bulk stock's `unit_cost × units` (not retired, damaged or lost).

## 4. API contract (`/api/amenities`)

Lists return `{ success, data: { items: [...], total, limit, offset } }` (default limit 50, max 200). Ids are numbers.

### Categories and types

- `GET /categories`: categories with `type_count`, `asset_count` (individual) and `bulk_units`. Add `?include_inactive=1` for inactive ones too.
- `POST /categories` `{name, description?, icon?, color?, sort_order?}`
- `PUT /categories/:id` (partial; `is_active` too). `DELETE /categories/:id` works only when no type uses it (`409` otherwise); use `is_active: false` instead.
- `GET /types?category_id=&include_inactive=1`, and `GET /types/:id` with its `inventory`.
- `POST /types` `{category_id, name, code_prefix, tracking, unit?, description?, default_expected_life_months?, maintenance_interval_days?, assignable_to_students?}`
- `PUT /types/:id` (partial; `code_prefix` only while the type has no assets, `409` otherwise; `tracking` never changes).

Type object:

```jsonc
{ "id": 4, "category_id": 1, "category_name": "Electrical", "name": "Ceiling Fan", "code_prefix": "FAN",
  "tracking": "individual", "unit": "pcs", "description": null, "default_expected_life_months": 120,
  "maintenance_interval_days": 180, "assignable_to_students": false, "is_active": true,
  "inventory": { "total": 340, "available": 12, "assigned": 0, "installed": 320, "issue_reported": 2, "inspection_required": 0,
                 "under_repair": 3, "damaged": 2, "lost": 1, "retired": 6, "value": "1530000.00",
                 "warranty_expiring": 4, "maintenance_due": 17 } }
```

For bulk types, `inventory` has `total, available, assigned, installed, under_repair, damaged, lost, retired, value`.

### Locations

- `GET /locations`: the whole tree, nested `children`, each node with `path` ("Pavitra House › Floor 2 › Room 204") and `asset_count`.
- `POST /locations` `{parent_id?, kind, name, room_number?}` and `PUT /locations/:id` (partial).
- `GET /locations/:id/amenities`:

```jsonc
{ "location": { "id": 33, "kind": "room", "name": "204", "room_number": "204", "path": "Hostel › Room 204" },
  "installed": [ assignment, … ],        // open assignments to this location (fans, lights, …)
  "home_assets": [ asset, … ],           // assets whose home is here and that are in store (e.g. spare keys in the office)
  "residents": [                         // rooms only: active residents whose room_number is this room
    { "student": { "id": 812, "name": "Dharmik Shah", "room": "204" }, "items": [ assignment, … ] } ] }
```

### Individual assets

- `GET /assets`, with these filters:
  - `search` (asset code, serial, label, type name, category name, student name, room)
  - `category_id`, `type_id`, `status`, `condition`, `placement`, `location_id` (includes everything under it), `room`
  - `student_id`, `warranty` (`expired|expiring|active|none`), `maintenance` (`due|open`)
  - `installed_from`, `installed_to`, `sort` (`code|newest|oldest|installed|cost`), `limit`, `offset`
- `POST /assets` `{type_id, count? (1–200), label?, serial_number?, purchase_date?, installation_date?, purchase_cost?, vendor?, warranty_expiry?, expected_life_months?, condition?, notes?, home_location_id?}`. Creates `count` assets with the next codes (`201`, `data: { items: [asset…] }`) and writes `created` and `purchased` events.
- `GET /assets/:id` returns the full asset (below).
- `GET /assets/by-code/:code` accepts `HSH-FAN-00124` in any letter case, or a QR payload that contains the code (see QR). It returns the same body, or `404`.
- `PUT /assets/:id` (partial: label, serial, dates, cost, vendor, warranty, expected life, notes, home location, condition) writes an `edited` event with the diff.
- `POST /assets/:id/status` `{status, condition?, note?}` follows these transitions:
  - any non-retired status can go to `issue_reported`, `inspection_required`, `under_repair`, `damaged`, `lost` or `active`;
  - `lost` can go to `active` (`found` event);
  - anything can go to `retired`, which closes an open assignment with `close_reason: lost|damaged` when relevant;
  - `retired` is final (`409`).
- `POST /assets/:id/assign` `{student_id | location_id, condition?, expected_return_date?, note?}` returns `409` if it already has an open assignment, is `lost`/`retired`, or the type isn't `assignable_to_students` (for a student).
- `POST /assets/:id/return` `{condition?, note?}` closes the open assignment (`returned`) and puts the asset back in the store.
- `POST /assets/:id/transfer` `{student_id | location_id, condition?, note?}` closes the open assignment and opens the new one atomically (`transferred` event with from/to).
- `GET /assets/:id/events`: the lifecycle, newest first, paged. Event object: `{ "id", "event", "happened_on" (YYYY-MM-DD or null), "at" (ISO), "by_name", "note", "data" (object), "assignment_id" }`.
- `GET /assets/:id/assignments`: all assignments of the asset, open first, then newest closed.

**Assignment object** (used by every list that returns assignments, including student amenities):

```jsonc
{ "id": 77, "assignment_id": 77,
  "asset": { "id": 124, "asset_code": "HSH-RKEY-00012", "type_id": 9, "type_name": "Room Key", "category_name": "Security / Keys",
             "label": "Copy 1", "serial_number": "204", "status": "active" },     // null for bulk
  "type": { "id": 9, "name": "Room Key", "unit": "pcs", "tracking": "individual" },
  "quantity": 1, "returned_quantity": 0,
  "student": { "id": 812, "name": "Dharmik Shah", "room": "204" },               // or null
  "location": null,                                                                // or { "id", "path" }
  "room_number": "204", "assigned_at": "…", "assigned_by_name": "Warden", "condition_at_assignment": "good",
  "expected_return_date": null, "notes": null,
  "closed_at": null, "closed_by_name": null, "close_reason": null, "condition_at_return": null, "return_note": null }
```

Asset object:

```jsonc
{ "id": 124, "asset_code": "HSH-FAN-00124", "type_id": 4, "type_name": "Ceiling Fan", "category_id": 1, "category_name": "Electrical",
  "label": null, "serial_number": "CF-889911", "status": "active", "condition": "good", "placement": "installed",
  "current_assignment": { "id": 77, "student": null, "location": { "id": 33, "path": "Pavitra House › Floor 2 › Room 204" },
                          "assigned_at": "2025-01-15T05:30:00.000Z", "condition_at_assignment": "new" },
  "home_location": null, "purchase_date": "2025-01-12", "installation_date": "2025-01-15", "purchase_cost": "4500.00",
  "vendor": "Shree Electricals", "warranty_expiry": "2027-01-12", "warranty": "active", "expected_life_months": 120,
  "replacement_due": "2035-01-15", "age_months": 22, "next_maintenance_due": "2026-12-01", "maintenance_due": false,
  "maintenance_count": 2, "maintenance_cost_total": "1050.00", "open_maintenance": null, "notes": null,
  "qr_payload": "https://<host>/a/HSH-FAN-00124",
  "created_at": "…", "created_by_name": "Super Admin", "updated_at": "…", "updated_by_name": "Warden" }
```

`student` (in an assignment) is `{ "id": 812, "name": "Dharmik Shah", "room": "204" }`.

### Bulk stock

- `POST /types/:id/stock` `{quantity, unit_cost?, purchase_date?, vendor?, note?}` adds available units (`stock_added`).
- `POST /types/:id/assign` `{student_id | location_id, quantity, condition?, expected_return_date?, note?}` returns `409` when `quantity` is more than `available`.
- `POST /types/:id/move` `{quantity, from, to, note?}` moves units between states, for example `available → under_repair`, or `under_repair → available` when repaired. Assigned units leave only through their assignment.
- `POST /assignments/:id/return` `{quantity? (bulk; default the rest), condition?, note?, to_state? ('available' default | 'damaged' | 'lost')}` can be partial for bulk, closing the assignment when nothing is left. It works for asset assignments too (same as `/assets/:id/return`).
- `GET /types/:id/assignments?open=1`: the type's assignments (bulk or individual).

### Students

- `GET /students/:studentId/amenities` returns the lists below, each item with `assignment_id`, `asset` (code, type, category) or `type` (bulk) and `quantity`, `assigned_at`, `condition_at_assignment`, `room_number`, `closed_at`, `close_reason` and `condition_at_return`:

```jsonc
{ "current": [ … ], "returned": [ … ], "lost_or_damaged": [ … ] }
```

### Maintenance (phase 2)

- `GET /maintenance?status=&asset_id=&type_id=&open=1&limit&offset`
- `POST /maintenance` `{asset_id | (type_id, quantity), issue, reported_by_name?, reported_by_student_id?, technician?, vendor?, notes?}` sets the asset to `issue_reported` and writes `issue_reported`.
- `PUT /maintenance/:id` (partial: status, technician, vendor, started_at, completed_at, cost, parts_replaced, notes). Allowed status steps:
  - `reported` → `inspection_required` → `in_progress` → `completed`
  - `completed` or `unrepairable`, then `cancelled`, end the job.

  The asset follows: `inspection_required` and `under_repair` while open; `active` on `completed` (`maintenance_completed` with cost); `damaged` on `unrepairable`; back to its earlier status on `cancelled`.
- `GET /assets/:id/maintenance` returns the records, newest first, plus `total_cost`.

### Attachments (phase 2)

- `POST /attachments` multipart: fields `entity_type`, `entity_id`, `kind`, and file `file`.
  - **File types:** jpg, png, webp or pdf, up to 10 MB. Check the real MIME type from the bytes, as the complaints upload does.
  - **Storage:** files go outside any public folder.
  - **Reply:** `201` with the attachment, including `url: "/api/amenities/attachments/<id>/file"`.
- `GET /attachments?entity_type=&entity_id=` and `GET /attachments/:id/file`, which needs the token (`Content-Type` set, inline).
- `DELETE /attachments/:id` is a soft delete.

### Activity and dashboard

- `GET /activity?asset_id=&type_id=&user=&limit&offset`: events with who and when (the admin "Activity" tab and the audit log).
- `GET /dashboard`:

```jsonc
{ "totals": { "assets": 1820, "bulk_units": 2400, "value": "2450000.00", "available": 130, "assigned": 780, "installed": 820,
              "issue_reported": 5, "under_repair": 9, "damaged": 14, "lost": 6, "retired": 40,
              "warranty_expiring": 11, "maintenance_due": 23, "open_maintenance": 12 },
  "categories": [ { "id": 1, "name": "Electrical", "icon": "bolt", "color": "#F59E0B", "assets": 340, "bulk_units": 0, "value": "…" } ] }
```

### QR

- **Payload:** the QR payload of an asset is `https://<API host>/a/<asset_code>`, so a web page can be added later.
- **Lookup:** `GET /assets/by-code/:code` takes the code, or any text containing `HSH-[A-Z0-9]{2,6}-\d{5}`.
- **Web page:** add `GET /a/:code`, which redirects to a simple "Open in the HSH app" page. Phase 3, optional.

## 5. Room Keys migration (phase 1, idempotent)

1. **Setup:** create category **Security / Keys**, type **Room Key** (`code_prefix` `RKEY`, individual, assignable to students) and type **Cupboard Key** (`CKEY`, individual, assignable).
2. **Rooms:** create a room location per distinct `room_keys.room_number` (under a building "Hostel" unless a building is chosen later), normalized as today.
3. **Each key:** every `room_keys` row without `legacy_room_key_id` becomes an asset.
   - **Fields:** type by `key_type`; `serial_number` = `key_number`; `label` and `notes` kept; `home_location_id` = its room.
   - **Status:**
     - `assigned` → `active` with an open student assignment. `assigned_at` is its latest `assigned` log time (else `updated_at`), `assigned_by` comes from that log, and `room_number` is the room.
     - `office` → `active`, in store.
     - `lost` → `lost`.
     - `is_deleted = 1` → `retired`.
4. **History:** every `room_key_logs` row becomes an `amenity_events` row with its original `created_at` and `by_*`. The mapping is created→created, edited→edited, assigned→assigned, returned→returned, lost→status_changed (to lost), found→found, deleted→retired. Each event also gets `data.legacy_log_id`.

   Earlier assignments in the logs (assigned … returned pairs) become **closed** assignments, so the student history shows them.
5. **Safety:** record each migrated key in `legacy_room_key_id`. Running it again changes nothing. **Do not modify or drop** `room_keys` / `room_key_logs`.
6. **Old app versions:** keep `/api/room-keys/*` working as an **adapter** over the new tables: same request and response shapes as today, mapped both ways. Reads come from the amenity assets of the two key types; writes (batch, update, actions, delete) go through the new engine and write events. Mark it deprecated in the docs.

## 6. Tests (`tests/e2e/amenities*.e2e.test.ts`)

- **Access:** non-operator → `401`/`403`. Student ids `"0768"`, `"HSH-1"` and `0` → `400`.
- **Codes:** creating 3 Fans gives `HSH-FAN-00001..3`. Retiring one and creating again gives `00004`, never a reused code. A prefix can't change once the type has assets.
- **Assignment:**
  - assign to a student, transfer to a location, then return: one open assignment at a time, two closed, events in order;
  - the student's `/amenities` shows current and returned;
  - assigning a `lost` or `retired` asset → `409`.
- **Bulk:** add 500 chairs, assign 420, move 10 to under_repair, then 5 to damaged. The counts are exactly 65 / 420 / 10 / 5. Assigning 100 more → `409`. Two parallel assigns can't oversell.
- **Edits:** `PUT` writes an `edited` event with the diff. Nothing is deleted.
- **Filters:** warranty expiring/expired, maintenance due, location subtree, search by code, serial, student and room.
- **Maintenance (phase 2):** the status flow, asset status following it, cost totals, and a bad transition → `409`.
- **Attachments (phase 2):** a PNG named `.pdf` is refused, as is a file over 10 MB. The file download needs the token.
- **Migration:**
  - a seeded set of keys and logs migrates exactly (counts, statuses, holders, history with original times);
  - running it twice changes nothing;
  - the `/room-keys` adapter returns the same shapes as before.
- **Dashboard:** totals match the seeded data.

Run `npm run check`. Update the docs and `AGENTS.md` (new module, the migration, the deprecated `/room-keys` adapter), then commit and deploy phase by phase.
