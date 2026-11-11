# Prompt: Broadcast messages — backend (`hsh_api`)

> Paste everything below the line into the backend chat (repo `hsh_api`, Node + Express + MySQL).

---

Build a **Broadcast** feature in `hsh_api`. An admin writes a custom message, picks recipients **by student tag** and/or **individually**, and sends it. Every recipient gets a **push notification** and can read the message in an **in-app inbox**. The admin can see what was sent and how many recipients received and read it.

The Flutter app (`hsh_app2`) is built **in parallel against the API contract in section 3**. Implement that contract exactly. If you have to change a path, a field name or a status code, list the change at the end of your reply so the app side can be updated.

Read `AGENTS.md` first and follow this repo's existing patterns: module layout, auth middleware, role checks, validation, the `{ success, data }` / `{ success, message }` responses, migrations and e2e tests. Reuse the existing FCM sending code and the tokens stored by `POST /auth/fcm-token`; don't add a second push setup.

## 1. Rules (must hold)

1. **Who can send:** `admin` only. Any other role gets `403`. If wardens should send too, that's a one-line change later; keep the role check in one place.
2. **Who can receive:** students, including `leader`, who are students. Only **active** students: never alumni, students who left or cancelled, or deactivated accounts. Use the same "active student" definition that other modules (attendance, tags) already use.
3. **Students are identified only by the numeric `students.id`.** Never accept or resolve a bank code, `student_code` or `HSH-…` value as a student identifier. Bank codes are numeric and collide with other students' ids; this once made a Screen Time lock hit the wrong student. Reject non-integer ids with `400`.
4. **Recipients = (students with ANY of the selected tags) ∪ (individually selected students)**, deduplicated, then filtered to active students. A student matched by both a tag and an individual pick gets **one** message.
5. **Recipients are frozen when sending.** Store one row per recipient when the broadcast is created. Later tag changes must not change who received an old broadcast.
6. **No double sends.** The app sends a `client_request_id` (a UUID) with each send. A repeated `(sender, client_request_id)` returns the **original** broadcast with `200` and sends nothing again.
7. **Sending doesn't block the request.** Save the broadcast and its recipients in one transaction, reply `201`, then send the pushes in the background. Use FCM multicast, 500 tokens per batch. Update counts when done. Delete or flag tokens FCM reports as unregistered, using the same clean-up the existing push code does, if any.
8. A student with **no device token** still gets the inbox message. They're counted as `no_device`, not as a failure.
9. **Limits:** `title` 1–100 characters, `message` 1–2000 characters (both trimmed), at most 20 tags, at most 500 individual students, and at least one tag or student. If the final recipient set is empty → `422` with `message: "No active students match this audience."`.

## 2. Database (migration)

```sql
CREATE TABLE broadcasts (
  id                 BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sender_user_id     INT UNSIGNED NOT NULL,              -- users.id of the admin
  client_request_id  VARCHAR(64)  NOT NULL,
  title              VARCHAR(100) NOT NULL,
  message            TEXT         NOT NULL,
  tag_ids            JSON         NOT NULL,              -- audience as chosen, for history display
  student_ids        JSON         NOT NULL,
  status             ENUM('sending','sent','failed') NOT NULL DEFAULT 'sending',
  recipient_count    INT UNSIGNED NOT NULL DEFAULT 0,
  push_sent          INT UNSIGNED NOT NULL DEFAULT 0,
  push_failed        INT UNSIGNED NOT NULL DEFAULT 0,
  no_device          INT UNSIGNED NOT NULL DEFAULT 0,
  created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at       DATETIME     NULL,
  UNIQUE KEY uq_sender_request (sender_user_id, client_request_id),
  KEY idx_sender_created (sender_user_id, created_at)
);

CREATE TABLE broadcast_recipients (
  broadcast_id   BIGINT UNSIGNED NOT NULL,
  student_id     INT UNSIGNED    NOT NULL,               -- students.id
  matched_by     ENUM('tag','individual','both') NOT NULL,
  push_status    ENUM('pending','sent','failed','no_device') NOT NULL DEFAULT 'pending',
  read_at        DATETIME NULL,
  PRIMARY KEY (broadcast_id, student_id),
  KEY idx_student_broadcast (student_id, broadcast_id),
  CONSTRAINT fk_br_broadcast FOREIGN KEY (broadcast_id) REFERENCES broadcasts(id) ON DELETE CASCADE
);
```

Match the column types of `users.id` and `students.id`, and add foreign keys to them the way other tables here do.

## 3. API contract (the app is coded against this)

All responses use `{ "success": true, "data": … }`, or `{ "success": false, "message": "…" }` on errors. The `message` is shown to the admin as-is, so keep it human-readable. Dates are ISO 8601 UTC.

### Admin (role `admin`)

