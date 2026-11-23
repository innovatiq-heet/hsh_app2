# Prompt: Amenities Management (replaces Rooms & Keys) — app (`hsh_app2`)

> Paste everything below the line into the app chat (repo `hsh_app2`, Flutter + GetX).

---

Build **Amenities Management** in the app: the hostel's central register of physical assets (keys, furniture, fans, lights, ACs, geysers, taps, coolers, routers, fire extinguishers, and anything the admin adds later). It **replaces the Rooms & Keys module**: the operator-console tile and its screens.

Read first:
- `AGENTS.md`, especially §4, student identity: numeric `students.id` only;
- `docs/AMENITIES_SPEC.md`, the product spec;
- `docs/AMENITIES_BACKEND_PROMPT.md`, the API contract, which is the source of truth for every path and field below.

The backend is `HAMS_WEB`. Build against the contract and test offline with `test/support/fake_api.dart`. Deliver in the same three phases as the backend. Each phase must work on its own; until the backend serves a phase, its screens show the normal load error with Retry.

## 1. Rules

1. **Nothing hard-coded per asset kind.** Categories, types, units, icons and colours come from the API. The UI is generic, and a new type (e.g. "Solar Panel") must work with no app change. Only the fixed enums are coded: tracking (`individual`, `bulk`), status, condition, placement, bulk states and maintenance status. Each gets one shared label and colour helper.
2. **Student identity:** assign to students only by numeric `students.id`, picked from the shared `StudentPickerSource` / `StudentPickerSheet`, never the phonebook cache or a bank code. From the phonebook profile, which has no `students.id`, use `StudentIdResolver`: the known id, else an exact 12-digit Aadhar match, else the admin confirms.
3. **Partial updates:** `PUT` sends only the changed fields.
4. **Access:** the operator console and admins/wardens only (`canOperate`). Any other role is sent back with "Access Denied" before any request is made, as Broadcast does.
5. **Money and dates:** money arrives as a string; show it as `₹4,500` with `intl`. Calendar dates arrive as `YYYY-MM-DD`; show them as `d MMM yyyy` with `DateFormatting.calendarDate`, plus age where useful ("22 months old"). Timestamps go through `DateFormatting`, which converts to IST.
6. **Never imply deletion:** "Retire" (asset) and "Deactivate" (category, type, location) say that history is kept. There is no delete for events, assignments, maintenance or attachments; attachments get "Remove", which is a server soft delete.
7. **Conventions:**
   - GetX feature at `lib/features/amenities/{bindings,controllers,views,widgets}`, with routes in `app_routes.dart` and `app_pages.dart` with bindings.
   - Repositories in `lib/core/network/repository/amenities/` that throw `ApiException` (use `toApiException`); models in `lib/core/models/amenities/`.
   - `LoadStateMixin` / `AsyncStateView`, and the Phonebook theme (`PhonebookTheme`, `PhonebookHeaderDelegate`, `PhonebookCard`, `PhonebookTintChip`, `phonebookInputDecoration`).
   - Snackbars via `AppSnackbar`. After a success snackbar, close with `Navigator.of(context).pop()`, not `Get.back()`.
   - Dialogs and sheets with text fields own their `TextEditingController` in a `State` (disposing one right after `showDialog` returns crashes while the dialog closes).

## 2. Navigation

- **Operator console:** replace the **Rooms & Keys** tile with **Amenities** (icon `inventory_2_rounded`, same section and colours style, `adminOnly` as today).
- **Old routes:** `Routes.operatorRoomKeys` and `Routes.operatorRoomKeysRoom` should open the new screens: the dashboard, and the location screen for that room. Remove `lib/features/room_keys/` once nothing uses it.
- **Amenities home:** a header with search and a **scan** action, then three tabs:
  - **Dashboard**
  - **Inventory**
  - **Locations**

  plus a ⋮ menu: Categories & types, Activity log.

## 3. Screens

### Dashboard (`GET /dashboard`)
- **Stat cards:** total items, total asset value, available, assigned, installed, under repair, damaged, lost, retired, warranty expiring, maintenance due, open repairs.
- **Category rows:** icon and colour from the API, items, value.
- **Drill down:** every card and row opens **Inventory** with the matching filter applied (status, placement, warranty, maintenance or category).

### Inventory
- **Search** (debounced 300 ms): asset code, serial, label, type, category, student, room.
- **Filter sheet:** category, type, status, condition, placement, location (tree picker, includes everything under it), room, warranty, maintenance, installed from/to. Filters show as removable chips.
- **Grouping:** results grouped by type; individual assets are paged, 50 at a time, with load-more.
- **Bulk types** show as one row: "Plastic Chair · 420 assigned · 65 available · 10 under repair".
- **FAB "Add":** choose an existing type, then for an individual type the add-assets form (`count` 1–200, purchase details, home location), or for a bulk type the add-stock form.

### Amenity type screen (`GET /types/:id`)
- **Inventory strip:** total, available, assigned, installed, under repair, damaged, lost, retired, value.
- **Individual types:** its assets list (filtered Inventory).
- **Bulk types:** stock actions (Add stock, Assign quantity, Move units, e.g. 10 to Under repair) and its open and closed assignments, with **Return** (partial quantities allowed, condition, to available / damaged / lost).

### Asset detail (`GET /assets/:id`; also opened by QR)
- **Header:** asset code (tap to copy), type and category, status and condition chips, placement line ("Installed · Pavitra House › Floor 2 › Room 204", "With Dharmik Shah · Room 204" or "In store").
- **Actions, depending on state:**
  - Assign, Transfer, Return;
  - Change status (Issue reported, Inspection, Under repair, Damaged, Lost, Active, Retire, each with an optional note);
  - Report issue, Edit, Show QR.
