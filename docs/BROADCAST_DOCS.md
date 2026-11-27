# Broadcast Messages

> **Last updated:** 2026-11-27 · **Repos:** `hsh_app2` (Flutter) and `hsh_api` (Node/Express/MySQL). **Status:** the app side is built and tested offline against the contract below. The backend is being built from [BROADCAST_BACKEND_PROMPT.md](BROADCAST_BACKEND_PROMPT.md), and until it ships, the screens show their load errors.

---

## 1. What this feature does

| Part | Who | Summary |
| :--- | :--- | :--- |
| **Compose** | Admin | Channels: **Both** (App + WhatsApp), **In-App Only**, or **WhatsApp Only**. Title (optional, max 100 characters) and message (1–2000 characters). Audience = students with **any** selected tag ∪ students picked individually. A live "Will reach N students" count with channel breakdown, a confirmation dialog, then Send. |
| **Picture** | Admin → students | One optional picture per broadcast (JPEG, PNG or WebP, up to 5 MB). WhatsApp sends the picture with the message as its caption, the push shows it as the big picture, and the student's inbox shows it under the message (tap to zoom). |
| **History** | Admin | Sent broadcasts, newest first, paged. Each shows channel badge, status (*Sending…* / *Sent* / *Failed*), and recipient / pushed / WhatsApp / read counts. It refreshes every 5 s while any broadcast is sending. |
| **Detail** | Admin | Full message, delivery channels, audience, counts (Push and WhatsApp stats) and the recipient list. Each recipient shows push & WhatsApp status and read time, with a filter: All / Read / Unread / No device. |
| **Announcements** | Students, leaders | Inbox of broadcasts addressed to them. Displays optional custom title or fallback heading. Opening one marks it read. A push notification opens the message directly. |

Entry points:
- Admin: **Operator console → Hostel Services & Staff → Broadcast**. The tile is `adminOnly`, and every admin screen also checks the role on open.
- Students: **Dashboard → Hostel updates → Announcements**. (It is also on the All services screen, but students cannot reach that screen.)

## 2. Rules

1. **Admin only** for compose, history and detail (`BroadcastAdminGate`). Any other role is sent back with "Access Denied" before any request is made.
2. **Individual picks are numeric `students.id` only.** They come from `/students?all=true`, falling back to `/screen-time/students`. Only the row's `id` is read, and only as a positive integer without a leading zero (`studentIdOf`). `student_id`, `student_code`, bank codes and the phonebook cache are never used, because bank codes collide with other students' ids (AGENTS.md §4). Alumni rows are not offered.
3. **Title is optional:** When omitted or blank, quick broadcasts send directly without requiring a subject heading. Push notification falls back to "Notice from Admin".
4. **Multi-channel dispatch:** Admins can send via In-App (push + inbox), WhatsApp (direct chat message via linked session), or Both.
5. **No double send:** a `client_request_id` (UUID v4) is created when Compose opens and reused for every retry. Send is disabled while sending.
6. **Confirmation first:** "Send to N students?". When some students have no device or no phone, the dialog adds reach warnings.
7. **A failed send keeps the form**, shows the server's `message` as-is, and lets the admin retry with the same id. `201` (new) and `200` (known request id) are both success.
8. **Send is enabled only when** title is valid (empty or <= 100 chars), message is non-empty, at least one tag or student is picked, who in the tags is chosen (rule 10), the preview has finished without error, and it reaches more than 0 students.
9. **The preview is debounced by 400 ms**, and only the newest reply is kept. An empty audience shows 0 without a request.
10. **Who in the tags:** with a tag selected, the admin must choose **Current & alumni**, **Current only** or **Alumni only** (each with its count) before Send is enabled. *Current & alumni* sends the tags (`tag_ids`) as before. *Current only* / *Alumni only* send that group's members as `student_ids` (numeric `students.id`, plus any individual picks) and no `tag_ids`, so the history lists them as individuals. Members come from `GET /students?all=true` (each row's `tags`) and are split like the server's `ACTIVE_STUDENT_SQL` (`TagMembers.of`): current = active and not left / cancelled / rejected; alumni = no room (empty, `N/A`, `alumni`, ...) and not cancelled / rejected. More than 500 students picked this way is refused with a hint to use *Current & alumni*.