**`POST /broadcasts/preview`**: how many students the current audience reaches. The app calls it, debounced, while the admin edits the audience.
```json
// request
{ "tag_ids": [3, 7], "student_ids": [102, 215] }
// 200
{ "success": true, "data": {
    "recipient_count": 48,
    "no_device_count": 5,
    "sample": [ { "id": 102, "name": "Parth Patel", "room": "204" } ]   // up to 10, sorted by name
} }
```
An empty audience returns `recipient_count: 0`, with `200`, not an error.

**`POST /broadcasts`**: send.
```json
// request
{ "client_request_id": "6f1c…-uuid", "title": "Water supply", "message": "No water 2–4 pm today.",
  "tag_ids": [3, 7], "student_ids": [102, 215] }
// 201 (new) or 200 (same client_request_id seen before: the original broadcast)
{ "success": true, "data": <Broadcast> }
```
Errors: `400` for validation (the message names the field), `403` for a role that isn't admin, `422` for an empty audience.

**`GET /broadcasts?limit=20&offset=0`**: this admin's sent broadcasts, newest first.
```json
{ "success": true, "data": [ <Broadcast>, … ], "total": 57 }
```

**`GET /broadcasts/:id`**: one broadcast with its recipients. Return `404` if it doesn't exist or wasn't sent by this admin.
```json
{ "success": true, "data": { …<Broadcast>,
    "recipients": [ { "student_id": 102, "name": "Parth Patel", "room": "204",
                      "matched_by": "both", "push_status": "sent", "read_at": null } ] } }
```

`<Broadcast>` object:
```json
{ "id": 91, "title": "Water supply", "message": "No water 2–4 pm today.",
  "tags": [ { "id": 3, "name": "Floor 2", "color": "#0284C7" } ],
  "student_ids": [102, 215],
  "status": "sending",            // sending | sent | failed
  "recipient_count": 48, "push_sent": 0, "push_failed": 0, "no_device": 0, "read_count": 0,
  "sender": { "id": 1, "name": "Super Admin" },
  "created_at": "2026-11-11T09:30:00.000Z", "completed_at": null }
```

### Recipient (logged-in student / leader)

**`GET /me/broadcasts?limit=20&offset=0`**: this student's inbox, newest first.
```json
{ "success": true, "data": [ { "id": 91, "title": "Water supply", "message": "No water 2–4 pm today.",
    "sender_name": "Super Admin", "created_at": "2026-11-11T09:30:00.000Z", "read_at": null } ],
  "total": 12, "unread_count": 3 }
```

**`POST /me/broadcasts/:id/read`**: marks one broadcast as read. It's idempotent: marking an already-read broadcast again returns `200` and keeps the first `read_at`. A broadcast not addressed to this student → `404`.
```json
{ "success": true, "data": { "id": 91, "read_at": "2026-11-11T09:41:00.000Z" } }
```

### Push payload (FCM)

Send a **notification plus data** message:
- notification: `title` = broadcast title, `body` = the message, cut to 180 characters.
- data, all values strings:
```json
{ "type": "broadcast", "broadcast_id": "91", "title": "Water supply", "body": "No water 2–4 pm today." }
```
The app opens the inbox message when `type == "broadcast"`. On Android, use the same notification channel as the app's other alerts. Set high priority for both Android and iOS (APNs).

## 4. Tests (`tests/e2e/broadcasts.e2e.test.ts`, existing e2e setup, mock FCM)

1. Preview: tag ∪ individuals, deduplicated; alumni, left and inactive students are excluded; `no_device_count` is correct.
2. Send: creates one row per recipient with the correct `matched_by` (`tag` / `individual` / `both`) and returns `201`. Push is sent once per token, with `type: "broadcast"` and `broadcast_id`.
3. The same `client_request_id` sent twice → second call returns `200` with the same `id`; no new rows, no second push.
4. Validation: empty or too-long title or message, no audience, more than 20 tags or 500 students, a non-integer or bank-code-like value in `student_ids` → `400`. An audience that ends up empty → `422`.
5. Roles: warden, student and staff get `403` on the admin routes; no token gets `401`.
6. Recipients are frozen: changing a student's tags after sending doesn't change `GET /broadcasts/:id` recipients.
7. Inbox: a student sees only broadcasts addressed to them; `unread_count` is correct; `read` is idempotent; reading another student's broadcast → `404`.
8. Counts: after the background send, `status` becomes `sent` and `push_sent` / `push_failed` / `no_device` / `read_count` add up. If FCM fails entirely, `status` is `failed`, but the inbox rows still exist.
9. History: `GET /broadcasts` lists only the caller's broadcasts, newest first, with correct `total`.

## 5. Docs and finish

- Add the "students only by numeric `students.id`" rule for this module to `hsh_api/AGENTS.md`, and document the endpoints wherever this repo documents routes.
- Run the repo's full check (`npm run check`, including e2e) and report the result.
- Reply with:
  - files changed;
  - the migration name;
  - any deviation from the section 3 contract;
  - how to trigger a test broadcast on staging.
