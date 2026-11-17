# Prompt: Room Keys (door and cupboard keys per room) — backend (`hsh_api`)

> Paste everything below the line into the backend chat (repo `hsh_api`, Node + Express + MySQL).

---

Build a **Room Keys** register in `hsh_api`. The hostel office records every key of every room: the **door lock key(s)** and the **cupboard keys**, each with the **number stamped on it**, and who has each key. A key can be given to a student, returned to the office, reported lost and found again, and every change is kept as history.

The Flutter app (`hsh_app2`) is already built against the API contract in section 3 and its tests run against it with a fake server. Implement that contract exactly. If you have to change a path, a field name or a status code, list the change at the end of your reply so the app side can be updated.

Read `AGENTS.md` first and follow this repo's existing patterns: module layout (`src/modules/roomKeys/`), auth middleware, validation, the `{ success, data }` / `{ success, message }` responses, migrations in `src/config/db.ts`, and e2e tests.

---

## 1. Rules (must hold)

1. **Who can use it:** the operator console roles (admin and warden). Reuse `verifyOperator` (`operator`, `platform-admin`) on every endpoint. Anyone else gets `401`/`403`.
2. **Student identity:** a student is identified **only by numeric `students.id`**. Accept a positive integer without a leading zero (`12`, not `"0012"`); reject bank codes, `student_code` and `HSH-…` ids with `400`. Bank codes are numeric and collide with other students' ids.
3. **Giving a key** (batch create with `student_id`, or the `assign` action) needs an **existing, active resident** (not left, cancelled, alumni or a deactivated account). Otherwise `400` with a clear message.
4. **Room numbers** are stored trimmed and upper-cased (`" a-12 "` → `A-12`), so `204` and ` 204` are one room. They match `students.room_number` the same way.
5. **No uniqueness constraint on numbers.** The door keys of one room share the lock's number (several copies). Cupboard numbers are normally unique, but the app only warns about a duplicate; the server accepts it.
6. **History is never lost.** Every create, edit, assign, return, lost, found and delete writes one row to `room_key_logs` in the same transaction as the change. Deleting a key is a soft delete; its history stays readable.
7. **Partial update:** `PUT /room-keys/:id` changes only the fields present in the body.
8. **Who did it:** each log row stores the name (and id) of the signed-in operator from the request.
9. Times are returned as ISO-8601 UTC strings.

---

## 2. Tables (`src/config/db.ts`, created if missing)

```sql
CREATE TABLE IF NOT EXISTS room_keys (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  room_number  VARCHAR(20)  NOT NULL,
  key_type     ENUM('door','cupboard') NOT NULL,
  key_number   VARCHAR(30)  NOT NULL,
  label        VARCHAR(60)  DEFAULT NULL,           -- e.g. "Main door", "Cupboard A"
  status       ENUM('assigned','office','lost') NOT NULL DEFAULT 'office',
  student_id   INT          DEFAULT NULL,           -- who has it (assigned) or had it (lost)
  notes        VARCHAR(500) DEFAULT NULL,
  is_deleted   TINYINT(1)   NOT NULL DEFAULT 0,
  updated_by   VARCHAR(100) DEFAULT NULL,
  created_at   DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_room_keys_room (room_number),
  INDEX idx_room_keys_student (student_id),
  INDEX idx_room_keys_number (key_type, key_number)
);

CREATE TABLE IF NOT EXISTS room_key_logs (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  key_id      INT NOT NULL,
  action      ENUM('created','edited','assigned','returned','lost','found','deleted') NOT NULL,
  student_id  INT          DEFAULT NULL,
  note        VARCHAR(500) DEFAULT NULL,
  by_user_id  INT          DEFAULT NULL,
  by_name     VARCHAR(100) DEFAULT NULL,
  created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_room_key_logs_key (key_id, created_at)
);
```

Invariants: `status = 'assigned'` ⇒ `student_id` is set; `status = 'office'` ⇒ `student_id` is `NULL`; `status = 'lost'` keeps the `student_id` of whoever had it (may be `NULL`).

---

## 3. API contract

Mount at `/api/room-keys` and `/room-keys` (like the other modules). All endpoints: Bearer token, `verifyOperator`.

### The `RoomKey` object (every response that returns a key)

