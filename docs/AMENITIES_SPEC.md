# Amenities Management — product spec

> **Last updated:** 2026-11-24 · **Status:** app Phase 1 built (`lib/features/amenities/`); backend module not built yet, so every screen shows the server's error until `/api/amenities` exists · **Replaces:** Rooms & Keys (removed from the app) · **Repos:** `HAMS_WEB` (backend), `hsh_app2` (app). Build prompts: [AMENITIES_BACKEND_PROMPT.md](AMENITIES_BACKEND_PROMPT.md), [AMENITIES_APP_PROMPT.md](AMENITIES_APP_PROMPT.md).

## 1. Goal

One place to manage every physical thing the hostel owns: keys, furniture, fans, lights, ACs, geysers, taps, coolers, routers, fire extinguishers, and anything added later. At any time the office can answer:

- What do we own, how many, and what is it worth?
- Where is each item, and who has it?
- When was it bought and installed? How old is it? Is it under warranty? When should it be replaced?
- How many times was it repaired, and what did that cost?
- Is it working now? What happened to it over its life, and who used it before?

New kinds of asset (e.g. a solar panel) are added **from the app**, with no code change.

## 2. Concepts

```text
Category ─< Amenity type ─< Asset (individual)          ─< Assignment, Lifecycle event, Maintenance, Attachment
                         └─ Stock (bulk, by quantity)   ─< Assignment (with quantity), Stock movement
Location tree: Building › Wing › Floor › Room / Area
```

| Concept | Meaning | Examples |
| :--- | :--- | :--- |
| **Category** | A group of amenity types. Admin-defined. | Electrical, Plumbing, Furniture, Security / Keys |
| **Amenity type** | A kind of thing. Admin-defined, under one category. | Fan, Tap, Plastic Chair, Room Key, Solar Panel |
| **Tracking mode** (per type) | **Individual**: every item is its own asset with an Asset ID and QR code. **Bulk**: counted by quantity, no per-item ID. | Individual: Fan, AC, Geyser, Router, Room Key. Bulk: Plastic Chair, Bucket, Bulb |
| **Asset** | One individually tracked item. | `HSH-FAN-00124` |
| **Stock** | The quantity of a bulk type, moved between states (available, assigned, under repair, damaged, lost, retired). | 500 plastic chairs |
| **Location** | Where things are. A dynamic tree: building › wing › floor › room, or an area (common area, office, kitchen, dining, bathroom, electrical room, plumbing area, custom). | Pavitra House › Floor 2 › Room 204 |
| **Assignment** | An item (or a quantity) given to a **student** or installed at a **location**, from a date until it is returned or moved. Closed assignments stay as history. | Room Key × 1 to a student; Fan installed in Room 204 |
| **Lifecycle event** | One entry in an item's history. Append-only, never edited or deleted. | Purchased, installed, repair started, shifted to A-206 |
| **Maintenance record** | One repair or service job, with its cost, parts, technician, vendor, bill and before/after photos. | "Noise issue" → capacitor replaced, ₹450 |
| **Attachment** | A photo or PDF linked to an asset, type, maintenance record or assignment. | Invoice, warranty card, manual, before/after photo |

## 3. State: status, condition and placement

Kept separate so the numbers add up:

- **Status** (does it work?): `active`, `issue_reported`, `inspection_required`, `under_repair`, `damaged`, `lost`, `retired`. "Repaired" is a maintenance outcome; afterwards the asset is `active` again.
- **Condition** (what shape is it in?): `new`, `good`, `fair`, `poor`, `unusable`. Recorded at every assignment and return.
- **Placement** (where is it?), derived from the open assignment: `in_store` (none), `with_student`, `installed` (at a location).

Dashboard words map onto these: **Available** = active and in store; **Assigned** = with a student; **Installed** = at a location; **Under repair / Damaged / Lost / Retired** = that status.

Bulk stock has the same states as counts: available, assigned, under repair, damaged, lost, retired. Total = all of them. Every change is a movement of a quantity from one state to another, so the counts are always the sum of the movements.

## 4. What admins can do

