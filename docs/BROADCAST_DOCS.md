# Broadcast Messages

> **Last updated:** 2026-11-11 · **Repos:** `hsh_app2` (Flutter) and `hsh_api` (Node/Express/MySQL). **Status:** the app side is built and tested offline against the contract below. The backend is being built from [BROADCAST_BACKEND_PROMPT.md](BROADCAST_BACKEND_PROMPT.md), and until it ships, the screens show their load errors.

---

## 1. What this feature does

| Part | Who | Summary |
| :--- | :--- | :--- |
| **Compose** | Admin | Title (1–100 characters) and message (1–2000 characters). Audience = students with **any** selected tag ∪ students picked individually. A live "Will reach N students" count, a confirmation dialog, then Send. |
| **History** | Admin | Sent broadcasts, newest first, paged. Each shows status (*Sending…* / *Sent* / *Failed*) and recipient / pushed / read counts. It refreshes every 5 s while any broadcast is sending. |
| **Detail** | Admin | Full message, audience, counts and the recipient list. Each recipient shows push status and read time, with a filter: All / Read / Unread / No device. |
| **Announcements** | Students, leaders | Inbox of broadcasts addressed to them. Opening one marks it read. A push notification opens the message directly. |

Entry points:
- Admin: **Operator console → Hostel Services & Staff → Broadcast**. The tile is `adminOnly`, and every admin screen also checks the role on open.
- Students: **More → Personal → Announcements**.

## 2. Rules

1. **Admin only** for compose, history and detail (`BroadcastAdminGate`). Any other role is sent back with "Access Denied" before any request is made.
2. **Individual picks are numeric `students.id` only.** They come from `/students?all=true`, falling back to `/screen-time/students`. Only the row's `id` is read, and only as a positive integer without a leading zero (`studentIdOf`). `student_id`, `student_code`, bank codes and the phonebook cache are never used, because bank codes collide with other students' ids (AGENTS.md §4). Alumni rows are not offered.
3. **No double send:** a `client_request_id` (UUID v4) is created when Compose opens and reused for every retry. Send is disabled while sending.
4. **Confirmation first:** "Send 'Title' to N students?". When some students have no device, the dialog adds "X have no device; they'll see it in the inbox".
5. **A failed send keeps the form**, shows the server's `message` as-is, and lets the admin retry with the same id. `201` (new) and `200` (known request id) are both success.
6. **Send is enabled only when** title and message are valid, at least one tag or student is picked, the preview has finished without error, and it reaches more than 0 students.
7. **The preview is debounced by 400 ms**, and only the newest reply is kept. An empty audience shows 0 without a request.

## 3. API contract

All responses use `{ success, data }`, or `{ success: false, message }` on errors. Dates are ISO 8601 UTC, shown in IST via `DateFormatting`.

| Method & path | Who | Request | Response `data` |
| :--- | :--- | :--- | :--- |
| `POST /broadcasts/preview` | admin | `{ tag_ids: int[], student_ids: int[] }` | `{ recipient_count, no_device_count, sample: [{ id, name, room }] }` |
| `POST /broadcasts` | admin | `{ client_request_id, title, message, tag_ids, student_ids }` | `<Broadcast>`: `201` new, `200` repeat |
| `GET /broadcasts?limit&offset` | admin | — | `[<Broadcast>]`, plus top-level `total` |
| `GET /broadcasts/:id` | admin | — | `<Broadcast>` + `recipients: [{ student_id, name, room, matched_by, push_status, read_at }]` |
| `GET /me/broadcasts?limit&offset` | student | — | `[{ id, title, message, sender_name, created_at, read_at }]`, plus `total` and `unread_count` |
| `POST /me/broadcasts/:id/read` | student | — | `{ id, read_at }` (idempotent) |

`<Broadcast>` = `{ id, title, message, tags: [{ id, name, color }], student_ids, status: sending|sent|failed, recipient_count, push_sent, push_failed, no_device, read_count, sender: { id, name }, created_at, completed_at }`.

- Errors: `400` validation, `403` wrong role, `404` not found, and `422` "No active students match this audience.".
- Parsing is defensive: numbers may arrive as strings, and an unknown `status` is shown without a badge.

**Push:** FCM data `{ type: "broadcast", broadcast_id, title, body }` (all strings).
- In `PushNotificationService._navigateFromPayload`, students open **Announcements** at that message, and admins open the broadcast detail (`broadcastTarget`).
- **Cold start:** a tap while splash is showing is held (`mustWaitForStartup`), and splash replays it 400 ms after routing to the user's home (`openPendingNotification`). Without this, splash's `Get.offAllNamed` would wipe the opened screen. The hold applies to every notification type, not just broadcasts.

## 4. Code

| Path | What |
| :--- | :--- |
| `lib/core/models/broadcasts/broadcast_models.dart` | `Broadcast`, `BroadcastRecipient`, `BroadcastPreview`, `BroadcastStudent`, `InboxBroadcast`, `studentIdOf` |
| `lib/core/network/repository/broadcasts/broadcasts_repository.dart` | The six calls (registered in `GlobalBindings`) |
| `lib/features/broadcast/controllers/` | `BroadcastAdminGate`, compose, history, detail and inbox controllers |
| `lib/features/broadcast/views/` | History, compose, detail and inbox screens |
| `lib/features/broadcast/widgets/` | Status badge, audience chips, counts, history card |
| Shared with Forms & Polls | `PickableStudent` / `studentIdOf`, `StudentPickerSource`, `StudentPickerHost`, `StudentPickerSheet` |
| Routes | `Routes.operatorBroadcasts`, `operatorBroadcastCompose`, `operatorBroadcastDetail`, `broadcastInbox` |

## 5. Tests (offline, `test/support/fake_api.dart`)

- `test/broadcast_compose_test.dart`:
  - role gate;
  - debounced preview (one request) and empty audience;
  - **only numeric `students.id` sent** (codes, `student_id`, leading zeros and alumni are rejected);
  - trimmed body plus UUID;
  - a double tap sends once;
  - a retry reuses `client_request_id`;
  - 200 counts as success;
  - 400 / 422 keep the form;
  - Send disabled for invalid text, zero reach or a preview error.
- `test/broadcast_history_test.dart`:
  - defensive parsing;
  - paging with `offset`;
  - polling only while sending;
  - role gate;
  - detail recipient filters.
- `test/broadcast_inbox_test.dart`:
  - list and unread count;
  - optimistic read, and rollback when it fails;
  - no request for an already-read message;
  - push payload → inbox message (student) or detail (admin);
  - the hold during splash.

## 6. Only checkable once the backend is live

- Real push delivery and counts.
- iOS taps in the background or from a killed state (APNs).
- The Android notification channel in the foreground.
- The 5-second history refresh against real sending times.
