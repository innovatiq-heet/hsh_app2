# Prompt: Broadcast messages (In-App & WhatsApp) — backend (`hsh_api`)

> Paste everything below the line into the backend chat (repo `hsh_api`, Node + Express + MySQL).

---

Build an enhanced **Broadcast** feature in `hsh_api`. An admin writes a custom message, picks recipients **by student tag** and/or **individually**, and sends it across configurable delivery channels: **In-App** (push notification + student inbox), **WhatsApp** (direct message via the linked WhatsApp session), or **Both**.

The **title is optional** (not compulsory). When omitted, quick messages are broadcast directly without requiring a formal heading.

The Flutter app (`hsh_app2`) is built in parallel against the API contract in section 3. Implement that contract exactly. If you have to change a path, a field name or a status code, list the change at the end of your reply so the app side can be updated.

Read `AGENTS.md` first and follow this repo's existing patterns: module layout, auth middleware, role checks, validation, the `{ success, data }` / `{ success, message }` responses, migrations and e2e tests.
- For push notifications: reuse the existing FCM sending code and tokens stored by `POST /auth/fcm-token`.
- For WhatsApp: reuse the existing linked WhatsApp engine/socket in `hsh_api` (used by the Birthday module under `src/modules/whatsapp/`).

---

## 1. Rules (must hold)

1. **Who can send:** `admin` only. Any other role gets `403`.
2. **Who can receive:** students, including `leader`, who are active residents. Never alumni, students who left or cancelled, or deactivated accounts.
3. **Student identity:** identify students **only by numeric `students.id`**. Never accept or resolve a bank code, `student_code` or `HSH-…` id. Bank codes collide with student IDs; reject non-integer IDs with `400`.
4. **Recipients = (students with ANY selected tags) ∪ (individually selected students)**, deduplicated, then filtered to active students. A student matched by both a tag and an individual pick gets **one** delivery.
5. **Frozen recipients:** save one row per recipient when the broadcast is created. Subsequent student tag or phone changes must not alter historic broadcast recipients.
6. **No double sends:** the app sends a `client_request_id` (UUID). A repeated `(sender, client_request_id)` returns the **original** broadcast with `200` without re-dispatching.
7. **Title is optional:**
   - `title` is `1–100` characters when provided, or `null`/empty when omitted.
   - For push notifications when `title` is null/empty: FCM notification title defaults to `"Notice from Admin"`, body is the message cut to 180 characters.
   - For WhatsApp when `title` is provided: formatted as `*${title}*\n\n${message}`. When `title` is null/empty: sent as `${message}` directly.
   - For in-app inbox: title can be null, the app falls back to `"Notice from Admin"` or sender name.
8. **Delivery channels (`channels`):**
   - Options: `'app'` (In-App push + inbox only), `'whatsapp'` (WhatsApp only), `'both'` (both In-App and WhatsApp). Defaults to `'both'`.
   - When channel does not include `'app'`: `push_status` is set to `'skipped'`.
   - When channel does not include `'whatsapp'`: `whatsapp_status` is set to `'skipped'`.
9. **WhatsApp dispatch & phone resolution:**
   - Resolve student phone number: check `whatsapp_number` first, fallback to `phone` / `mobile` (same priority as Birthday wishes).
   - Normalize to digits with country code (e.g. `919876543210`). Indian 10-digit numbers prepend `91`.
   - If student has no valid number: mark `whatsapp_status = 'no_phone'` and increment `no_whatsapp`.
   - If WhatsApp is requested but the server's WhatsApp session is disconnected:
     - `POST /broadcasts/preview` reports `whatsapp_connected: false`.
     - `POST /broadcasts` still accepts the broadcast, logs a warning, and marks WhatsApp messages as `failed` (or queues them for reconnect) while delivering in-app push normally.
   - Dispatch rate limiting: send WhatsApp messages sequentially with an asynchronous interval (e.g. 600ms–1200ms jitter) in the background worker to avoid anti-spam blocks.
10. **Limits:** `message` 1–2000 characters (trimmed), `title` up to 100 characters, at most 20 tags, at most 500 individual students, and at least one tag or student. Empty audience after filtering → `422` with `message: "No active students match this audience."`.