1. **Set up:** create, rename and deactivate categories and amenity types. A type has a name, an Asset ID prefix (e.g. `FAN`), tracking mode, unit, default expected life, an optional maintenance interval, and whether it can go to students.
2. **Add stock:** individual: add one or many assets at once (same purchase details), each getting the next Asset ID. Bulk: add a quantity with its purchase details.
3. **Record details:** name/label, serial number, purchase date and cost, vendor, installation date, warranty expiry, expected life, condition, status, notes, photos and documents.
4. **Assign and return:** give an asset or a quantity to a student (numeric `students.id` only) or install it at a location. Record the condition, an optional expected return date and notes. On return, record the condition. **Transfer** moves it to another student or location in one step. A student's room is stored with each assignment, so a later room change doesn't rewrite history.
5. **Report and repair:** report an issue, then inspection, repair started and repair completed (cost, parts, technician, vendor, bill, before/after photos). An asset can also be marked damaged, lost or retired. Lost items can be found again.
6. **Look up:** search by name, Asset ID, serial number, student, room or category. Filter by category, type, status, condition, building, wing, floor, room, placement, installation date, warranty (active / expiring in 30 days / expired) and maintenance (open / due).
7. **Scan:** scanning an asset's QR code opens it: details, location, status, holder, installation, warranty, maintenance history, and **Report issue**.

## 5. Screens (app)

- **Dashboard:**
  - Cards for total items, total asset value, available, assigned, installed, under repair, damaged, lost, retired, warranty expiring, maintenance due and open repairs.
  - A row per category (items and value).
  - Every card opens the filtered list.
- **Inventory:** search, filters, and a list of types and assets.
- **Amenity type:** inventory counts; for bulk, stock and its assignments; for individual, its assets.
- **Asset detail:** tabs **Overview** (with QR), **Lifecycle** (timeline), **Assignments**, **Maintenance** (with total cost), **Documents** and **Activity** (who did what).
- **Locations:** the building tree. A room shows everything installed there and its students' items, which replaces the old Room Keys room screen.
- **Student profile → Amenities:**
  - current items: quantity, since when, condition, room;
  - returned items;
  - lost or damaged items;
  - full history.
  - Each one opens its detail.
- **Scanner.** Setup screens for categories, types and locations.

## 6. Rules

1. **Nothing is lost.** Lifecycle events, assignments, maintenance records and attachments are never deleted or overwritten. Editing an asset records what changed. Deleting means retiring (assets) or deactivating (categories, types, locations).
2. **Audit everything:** who and when for create, edit, assign, transfer, return, status change and repair updates. The user always comes from the login, never from the request body.
3. **Student identity:** numeric `students.id` only, never a bank code, `student_code` or `HSH-…` id (AGENTS.md).
4. **Stock can't go negative.** Assigning more than is available is refused.
5. **Asset IDs** are unique and never reused, even after an asset is retired: `HSH-<PREFIX>-<5 digits>`. A type's prefix can't change once it has assets.
6. **Access:** admins and wardens (the operator console). Students and leaders have no access in this version.
7. **Money:** rupees with 2 decimals. Dates (purchase, install, warranty) are calendar dates in IST; event times are timestamps.

## 7. Room Keys migration

Every existing key becomes an asset under **Security / Keys**: door keys as type **Room Key**, cupboard keys as **Cupboard Key**.
- **Key fields:** the key number becomes its serial number, and its label is kept.
- **Location:** the room becomes the asset's location; missing rooms are created from the room numbers.
- **Status:** a key with a student becomes an open student assignment; a key in the office becomes active and in store; a lost key becomes `lost`; a deleted key becomes `retired`.
- **History:** every log entry becomes a lifecycle event with its original time and person.

The migration can run twice without making duplicates. The old tables stay untouched, and the old `/room-keys` endpoints keep working on top of the new data until every phone runs the new app.

## 8. Phases

1. **Core:**
   - categories, types, locations;
   - individual assets and bulk stock, with assignments, returns, transfers and status changes;
   - lifecycle and activity;
   - search and filters, the dashboard, and the student's Amenities;
   - the Room Keys migration, with the Rooms & Keys tile replaced by Amenities.
2. **Maintenance and documents:** maintenance records, attachments (photos, PDFs), warranty and maintenance-due alerts, and total maintenance cost.
3. **QR:** QR codes (show, share, print a sheet of labels), the scanner and **Report issue**. Also expected-life and replacement-due reports.

## 9. Open questions (decide before Phase 2)

- Are the hostel groups (Param, Pavitra, Pulkit, Paramanand) the **buildings** of the location tree, or wings inside one building?
- Should students later see their own items and report issues from their app, which could feed the complaints desk?
- A vendors list (name, phone, GST) instead of free text?
- Print QR labels from the app (PDF sheet) or from a desktop?
- Depreciation / book value, or purchase cost only?
