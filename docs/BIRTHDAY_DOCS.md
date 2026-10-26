# Birthday Wishes

> **Last updated:** 2026-10-26 · **Repos:** `hsh_app2` (admin Template Studio), `hsh_api` (stores the config and sends the WhatsApp wishes).

---

## 1. What this feature does

Admins configure automatic WhatsApp birthday wishes in **Birthday → Template Studio**:

- **Delivery setup:** daily send time (IST), target audience (`student_only`, `parent_only`, `student_and_parent`) and an optional admin digest number.
- **Wish templates:** any number of saved templates, kept separately for **Students** and **Parents**. Each audience has exactly one **active** template, which is the one that gets sent. Tap a template to edit it, use **Set active** to switch, and delete any template except the active one.
- **Live preview:** the WhatsApp mockup updates while typing, with sample data (Rahul Sharma, room 306, HSH-105).

Placeholders, filled the same way by the app (`AdminBirthdayController.fillTemplate`) and the API:

| Placeholder | Value |
| :--- | :--- |
| `{first_name}` | First word of the student's name |
| `{student_name}`, `{name}` | Full name |
| `{room}`, `{room_number}` | Room ('' if none in the app; the API writes `N/A`) |
| `{student_code}`, `{code}` | Student code |

Parent templates are still about the student, so they use the same placeholders.

Who sends what:

| Send path | Where | Template used |
| :--- | :--- | :--- |
| Daily automatic run | `hsh_api` | Active student template to students, active parent template to parents |
| "Send to all today" (`POST /whatsapp/birthday/trigger`) | `hsh_api` | Same as above |
| Test wish (`trigger` with `testPhone`) | `hsh_api` | Active student template |
| "Send wish" on one student (opens WhatsApp) | App | Active student template |

The app saves any unsaved template edits before calling `trigger`.

### Student cards

Today / Tomorrow celebrant cards and Directory rows show a status chip styled like the phonebook card:

- **Alumni** (purple) when the student has no room / `N/A`, `isActive` is false, or the status says left / cancelled / alumni (same rule as `PhonebookStudent.isAlumni`). Alumni cards hide the room.
- Otherwise the **group** (Param, Pavitra, Pulkit, Paramanand) in the group's colour, or **Active** when the group is unknown.

The group comes from the student's `groupName` in the API when present. When the API has none (students not synced from the directory since the group was added), the app looks the student up in the phonebook synced on the admin's phone by bank code (`studentCode`, leading zeros ignored); if that phone has never synced the phonebook, the Birthday screen syncs the directory once on open. This lookup is **display only**; a code shared by phonebook rows that disagree shows no group.

### Dispatch logs

Logs (Logs & Test tab) are grouped under date headers (Today, Yesterday, `Thu, 23 Oct 2026`) with sent / failed counts, and a row of date chips filters to one day. A log's date is its `wishDate`, or the IST day of `sentAt`. Each row shows the time sent and whether it went to the Student or the Parent.

The dashboard only carries the most recent logs. **Pick a day** (first chip) opens a calendar and loads every wish logged that day from `GET /whatsapp/birthday/logs` (`AdminBirthdayController.loadLogsForDate`); the day is merged with the recent logs and selected. A day with no wishes shows "No wishes were logged on …".

### Linking WhatsApp (sender device)

The **Link Device** sheet offers two ways to link the WhatsApp account that sends the wishes:

| Option | When | Flow |
| :--- | :--- | :--- |
| 1. Pairing code | Linking the WhatsApp on the phone you're holding | Enter that phone's number, tap **Get Code**, paste the code in WhatsApp |
| 2. Scan QR | Linking from a second phone | Scan the QR with the other phone (WhatsApp → Linked devices → Link a device) |

Pairing code, as the app does it:

1. The number is normalized to digits with country code (`AdminBirthdayController.normalizeWhatsAppNumber`): `98765 43210`, `+91 98765 43210` and `09876543210` all become `919876543210`. A bare 10-digit number is treated as Indian. Without the country code WhatsApp issues the code for another number, so no "Enter code" notification arrives and the code is rejected.
2. `POST /whatsapp/disconnect`, a short wait, then `POST /whatsapp/pair {phone}`. The backend's `message` is shown if it refuses. (`/pair` also starts a fresh session itself and can take up to ~20 s while the socket comes up.)
3. The code is copied to the clipboard and shown with the number it is for. The steps say to open WhatsApp and tap the **"Enter code to link new device"** notification, or go to Linked devices → Link a device → **Link with phone number instead**.
4. **Open WhatsApp** calls `launchUrl('whatsapp://')` (then `https://wa.me/`) directly; `canLaunchUrl` would need the scheme declared in Android `<queries>` / iOS `LSApplicationQueriesSchemes`.
5. While a code is shown, the QR option is paused (`POST /whatsapp/connect` restarts the session and cancels the code). **Use QR instead** drops the code.
6. `GET /whatsapp/status` is polled every 3.5 s while the sheet is open; `data.user.phone` means linked.

---

## 2. API contract

### `GET /whatsapp/birthday` → `data.config`

```jsonc
{
  "id": 1,
  "isEnabled": true,
  "sendTime": "08:00",
  "targetAudience": "student_and_parent",
  "preferWhatsAppNumber": true,
  "adminNotificationPhone": null,
  "messageTemplate": "Dear {student_name}, ...",          // active student template body
  "parentMessageTemplate": "Dear Parent, ...",            // active parent template body (null when unset)
  "templates": [                                          // the whole library ([] when none saved yet)
    { "id": "default_student", "name": "Default student wish", "body": "Dear {student_name}, ...", "audience": "student" },
    { "id": "tpl_1729850000000000", "name": "Diwali parents", "body": "Dear Parent, ...", "audience": "parent" }
  ],
  "activeStudentTemplateId": "default_student",
  "activeParentTemplateId": "tpl_1729850000000000",
  "imageUrl": null,
  "lastRunDate": "2026-10-24"
}
```

