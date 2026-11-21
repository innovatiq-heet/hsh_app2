# Room Keys

> **Last updated:** 2026-11-22 · **Repos:** `hsh_app2` (Flutter) and `HAMS_WEB` / `hsh_api` (Node/Express/MySQL)
>
> **Backend status:** Implemented and live in `HAMS_WEB` (`src/modules/roomKeys/`, mounted at `/room-keys` and `/api/room-keys`, e2e tested in `tests/e2e/room-keys.e2e.test.ts`).

## 1. What it does

The hostel office keeps a register of every room's keys:

- **Door lock keys:** one lock per room, so the copies share its number (e.g. `204`). Each copy is with a student or kept in the office.
- **Cupboard keys:** one per cupboard, each with its own number (e.g. `1123`), normally with the student who uses that cupboard.
- For each key: who has it (**With student / In office / Lost**), and its full history (given, returned, lost, found, edited, removed; by whom and when).

Operator console → **Room Keys** (admin and warden).

## 2. Screens

- **Room list** (`RoomKeysScreen`): counts of keys with students, in the office and lost; search by room, key number or student name; filters *All rooms*, *Missing keys* (no usable door key, or a resident without a cupboard key) and *Needs attention* (a lost key, or a key still with a student who moved to another room or left the hostel). Each room card shows its students, door number and copies, and cupboards given out (e.g. `Cupboards 2/3`). Drag a card's handle to change the room order; it saves automatically on this device and survives reloads. Filtered reorders leave hidden rooms in their existing slots. Rooms come from the current residents plus any room that has keys; *Another room* opens a room with no residents.
- **Room** (`RoomKeysRoomScreen`): the door keys; each resident with their cupboard key (or *No cupboard key · Add*); other cupboard keys of the room (spare, lost, or with someone who moved out). Tap a key for its actions.
- **Add keys** (`RoomKeysSetupSheet`): the whole room at once. Type the door key number once, tick *Give a door key copy* per student, choose how many spare door keys stay in the office, type each student's cupboard number, and add spare cupboard keys. Keys a student already has are shown instead of asked for. One request (`POST /room-keys/batch`). Before saving, the app warns when a cupboard number is already used in another room, or the door number is another room's.
- **Key actions** (`KeyActionsSheet`): give to a student (the room's students first, anyone else by search), returned to office, mark lost (with confirmation), found, edit number / name / notes / type (only changed fields are sent), history, remove (with confirmation; history is kept).

Changes show at once and are rolled back with an error message if the server refuses.

## 3. Rules

- A key is given to a student **only by numeric `students.id`**, taken from `StudentPickerSource` (`/students?all=true`, falling back to the Screen Time directory). Never the phonebook cache, never a bank code (AGENTS.md §4).
- Room numbers are compared trimmed and upper-cased (`normalizeRoom`).
- `PUT /room-keys/:id` is a partial update: send only changed fields.
- If the student list can't be loaded, the keys still show; rooms then list keys without residents.
- Room order is stored in this device's preferences (`room_keys_room_order_v1`). The API has no shared room-order field or endpoint, so another device keeps its own order. The default remains natural room-number order until a room is dragged.

## 4. API (summary)

Full contract: [ROOM_KEYS_BACKEND_PROMPT.md](ROOM_KEYS_BACKEND_PROMPT.md). All endpoints need an operator-console token.

| Method & path | Use |
| :--- | :--- |
| `GET /room-keys` | Every key (`data.keys`) with `student_name`, `student_room`, `student_active` |
| `POST /room-keys/batch` | `{ room_number, keys: [{ key_type, key_number, label?, student_id? }] }`, 1–50 keys |
| `PUT /room-keys/:id` | Partial: `key_type`, `key_number`, `label`, `notes`, `room_number` |
| `POST /room-keys/:id/action` | `{ action: assign \| return \| lost \| found, student_id?, note? }` |
| `DELETE /room-keys/:id` | Soft delete; history kept |
| `GET /room-keys/:id/history` | `data.logs`, newest first |

## 5. Files

| File | Role |
| :--- | :--- |
| [room_key_models.dart](../lib/core/models/room_keys/room_key_models.dart) | `RoomKey`, `NewRoomKey`, `RoomKeyLog`, `KeyType`, `KeyStatus`, `KeyAction`, `normalizeRoom` |
| [room_keys_repository.dart](../lib/core/network/repository/room_keys/room_keys_repository.dart) | Every `/room-keys` call |
| [room_keys_controller.dart](../lib/features/room_keys/controllers/room_keys_controller.dart) | Loading, rooms (`KeyRoom`), search and filters, optimistic actions |
| [room_keys_screen.dart](../lib/features/room_keys/views/room_keys_screen.dart), [room_keys_room_screen.dart](../lib/features/room_keys/views/room_keys_room_screen.dart) | Room list and one room |
| [room_key_widgets.dart](../lib/features/room_keys/widgets/room_key_widgets.dart) | Key tile and the add / actions / give / edit / history sheets |

Routes: `Routes.operatorRoomKeys`, `Routes.operatorRoomKeysRoom` (argument: the room number).

## 6. Tests

`test/room_keys_test.dart` (offline, `FakeApi`): parsing (a bank code never becomes a student id), grouping by room, filters and search, duplicate warnings, the batch / action / edit / delete requests, rollback on a refused change, keys without the student list, and the list, room and add-keys screens at 360 px (including the exact batch request the sheet sends).

## 7. Not done yet

- The backend endpoints (see the prompt).
- Ideas for later: QR stickers on key tags to open a key by scanning; a reminder when a student leaves with a key; a "My keys" card on the student profile; a key-keeper staff role.
