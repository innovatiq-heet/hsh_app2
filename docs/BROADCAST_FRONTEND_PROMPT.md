# Prompt: Broadcast messages — Flutter app (`hsh_app2`)

> Paste everything below the line into a Claude Code session in this repo.

---

Build a **Broadcast** feature in this Flutter app. An **admin** writes a custom message (title + text), picks recipients **by student tag** and/or **individually**, sees how many students it will reach, and taps **Send**. Each recipient gets a push notification and can read it in an in-app **inbox**. The admin can see sent broadcasts with delivery and read counts.

**The backend (`hsh_api`) isn't built yet**; it's being built in parallel against the contract in section 3. Code against that contract exactly, and cover it with offline tests using `test/support/fake_api.dart`. Don't call the real API in tests, and don't invent fields beyond the contract. If something in the contract blocks you, stop and tell me rather than working around it.

Read `AGENTS.md` first and follow it: GetX feature layout, `Get.find<ApiClient>().dio`, repositories that throw, controllers that show errors and roll back, closing pages with `Navigator.of(context).pop()` after a success snackbar, reusing shared widgets, docs updates and tests.

## 1. Rules (must hold)

1. **Only `admin`** sees and opens the admin screens. Add the operator-home tile with `adminOnly: true` (like **Manage User**), and also check the role in the controller's `onInit`, closing with "Access Denied" the way `PhonebookController` does.
2. **Students are identified only by numeric `students.id`** (AGENTS.md §4). The individual picker must get students from a source that has `students.id`: `TagsRepository.getStudentsForAssignment()` (`/students?all=true`), falling back to `ScreenTimeRepository.students(...)`, the same as `assign_tag_screen.dart`. **Never** use the phonebook cache (`HSH-…` / bank codes) here. A test must assert that every `student_ids` value sent is an integer from that source.
3. **No double send.** Create one `client_request_id` (UUID) when the compose screen opens, and reuse it for every retry of that send. Disable **Send** while sending; a double tap must make a single request.
4. **Confirm before sending:** a dialog reading "Send 'Title' to N students?" (N from preview). Mention students without the app when `no_device_count > 0` ("5 have no device; they'll see it in the inbox").
5. **Nothing is lost on a failed send:** keep the title, message and audience on screen, show the server's `message` as-is, and let the admin retry with the same `client_request_id`.
6. Send is enabled only when the title (1–100 characters) and message (1–2000 characters) are valid **and** the preview count is > 0. Show live character counters.

## 2. Screens and flow

**A. Operator home → "Broadcast" tile** (admin only), in the *Hostel Services & Staff* group. It opens **Broadcast history**.

**B. Broadcast history** (`Routes.operatorBroadcasts`)
- The admin's sent broadcasts, newest first, paged (`limit` 20), with pull-to-refresh.
- Each card shows the title, the start of the message, the time, the audience (tag chips + "N individual"), and `status`: *Sending…*, *Sent* or *Failed*.
- The card also shows counts: `recipient_count`, `push_sent`, `read_count`.
- If any card is still `sending`, refresh it every 5 seconds while the screen is open.
- A **New broadcast** button opens Compose.
- Empty state uses the shared `EmptyState` widget.

**C. Compose** (`Routes.operatorBroadcastCompose`)
1. Title and message fields, with counters.
2. **Audience by tag:** multi-select chips from `TagsRepository.getTags()`, showing each tag's student count. A student matches if they have *any* selected tag.
3. **Individual students:** an "Add students" button opens a searchable picker by name or room. Reuse the list style of `assign_tag_screen.dart` and `StudentContactCard` where it fits. Picked students show as removable chips.
4. **Live reach:** "Will reach **N** students" from `POST /broadcasts/preview`, debounced 400 ms after any audience change, plus up to 10 sample names. While loading, show a small spinner; on error, show "Couldn't count recipients" with a retry option, and disable Send.
5. **Send** → confirm dialog → `POST /broadcasts` → success snackbar "Sent to N students" → `Navigator.of(context).pop()` back to history, which refreshes.

**D. Broadcast detail** (tap a history card): the full message, the audience, the counts, and the recipient list from `GET /broadcasts/:id`. Each recipient shows name, room, a push-status icon and read time. Add a filter: All / Read / Unread / No device.

**E. Recipient inbox** (students / leaders)
- An **Announcements** screen (`Routes.broadcastInbox`) reachable from the student **More** screen (`Routes.services`). Show an unread badge from `unread_count` on that entry if the screen supports badges.
- Opening a message calls `POST /me/broadcasts/:id/read`, optimistically: mark it read in the list, and roll back if the request fails.
- **Push tap:** in `PushNotificationService._navigateFromPayload`, add `case 'broadcast':`, which opens the inbox message with `broadcast_id`. It must work in all three cases: app in the foreground, in the background, and launched from a killed state. Foreground notifications use the existing local-notification path.