11. **Picture (optional):** chosen in Compose (`image_picker`, re-encoded to JPEG at 85 %, max 1600 px, so iPhone HEIC works) and **uploaded at once** with `POST /broadcasts/image`, so Send only carries the returned `image_id`. It is checked on the phone the way the API checks it (type by content, at most 5 MB). A refused upload clears the picture and the broadcast can still go out as text. Send is disabled while a picture is uploading. A newer pick or Remove wins over an upload still in flight. Never send an image URL: only an `image_id` from the upload.

## 3. API contract

All responses use `{ success, data }`, or `{ success: false, message }` on errors. Dates are ISO 8601 UTC, shown in IST via `DateFormatting`.

| Method & path | Who | Request | Response `data` |
| :--- | :--- | :--- | :--- |
| `POST /broadcasts/preview` | admin | `{ tag_ids: int[], student_ids: int[] }` | `{ recipient_count, no_device_count, no_whatsapp_count, whatsapp_connected, sample: [{ id, name, room }] }` |
| `POST /broadcasts/image` | admin | multipart, field `image` (JPEG / PNG / WebP, ≤ 5 MB, real type in the part) | `201` `{ image_id, image_url }`; `413` too big, `400` not an image |
| `POST /broadcasts` | admin | `{ client_request_id, title?, message, image_id?, channels: 'both'|'app'|'whatsapp', tag_ids, student_ids }` | `<Broadcast>`: `201` new, `200` repeat; `400` for an unknown `image_id` |
| `GET /broadcasts?limit&offset` | admin | — | `[<Broadcast>]`, plus top-level `total` |
| `GET /broadcasts/:id` | admin | — | `<Broadcast>` + `recipients: [{ student_id, name, room, matched_by, push_status, whatsapp_status, whatsapp_phone, read_at }]` |
| `GET /me/broadcasts?limit&offset` | student | — | `[{ id, title, message, image_url?, sender_name, created_at, read_at }]`, plus `total` and `unread_count` |
| `POST /me/broadcasts/:id/read` | student | — | `{ id, read_at }` (idempotent) |

`<Broadcast>` = `{ id, title?, message, image_url?, channels: 'both'|'app'|'whatsapp', tags: [{ id, name, color }], student_ids, status: sending|sent|failed, recipient_count, push_sent, push_failed, no_device, whatsapp_sent, whatsapp_failed, no_whatsapp, read_count, sender: { id, name }, created_at, completed_at }`.

- Errors: `400` validation, `403` wrong role, `404` not found, and `422` "No active students match this audience.".
- Parsing is defensive: numbers may arrive as strings, and an unknown `status` is shown without a badge.

**Push:** FCM data `{ type: "broadcast", broadcast_id, title, body, image_url? }` (all strings). `image_url` is a full link; Android shows it as the notification's big picture without app code. iOS shows it only with a Notification Service Extension (the API already sends `mutable-content`), otherwise the picture is in the inbox only. `image_url` is `null` / absent for a text-only broadcast, and older app builds ignore it.
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
| Shared with Forms & Polls | `PickableStudent` / `studentIdOf`, `StudentPickerSource`, `StudentPickerHost`, `StudentPickerScreen` |
| Student picker UI | A full screen (`features/shared/screens/student_picker_screen.dart`): the shared collapsing header (`PhonebookHeaderDelegate`) with the selected count, the search bar below it, pull-to-refresh, Residents / Alumni / All tabs with counts (opens on Residents; swipe the page left or right to move between them, with a line sliding under the active tab), removable chips for the picked students with **Clear**, and a pinned **Done** button. While the keyboard is up, the chips and Done are hidden so results stay visible. |
| Student filters | The tune button beside the search opens **Floor / Group / Tag** choices (`student_filter_sheet.dart`), built from the loaded rows (`floor_id`, `group_name`, `tags`; never the phonebook cache; group spellings that differ only in case or spaces are one group). Several choices in one section widen the list; sections narrow each other. Filters only narrow what is shown: picked students stay picked. |
| Tag picker | **By tag → Add** opens `features/shared/screens/tag_picker_screen.dart`: search, multi-select, student count per tag, pull-to-refresh (a deleted tag is unselected). Both pickers share `PickerScaffold`. |
| Picks in Compose (tags and students) | `SelectedList`: an expandable box, closed at first, showing the count, the names on one line and **Clear all**; open, one row each with a remove button (over 5 rows also get **Collapse** at the bottom). The **Send to** choice (rule 10) stays under the tags. |
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