The app also accepts snake_case (`parent_message_template`, `active_student_template_id`, `active_parent_template_id`), and `templates` as either an array or a JSON string.

Each student in `todaysBirthdays`, `tomorrowsBirthdays` and `GET /whatsapp/birthday/all-students` also has:

| Field | Value |
| :--- | :--- |
| `groupName` | `Param`, `Pavitra`, `Pulkit`, `Paramanand` (canonical spelling), another value as stored, or `null` |
| `status` | Admission status as the directory stores it: `renewed-admission`, `new-admission`, `pending-admission`, `not-fill`, `left`, `cancel-admission`, `rejected-admission`, or `null` |

### `POST /whatsapp/birthday/config`

The app sends every field above (except `id` / `lastRunDate`). Template ids are generated by the app (`default_student`, `default_parent`, `tpl_<microseconds>`); the API stores them as they are. `messageTemplate` and `parentMessageTemplate` are always the bodies of the active templates, so the sender never has to look anything up in `templates`.

The API merges the request into the saved config (fields left out keep their value) and rejects it with **400** `{ success: false, message }` when:

- `templates` is not an array of `{id, name, body, audience}`: ids 1–64 characters and unique, `audience` `student` or `parent`, `name` text of at most 100 characters, `body` text of at most 4,000 characters, at most 50 templates. Drafts may have an empty name or body.
- An `active…TemplateId` is set but doesn't match a template of that audience.
- `messageTemplate` is empty, or `parentMessageTemplate` is empty while `targetAudience` includes parents.

The app checks the same rules before saving (`AdminBirthdayController.templateProblem`) and shows the API's `message` if a save is still rejected.

### `GET /whatsapp/birthday/logs`

`?date=YYYY-MM-DD`, or `?from=YYYY-MM-DD&to=YYYY-MM-DD` (inclusive, by `wishDate`); `limit` defaults to and is capped at 500. Returns `{ success: true, data: [...] }` with the same log objects as `recentLogs`, newest first. Without a date it returns the recent logs. Bad dates or `from` after `to` give 400.

### `POST /whatsapp/pair`

`{ phone }` must be digits with country code (`^[1-9][0-9]{10,14}$`), else 400. 409 when WhatsApp is already linked, or when the new session isn't ready within ~20 s. On success `{ success: true, code }`.

### Older API

The app also keeps the library and active picks in `SharedPreferences` (`birthday_templates_v1`) and uses that copy while `GET` returns no templates (an `hsh_api` without these fields, or nothing saved yet; an old API sends `messageTemplate` to everyone, parents included). Once `GET` returns a non-empty `templates`, the server's library is used.

---

## 3. How `hsh_api` implements it

- **Schema:** `whatsapp_birthday_config` has `parent_message_template`, `templates` (JSON), `active_student_template_id` and `active_parent_template_id`. `students.group_name` and `students.student_status` hold the directory's `groupName` / `status`, filled by the student sync (server start and `POST /students/sync`); "not Available" groups are stored as NULL.
- **Sender** (`src/services/birthdayWishes.ts`, daily job and `trigger`): parents get `parentMessageTemplate`, falling back to `messageTemplate` when it's empty; students and the test wish get `messageTemplate`. Placeholders are filled as in the table in section 1, `{code}` included.
- **Pairing** (`src/services/whatsapp.ts`): `/pair` refuses a linked session, clears the unlinked one, starts a socket (`Browsers.macOS('Chrome')`, slower QR rotation so it stays up while the code is typed), waits for its first QR and only then calls `requestPairingCode`. Status stays `pairing` while QR refs rotate. `GET /whatsapp/status` reports `user` only once the device is actually linked (Baileys sets `creds.me` as soon as a code is requested). After the code is accepted, the 515 restart reconnects with the saved creds; an unfinished pairing is discarded on the next connect instead of attempting a login WhatsApp rejects.
- **Tests:** `tests/e2e/birthday.e2e.test.ts`.

---

## 4. Code map (app)

| File | Role |
| :--- | :--- |
| `lib/core/models/birthday/birthday_models.dart` | `BirthdayTemplate`, `BirthdayAudience`, config, student and log JSON |
| `lib/core/network/repository/birthday/birthday_repository.dart` | Dashboard, save config (API `message` on rejection), logs by day, trigger, WhatsApp linking |
| `lib/features/birthday/controllers/admin_birthday_controller.dart` | Library state, `resolveTemplates` (server → cache → migration), `templateProblem`, save, cache, `fillTemplate`, logs by day (`allLogs`, `loadLogsForDate`) |
| `lib/features/birthday/widgets/template_library.dart` | Students / Parents switch, template list, new / set active / delete |
| `lib/features/birthday/widgets/template_preview.dart` | Live WhatsApp preview |
| `lib/features/birthday/views/admin_birthday_screen.dart` | Template Studio tab layout, dispatch logs with date chips and **Pick a day** |
| `test/birthday_models_test.dart` | Config, student and dashboard JSON parsing |
| `test/birthday_api_contract_test.dart` | Template checks matching the API, log merging, save rejection message, logs-by-day request (fake API) |