---

## 2. Database (migration)

```sql
CREATE TABLE broadcasts (
  id                 BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sender_user_id     INT UNSIGNED NOT NULL,              -- users.id of the admin
  client_request_id  VARCHAR(64)  NOT NULL,
  channels           ENUM('app', 'whatsapp', 'both') NOT NULL DEFAULT 'both',
  title              VARCHAR(100) NULL,                  -- optional
  message            TEXT         NOT NULL,
  tag_ids            JSON         NOT NULL,              -- audience as chosen
  student_ids        JSON         NOT NULL,
  status             ENUM('sending','sent','failed') NOT NULL DEFAULT 'sending',
  recipient_count    INT UNSIGNED NOT NULL DEFAULT 0,
  -- In-App Push counters
  push_sent          INT UNSIGNED NOT NULL DEFAULT 0,
  push_failed        INT UNSIGNED NOT NULL DEFAULT 0,
  no_device          INT UNSIGNED NOT NULL DEFAULT 0,
  -- WhatsApp counters
  whatsapp_sent      INT UNSIGNED NOT NULL DEFAULT 0,
  whatsapp_failed    INT UNSIGNED NOT NULL DEFAULT 0,
  no_whatsapp        INT UNSIGNED NOT NULL DEFAULT 0,
  -- Inbox read counter
  read_count         INT UNSIGNED NOT NULL DEFAULT 0,
  created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at       DATETIME     NULL,
  UNIQUE KEY uq_sender_request (sender_user_id, client_request_id),
  KEY idx_sender_created (sender_user_id, created_at)
);

CREATE TABLE broadcast_recipients (
  broadcast_id      BIGINT UNSIGNED NOT NULL,
  student_id        INT UNSIGNED    NOT NULL,            -- students.id
  matched_by        ENUM('tag','individual','both') NOT NULL,
  push_status       ENUM('pending','sent','failed','no_device','skipped') NOT NULL DEFAULT 'pending',
  whatsapp_status   ENUM('pending','sent','failed','no_phone','skipped') NOT NULL DEFAULT 'pending',
  whatsapp_phone    VARCHAR(20)     NULL,                -- phone number sent to
  whatsapp_sent_at  DATETIME        NULL,
  read_at           DATETIME        NULL,
  PRIMARY KEY (broadcast_id, student_id),
  KEY idx_student_broadcast (student_id, broadcast_id),
  CONSTRAINT fk_br_broadcast FOREIGN KEY (broadcast_id) REFERENCES broadcasts(id) ON DELETE CASCADE
);
```

---

## 3. API Contract

All responses use `{ "success": true, "data": … }` or `{ "success": false, "message": "…" }`. Dates are ISO 8601 UTC.

### Admin (role `admin`)

#### `POST /broadcasts/preview`
Calculates audience reach across both channels and checks WhatsApp connection status.
```json
// request
{ "tag_ids": [3, 7], "student_ids": [102, 215] }

// 200 response
{
  "success": true,
  "data": {
    "recipient_count": 48,
    "no_device_count": 5,
    "no_whatsapp_count": 2,
    "whatsapp_connected": true,
    "sample": [
      { "id": 102, "name": "Parth Patel", "room": "204", "phone": "9876543210" }
    ]
  }
}
```