- **Tab Overview:** label, serial, purchase date and cost, vendor, installation date, age, warranty (with expiring or expired badge), expected life and replacement due, next maintenance, notes, who created and updated it and when, and the QR code (`qr_flutter`, from `qr_payload`).
- **Tab Lifecycle** (`GET /assets/:id/events`, paged):
  - a vertical timeline, newest first, with an icon per event, `happened_on` or the time, "by <name>" and a readable line;
  - examples: "Shifted from Room A-204 to A-206"; for edits, "Purchase cost ₹4,000 → ₹4,500";
  - migrated Room Keys events show normally.
- **Tab Assignments:** current one first, then previous; each shows the student (room at that time) or the location, dates, and the condition out and back.
- **Tab Maintenance (phase 2):** total cost on top, then records (issue, status, technician, vendor, cost, parts, dates, photo thumbnails), **New record** and record detail and edit with the status steps.
- **Tab Documents (phase 2):** attachments grouped by kind (invoice, warranty, manual, photo, before/after).
  - **Upload:** a photo via `image_picker`, compressed to around 1600 px, or a PDF via a file picker (add `file_picker` if needed).
  - **Viewing:** images open full size; PDFs open with the token (download to a temp file, then `open_filex` or a viewer). Attachment files need the `Authorization` header (`ApiClient` dio).
- **Tab Activity:** `GET /activity?asset_id=`, who did what and when.

### Locations
- **Tree:** expandable building › wing › floor › room / area, with counts.
- **A room or area screen** (`GET /locations/:id/amenities`):
  - what is installed there;
  - for rooms, each resident with their items;
  - the room's door and cupboard keys.

  It does everything the old Room Keys room screen did: give a key to a student, take it back, mark it lost or found, add keys.
- **Admin:** add, rename and deactivate nodes.

### Categories & types (setup)
- **Categories:** name, description, icon (a small picker of Material icons), colour (a palette), order, active.
- **Types:**
  - category, name, Asset ID prefix (2–6 A–Z/0–9, locked once it has assets, with the server's 409 shown), tracking (individual or bulk, fixed after create);
  - unit, default expected life (months), maintenance interval (days), "can be given to students", active.
  - A live preview of the next code: `HSH-FAN-00001`.

### Assign / transfer / return sheets
- **Target:** **Student** (the shared picker, residents and alumni; the student's room shows; a server `warning` shows as an amber note) or **Location** (tree picker).
- **Fields:** quantity (bulk; at most the available count, with the server's 409 shown), condition, expected return date, note.
- **Return:** condition, note; for bulk, the quantity and where it goes.

### Student profile → Amenities
On the phonebook student details screen, add an **Amenities** section, collapsible like the others and part of "Expand all":
- **current items:** type and code or quantity, since when, condition, room at assignment;
- **Returned** and **Lost / damaged:** two collapsible groups.

Tapping an item opens its asset or type screen. It uses `GET /students/:id/amenities`, with the id from `StudentDetailScreen.studentId` or `StudentIdResolver`; while unresolved, it shows a "Link student" button as the Current address card does.

### Scanner and QR (phase 3; lookup works from phase 1)
- **Scan:** the header scan icon opens `mobile_scanner` (already a dependency). It reads any QR, pulls out `HSH-[A-Z0-9]{2,6}-\d{5}`, calls `GET /assets/by-code/:code` and opens Asset detail.
- **Quick actions:** **Report issue** is one tap from there. Show a clear message for an unknown code or a QR that isn't an HSH asset.
- **Show QR:** a big QR, the code under it, and Share as image. Phase 3: a printable A4 sheet of labels for a filtered list (PDF via the `printing`/`pdf` packages).

## 4. Phase plan

1. **Core:**
   - models, repositories, dashboard, inventory, type and asset screens (Overview, Lifecycle, Assignments, Activity);
   - assign, transfer, return, status, bulk stock;
   - locations with the room screen replacing Room Keys;
   - setup screens, student Amenities section, by-code lookup;
   - tile and route replacement.
2. **Maintenance and documents:** tabs, forms, uploads, warranty and maintenance badges and filters.
3. **QR:** scanner polish, Report issue, share and print labels.

## 5. Tests (offline, `FakeApi`, one file per area)

- **Repositories:** paths, partial `PUT` bodies; student ids are always numeric (a bank code is never sent; copy the pattern in `screen_time_student_id_test.dart`).
- **Parsing:** model `fromJson` for every object in the contract, plus money and date formatting.
- **Controllers:** dashboard drill-down sets the right filters; inventory search debounce and filter chips; bulk assign over availability shows the 409 message; transfer and return update the screen; asset code extraction from QR text (plain code, URL, lower case, junk).
- **Render tests at 360×800 @3x** (`loadDeviceLikeFonts`):
  - asset detail and dashboard have no overflow;
  - the Rooms & Keys tile is gone and Amenities is there;
  - an old Room Keys route opens the new screen.
- **Migration view:** a migrated key (`RKEY`) shows its old history.

Run `flutter analyze` (and the offline tests). Update `docs/AMENITIES_SPEC.md` to describe what was actually built, retire `docs/ROOM_KEYS_DOCS.md` (point it to the new doc), and add the new module to `AGENTS.md` (§1 feature docs, §4 a short invariants block: generic types, append-only history, `students.id` only, partial updates).