```json
{
  "id": 12,
  "room_number": "204",
  "key_type": "cupboard",
  "key_number": "1123",
  "label": "Cupboard A",
  "status": "assigned",
  "student_id": 1043,
  "student_name": "Asha Patel",
  "student_room": "204",
  "student_active": true,
  "notes": null,
  "updated_at": "2026-11-16T05:30:00Z",
  "updated_by": "Hostel Admin"
}
```

- `student_name`, `student_room` (the student's **current** `students.room_number`) and `student_active` come from a join on `students`. They are `null` / `true` when `student_id` is `null`.
- `student_active` is `false` when the student has left, cancelled, is alumni, or the account is inactive. The app uses it, and `student_room` ≠ `room_number`, to tell the office to collect a key.

### `GET /room-keys`

All keys that are not deleted, ordered by `room_number`, then `key_type` (door first), then `key_number`. Optional `?room_number=204`.

`200 { "success": true, "data": { "keys": [RoomKey, ...] } }`

### `POST /room-keys/batch`

Adds several keys to one room in one transaction (how the app sets up a room).

```json
{
  "room_number": "204",
  "keys": [
    { "key_type": "door", "key_number": "204", "student_id": 1043 },
    { "key_type": "door", "key_number": "204" },
    { "key_type": "cupboard", "key_number": "1123", "label": "Cupboard A", "student_id": 1043 }
  ]
}
```

- `keys`: 1–50 items. `key_type` is `door` or `cupboard`; `key_number` 1–30 characters after trimming; `label` optional, ≤ 60; `student_id` optional (rule 2 and 3).
- A key with `student_id` is saved as `assigned`, without it as `office`. One `created` log row per key, with its `student_id`.
- Any invalid item rejects the whole batch (`400`, nothing saved).

`201 { "success": true, "data": { "keys": [RoomKey, ...] } }` (the created keys, in request order)

### `PUT /room-keys/:id`

Partial update of the details: any of `key_type`, `key_number`, `label`, `notes`, `room_number`. `label` / `notes` may be `null` to clear. Status and holder are **not** changed here (use the action endpoint). Writes one `edited` log row whose `note` says what changed (e.g. `key_number 204 → 204A`).

`200 { "success": true, "data": RoomKey }` · `404` unknown or deleted key · `400` invalid field

### `POST /room-keys/:id/action`

```json
{ "action": "assign", "student_id": 1043, "note": "optional, ≤ 500" }
```

| `action` | Needs | Result | Log |
| :--- | :--- | :--- | :--- |
| `assign` | `student_id` (rule 2, 3) | `status = assigned`, `student_id` = that student (also from another student or from `lost`) | `assigned` with the new student |
| `return` | key is `assigned` | `status = office`, `student_id = NULL` | `returned` with the previous student |
| `lost` | key is `assigned` or `office` | `status = lost`, `student_id` kept | `lost` with that student |
| `found` | key is `lost` | `status = office`, `student_id = NULL` | `found` |

`200 { "success": true, "data": RoomKey }` · `400` unknown action, missing/invalid `student_id`, or an action that doesn't fit the current status · `404` unknown or deleted key or student

### `DELETE /room-keys/:id`

Soft delete (`is_deleted = 1`) and a `deleted` log row. `200 { "success": true }` · `404` unknown or already deleted.

### `GET /room-keys/:id/history`

Newest first; works for deleted keys too.

```json
{
  "success": true,
  "data": {
    "logs": [
      { "action": "assigned", "student_id": 1043, "student_name": "Asha Patel", "note": null, "by_name": "Hostel Admin", "created_at": "2026-11-16T05:30:00Z" }
    ]
  }
}
```

`404` unknown key.

---

## 4. Tests (e2e)

- Every endpoint rejects a request without a token and a student token.
- Batch create: door copies with the same number are accepted; a bank-code `student_id` (`"0768"`) is `400`; an alumni / left student is `400`; one bad item saves nothing; created keys come back as `assigned` / `office`.
- Assign → return → lost → found: statuses, `student_id` and one log row per step, newest first in history.
- `return` on an `office` key and `found` on a non-lost key are `400`.
- `PUT` with only `label` leaves every other column unchanged; the log note names the change.
- Delete hides the key from `GET /room-keys` but keeps its history.
- `student_room` / `student_active` reflect a student who moved rooms or left.

At the end of your reply, list anything that differs from this contract.