#### `POST /broadcasts`
Creates and sends a broadcast. Title is optional.
```json
// request (Both channels, with title)
{
  "client_request_id": "6f1c2d3e-4b5a-4c6d-8e9f-0a1b2c3d4e5f",
  "channels": "both",                                   // "app" | "whatsapp" | "both" (default: "both")
  "title": "Water supply maintenance",                  // optional, can be omitted or null
  "message": "Water supply will be paused from 2 PM to 4 PM today for maintenance.",
  "tag_ids": [3, 7],
  "student_ids": [102, 215]
}

// request (WhatsApp only, no title)
{
  "client_request_id": "8a2b3c4d-...",
  "channels": "whatsapp",
  "message": "Dinner is served in dining hall 2 tonight.",
  "tag_ids": [3],
  "student_ids": []
}

// 201 response (new) or 200 (idempotent retry with same client_request_id)
{
  "success": true,
  "data": {
    "id": 91,
    "channels": "both",
    "title": "Water supply maintenance",
    "message": "Water supply will be paused from 2 PM to 4 PM today for maintenance.",
    "tags": [ { "id": 3, "name": "Floor 2", "color": "#0284C7" } ],
    "student_ids": [102, 215],
    "status": "sending",
    "recipient_count": 48,
    "push_sent": 0,
    "push_failed": 0,
    "no_device": 0,
    "whatsapp_sent": 0,
    "whatsapp_failed": 0,
    "no_whatsapp": 0,
    "read_count": 0,
    "sender": { "id": 1, "name": "Super Admin" },
    "created_at": "2026-11-15T09:30:00.000Z",
    "completed_at": null
  }
}
```

#### `GET /broadcasts?limit=20&offset=0`
History of broadcasts sent by this admin, newest first. Includes channels, push and WhatsApp stats.
```json
{
  "success": true,
  "data": [
    {
      "id": 91,
      "channels": "both",
      "title": "Water supply maintenance",
      "message": "Water supply will be paused from 2 PM to 4 PM today...",
      "status": "sent",
      "recipient_count": 48,
      "push_sent": 43,
      "push_failed": 0,
      "no_device": 5,
      "whatsapp_sent": 46,
      "whatsapp_failed": 0,
      "no_whatsapp": 2,
      "read_count": 31,
      "created_at": "2026-11-15T09:30:00.000Z",
      "completed_at": "2026-11-15T09:30:45.000Z"
    }
  ],
  "total": 57
}
```

#### `GET /broadcasts/:id`
Single broadcast with per-recipient push, WhatsApp, and read status breakdown.
```json
{
  "success": true,
  "data": {
    "id": 91,
    "channels": "both",
    "title": "Water supply maintenance",
    "message": "...",
    "recipients": [
      {
        "student_id": 102,
        "name": "Parth Patel",
        "room": "204",
        "matched_by": "both",
        "push_status": "sent",
        "whatsapp_status": "sent",
        "whatsapp_phone": "919876543210",
        "whatsapp_sent_at": "2026-11-15T09:30:04.000Z",
        "read_at": "2026-11-15T09:45:00.000Z"
      }
    ]
  }
}
```

---

### Recipient (Student / Leader)

#### `GET /me/broadcasts?limit=20&offset=0`
Student inbox list. `title` may be null.
```json
{
  "success": true,
  "data": [
    {
      "id": 91,
      "title": null,
      "message": "Dinner is served in dining hall 2 tonight.",
      "sender_name": "Super Admin",
      "created_at": "2026-11-15T09:30:00.000Z",
      "read_at": null
    }
  ],
  "total": 12,
  "unread_count": 3
}
```

#### `POST /me/broadcasts/:id/read`
Marks broadcast read in inbox. Idempotent. Returns `{ "success": true, "data": { "id": 91, "read_at": "..." } }`.

---

## 4. Tests (`tests/e2e/broadcasts.e2e.test.ts`)

1. **Title optional:** sending with valid `title` succeeds; sending without `title` or with `null` succeeds; `message` without `title` returns `201`.
2. **Channels validation:** sending `channels: 'app'`, `channels: 'whatsapp'`, and `channels: 'both'` correctly sets recipient `push_status` and `whatsapp_status` (unselected channel is set to `'skipped'`).
3. **Audience & Deduplication:** tag ∪ individual picks deduplicated; numeric `students.id` enforced.
4. **Idempotency:** same `client_request_id` returns initial broadcast `200` without second FCM or WhatsApp dispatch.
5. **Push Payload:** when title is null, FCM push uses `"Notice from Admin"`.
6. **WhatsApp formatting:** when title is null, WhatsApp body is plain message; when title exists, formatted with bold title.
7. **Inbox:** student sees their broadcasts; null titles returned as null without crashing; read status updates `read_count`.
8. **Permissions:** `admin` allowed; warden, student, staff return `403`.
