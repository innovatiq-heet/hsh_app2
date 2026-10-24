# Birthday Wishes

> **Last updated:** 2026-10-25 · **Repos:** `hsh_app2` (admin Template Studio), `hsh_api` (stores the config and sends the WhatsApp wishes).

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
| `{room}`, `{room_number}` | Room ('' if none) |
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

The group comes from the student's `groupName` in the API when present. Until the API sends it, the app looks the student up in the phonebook synced on the admin's phone by bank code (`studentCode`, leading zeros ignored). This lookup is **display only**; a code shared by phonebook rows that disagree shows no group.

### Dispatch logs

Logs (Logs & Test tab) are grouped under date headers (Today, Yesterday, `Thu, 23 Oct 2026`) with sent / failed counts, and a row of date chips filters to one day. A log's date is its `wishDate`, or the IST day of `sentAt`. Each row shows the time sent and whether it went to the Student or the Parent.

### Linking WhatsApp (sender device)

The **Link Device** sheet offers two ways to link the WhatsApp account that sends the wishes:

| Option | When | Flow |
| :--- | :--- | :--- |
| 1. Pairing code | Linking the WhatsApp on the phone you're holding | Enter that phone's number, tap **Get Code**, paste the code in WhatsApp |
| 2. Scan QR | Linking from a second phone | Scan the QR with the other phone (WhatsApp → Linked devices → Link a device) |

Pairing code, as the app does it:

1. The number is normalized to digits with country code (`AdminBirthdayController.normalizeWhatsAppNumber`): `98765 43210`, `+91 98765 43210` and `09876543210` all become `919876543210`. A bare 10-digit number is treated as Indian. Without the country code WhatsApp issues the code for another number, so no "Enter code" notification arrives and the code is rejected.
2. `POST /whatsapp/disconnect`, a short wait, then `POST /whatsapp/pair {phone}`. The backend's `message` is shown if it refuses.
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
  "parentMessageTemplate": "Dear Parent, ...",            // NEW: active parent template body
  "templates": [                                          // NEW: the whole library
    { "id": "default_student", "name": "Default student wish", "body": "Dear {student_name}, ...", "audience": "student" },
    { "id": "tpl_1729850000000000", "name": "Diwali parents", "body": "Dear Parent, ...", "audience": "parent" }
  ],
  "activeStudentTemplateId": "default_student",           // NEW
  "activeParentTemplateId": "tpl_1729850000000000",       // NEW
  "imageUrl": null,
  "lastRunDate": "2026-10-24"
}
```

The app also accepts snake_case (`parent_message_template`, `active_student_template_id`, `active_parent_template_id`), and `templates` as either an array or a JSON string.

### `POST /whatsapp/birthday/config`

The app sends every field above (except `id` / `lastRunDate`). Template ids are generated by the app (`default_student`, `default_parent`, `tpl_<microseconds>`); the API stores them as they are. `messageTemplate` and `parentMessageTemplate` are always the bodies of the active templates, so the sender never has to look anything up in `templates`.

### Compatibility (current state)

Until `hsh_api` implements the fields marked NEW:

- It keeps receiving `messageTemplate` (the active student template) and sends that to everyone, **parents included**.
- The template library and active picks are cached on the admin's phone (`SharedPreferences` key `birthday_templates_v1`). Other devices see only the active student template, shown as "Default student wish".
- When `GET` starts returning `templates`, the app uses the server's library and stops relying on the cache.

---

## 3. Changes needed in `hsh_api`

1. **Schema** (birthday config table, one row):

   ```sql
   ALTER TABLE birthday_config
     ADD COLUMN parent_message_template TEXT NULL,
     ADD COLUMN templates JSON NULL,
     ADD COLUMN active_student_template_id VARCHAR(64) NULL,
     ADD COLUMN active_parent_template_id VARCHAR(64) NULL;
   ```

   Use the real table name; this is the shape, not a ready migration.

2. **`GET /whatsapp/birthday`:** return the four new fields in `config` (camelCase like the existing ones). Return `templates` as an array (`[]` when NULL) so the app knows the server supports it.

3. **`POST /whatsapp/birthday/config`:** accept and save the four fields. Validate:
   - `templates` is an array of `{id, name, body, audience}`, `audience` ∈ `student` | `parent`, ids unique, a sensible cap (for example 50 templates, 4,000 characters per body).
   - Each `active…TemplateId`, when set, matches a template of that audience.
   - `messageTemplate` is non-empty; `parentMessageTemplate` is non-empty when `targetAudience` includes parents.
   - Echo the saved config back in `data`, as today.

4. **Sender (daily job + `trigger`):** when building a message for a parent recipient (`recipient_type = 'parent'`), use `parent_message_template`, falling back to `message_template` when it is empty. Students keep `message_template`. Placeholder replacement is unchanged. The test wish (`testPhone`) keeps using `message_template`.

5. **Logs:** `recentLogs[].message` already stores the final text, so parent wishes show their own wording with no change. The app groups logs by date but only sees what `recentLogs` returns; for older days add `GET /whatsapp/birthday/logs?date=YYYY-MM-DD` (or `?from=&to=`) returning the same log objects, and the date chips can then load more.

6. **Student group and status:** add `groupName` (Param, Pavitra, Pulkit, Paramanand) and `status` (as stored, e.g. Active / Left) to each student in `todaysBirthdays`, `tomorrowsBirthdays` and `GET /whatsapp/birthday/all-students`. The app already reads them (`groupName` / `group_name`, `status`) and then stops relying on the phonebook lookup.

7. **WhatsApp pairing code (`POST /whatsapp/pair`).** The QR path works, so the socket and saved-credentials handling are fine; pairing codes fail for reasons specific to them. Check, for Baileys:
   - The `phone` arrives as digits with country code (`919876543210`). Validate it (`^[1-9][0-9]{10,14}$`) and return a clear `message` otherwise.
   - Call `sock.requestPairingCode(phone)` only on a fresh, unregistered session (`!state.creds.registered`) **after** the socket is up: wait for the first `connection.update` that carries `qr` (or `connection === 'connecting'`). Calling it before that returns a code WhatsApp rejects. Ideally `/pair` resets the session and waits for this itself instead of relying on the app's disconnect + 800 ms wait.
   - Use a standard browser tuple in `makeWASocket({ browser: Browsers.macOS('Chrome') })` (or `Browsers.ubuntu('Chrome')`). Custom browser names commonly make phone-number linking fail with "Couldn't link device" even when QR works.
   - Keep that same socket alive while the user switches to WhatsApp and types the code: `GET /whatsapp/status` must not reconnect, regenerate QR or log out, and an expired QR ref must not tear the session down while a code is pending.
   - After the code is accepted Baileys closes with `DisconnectReason.restartRequired` (515); reconnect with the saved creds (same as after a QR scan).
   - Return `{ code }` on success and `{ success: false, message }` with a 4xx on failure; the app shows `message`.
   - whatsapp-web.js instead: create the client with `pairWithPhoneNumber: { phoneNumber }` (or call `client.requestPairingCode(phone)` once the `qr` event fires), same number format.

8. **Tests:** e2e coverage for save/load round trip of `templates`, rejection of an active id from the wrong audience, a parent recipient receiving the parent body, and `groupName`/`status` on birthday students.

---

## 4. Code map (app)

| File | Role |
| :--- | :--- |
| `lib/core/models/birthday/birthday_models.dart` | `BirthdayTemplate`, `BirthdayAudience`, config fields and JSON |
| `lib/features/birthday/controllers/admin_birthday_controller.dart` | Library state, `resolveTemplates` (server → cache → migration), save, cache, `fillTemplate` |
| `lib/features/birthday/widgets/template_library.dart` | Students / Parents switch, template list, new / set active / delete |
| `lib/features/birthday/widgets/template_preview.dart` | Live WhatsApp preview |
| `lib/features/birthday/views/admin_birthday_screen.dart` | Template Studio tab layout |
| `test/birthday_templates_test.dart` | Model parsing, migration and cache rules, controller save flow (fake API) |
| `test/birthday_cards_and_logs_test.dart` | Alumni rule, group source precedence, phonebook index, log grouping and date labels |