## 3. API contract (shared with the backend; don't change it)

All responses use `{ "success": true, "data": … }`, or `{ "success": false, "message": "…" }` on errors; show the error `message` as-is. Dates are ISO 8601 UTC, shown in local time with the helpers in `lib/core/utils/date_formatting.dart`.

| Method & path | Who | Request | Response `data` |
| :--- | :--- | :--- | :--- |
| `POST /broadcasts/preview` | admin | `{ tag_ids: int[], student_ids: int[] }` | `{ recipient_count, no_device_count, sample: [{ id, name, room }] }` (an empty audience gives `0`, not an error) |
| `POST /broadcasts` | admin | `{ client_request_id, title, message, tag_ids, student_ids }` | `<Broadcast>`: `201` new, `200` repeat of a known `client_request_id` (treat both as success) |
| `GET /broadcasts?limit&offset` | admin | — | `[<Broadcast>]`, plus top-level `total` |
| `GET /broadcasts/:id` | admin | — | `<Broadcast>` + `recipients: [{ student_id, name, room, matched_by, push_status, read_at }]` |
| `GET /me/broadcasts?limit&offset` | student | — | `[{ id, title, message, sender_name, created_at, read_at }]`, plus top-level `total`, `unread_count` |
| `POST /me/broadcasts/:id/read` | student | — | `{ id, read_at }` (idempotent) |

`<Broadcast>` = `{ id, title, message, tags: [{ id, name, color }], student_ids: int[], status: "sending"|"sent"|"failed", recipient_count, push_sent, push_failed, no_device, read_count, sender: { id, name }, created_at, completed_at }`.

- `matched_by` is `tag`, `individual` or `both`. `push_status` is `pending`, `sent`, `failed` or `no_device`.
- Status codes: `400` validation, `401` signed out (existing interceptor), `403` wrong role, `404` not found, `422` "No active students match this audience."
- Push data payload, all strings: `{ type: "broadcast", broadcast_id, title, body }`.

## 4. Code layout

- `lib/core/network/repository/broadcasts/broadcasts_repository.dart`: all six calls, using the `_guard` / `toApiException` pattern from `StudentContactsRepository`.
- `lib/core/models/broadcasts/broadcast_models.dart`: `Broadcast`, `BroadcastRecipient`, `BroadcastPreview`, `InboxBroadcast`. Parse defensively: ints may arrive as strings, and unknown `status` values must be tolerated.
- `lib/features/broadcast/`: `bindings`, `controllers` (history, compose, detail, inbox), `views`, `widgets` (audience tag chips, student picker sheet, reach banner, broadcast card).
- Routes plus bindings in `app_routes.dart` / `app_pages.dart`; the tile in `operator_home_screen.dart`; the inbox entry on the student More screen; the `broadcast` case in `push_notification_service.dart`.
- Match the existing visual style: colours from `AppColors`, `AppDimens` spacing, and the card look used in the phonebook and Manage Users.

## 5. Tests (offline, `FakeApi`)

Add `test/broadcast_compose_test.dart`, `test/broadcast_history_test.dart` and `test/broadcast_inbox_test.dart`. They must check:
1. The preview request carries the selected `tag_ids` and `student_ids`, and a fast series of audience edits leads to **one** debounced request.
2. Every `student_ids` value sent is an `int` taken from the `students.id` source; no `HSH-…` or bank-code strings.
3. Send body has the trimmed title and message and a `client_request_id`. A double tap leads to **one** POST. A retry after a `500` reuses the **same** `client_request_id`.
4. `201` and `200` both count as success. `400` / `422` show the server `message`, and the form keeps its contents.
5. Send stays disabled for invalid lengths, a preview count of 0, or a preview error.
6. A non-admin role is sent away from the admin screens.
7. History parses `<Broadcast>`, pages with `offset`, and polls only while a broadcast is `sending`.
8. Inbox: opening a message marks it read optimistically and rolls back on failure; `unread_count` updates.
9. The push payload `{type: "broadcast", broadcast_id: "91"}` navigates to the inbox message.

## 6. Docs and finish

- Create `docs/BROADCAST_DOCS.md`, in the same style as the other feature docs. It should cover what the feature does, the screens, the contract table, the rules from section 1, and the tests. Add it to the feature-docs list in `AGENTS.md`.
- Run `bash scripts/check.sh` and report the result. A failure that already existed before your change should be named as such, not hidden.
- Don't commit unless I ask. Reply with:
  - files changed;
  - anything in the contract you had to assume;
  - what can only be checked once the backend is live (real push delivery, iOS background tap).
