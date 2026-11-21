# Prompt: Parents' own birthdays (father / mother): finish the backend (`HAMS_WEB`)

> Paste everything below the line into the backend chat (repo `HAMS_WEB`, the API the app calls, Node + Express + MySQL, TypeScript).

---

Finish **parents' own birthdays** (wish a student's father on his birthday and the mother on hers) in the WhatsApp Birthday Wishes feature.

**Most of it is already written but not committed or exposed.** The working tree has uncommitted changes in `src/config/db.ts` and `src/services/birthdayWishes.ts`. They compile (`tsc --noEmit` passes) but no route uses them yet. Keep that code. Do not rewrite it. It already does the following:

- `db.ts` adds config columns `active_father_template_id`, `active_mother_template_id`, `father_message_template`, `mother_message_template`, `include_parent_birthdays`, plus `birthday_wishes_log.account_id`.
- `birthdayWishes.ts`:
  - Template audiences are `student | parent | father | mother | anniversary`, with validation, and active ids are checked against their kind.
  - `getBirthdayConfig` always returns `activeFatherTemplateId`, `activeMotherTemplateId`, `fatherMessageTemplate`, `motherMessageTemplate` and `includeParentBirthdays`.
  - `getTodaysParentBirthdays` / `getTomorrowsParentBirthdays` (`getParentBirthdaysForDate`) find the celebrants:
    - matched by IST month and day; 29 February is celebrated on 28 February in non-leap years
    - siblings merged by role + date of birth + last 10 phone digits
    - leader group filter
  - `processBirthdayWishes` also wishes parents when `includeParentBirthdays` is true. It skips parents whose children have all left, never resends, and returns `parentCount`.
  - `sendParentBirthdayWish({ role, studentId, accountId?, customMessage?, leaderGroup? })` sends one wish. It throws `ParentWishError` with the following codes:
    - `400` for a bad role, id or message
    - `403` for another group
    - `404` for an unknown student or no phone
    - `409` when already wished today
    - `400` with `code: "WHATSAPP_NOT_CONNECTED"` when the number isn't connected
  - Every send is logged in `birthday_wishes_log` with `wish_type = 'parent_birthday'`, `recipient_type` `father` / `mother` and `account_id`.

The Flutter app (`hsh_app2`) is already built against the contract below:

- **Template saving:** it detects support by the presence of `activeFatherTemplateId` in `GET /whatsapp/birthday` `data.config`. Once present, it saves `father` / `mother` templates and their active ids through `POST /whatsapp/birthday/config`.
- **Parent lists:** today it lists parents from the phonebook on the phone. It will switch to the server lists below once they exist.

Read `AGENTS.md` first and follow the patterns of the existing birthday / anniversary routes in `src/modules/whatsapp/whatsapp.routes.ts`. Use `isLeaderUser`, `resolveLeaderGroup`, `accountOf(req)` and `{ success, data }` / `{ success, message }`.

---

## 1. What is left to do

### 1.1 `GET /whatsapp/birthday` (`whatsapp.routes.ts`)

Add two lists to `data`, next to `todaysBirthdays` / `tomorrowsBirthdays`, using the same `effectiveGroup` (a leader only gets their own group):

```ts
const todaysParentBirthdays = await getTodaysParentBirthdays(effectiveGroup);
const tomorrowsParentBirthdays = await getTomorrowsParentBirthdays(effectiveGroup);
// ...
data: { ..., todaysParentBirthdays, tomorrowsParentBirthdays }
```

The shape is exactly `ParentCelebrant` as already written:

```jsonc
{
  "role": "father",                 // "father" | "mother"
  "parentName": "Chirag Vasantlal Shah",
  "phone": "9974066375",
  "dob": "1972-11-22",
  "turning": 54,                    // null when the birth year looks wrong
  "students": [
    { "studentId": 812, "name": "Dharmik Chirag Shah", "studentCode": "1131",
      "room": "2", "groupName": "Paramanand", "status": "renewed-admission" }
  ],
  "alreadySentToday": false
}
```

Keep `config` for admins as it is (it already contains the father / mother fields). The leader `responseConfig` doesn't need them.

### 1.2 `POST /whatsapp/birthday/send-parent-wish` (new route)

```
POST /whatsapp/birthday/send-parent-wish      (verifyAdminOrFloorLeader)
body: { role: "father" | "mother", studentId: number, accountId?: string, customMessage?: string }
```

- A leader passes `leaderGroup` from `resolveLeaderGroup(req)`. An admin passes `null`.
- `accountId`: when given, resolve it with `accountOf(req)`. Unknown → `404`, as the other routes do. Otherwise pass `null`, so the service uses `defaults.birthday`.
- Call `sendParentBirthdayWish(...)`. On success: `200 { success: true, data: { role, phone, message, accountId } }`.
- `ParentWishError` → `res.status(err.statusCode).json({ success: false, message: err.message, ...(err.code ? { code: err.code } : {}) })`. Anything else → `500`.
- `studentId` is the numeric `students.id` only (AGENTS.md: student identifiers). The service already rejects anything else with `400`.

### 1.3 `POST /whatsapp/birthday/trigger`

No change is needed. `processBirthdayWishes` already returns `parentCount` and includes parents only when `includeParentBirthdays` is true. A test wish (`testPhone`) never touches parents. Check that it behaves this way.

### 1.4 Commit

Commit the existing `db.ts` and `birthdayWishes.ts` changes together with the routes and tests, so a deploy never has the service without the migrations.

---

## 2. Rules (must hold)

1. **Backward compatible:** a config saved by an older app, without the new fields, still loads and saves. The existing `saveBirthdayConfig` merge already preserves them; keep it that way.
2. **`activeFatherTemplateId` is always present** in admin `GET /whatsapp/birthday` `data.config`, even as `null`. The app uses it to detect support.
3. **No double sends:** a parent (role + last 10 phone digits) is wished at most once per IST day, across the automated run, `trigger` and `send-parent-wish`. The existing `deliverParentWish` guard covers this.
4. **Automated run is opt-in:** `includeParentBirthdays` defaults to `false`.
5. **Leaders** only see and wish parents of students in their own group (`403` otherwise).

---

## 3. Tests (`tests/e2e/birthday.e2e.test.ts`, use the existing `setBirthdayWhatsAppForTests` fake)

1. A father whose `father_dob` is today and a mother whose `mother_dob` is tomorrow appear in `todaysParentBirthdays` / `tomorrowsParentBirthdays`. A parent with another date does not.
2. Two siblings with the same father phone and date of birth produce **one** celebrant with two `students`.
3. 29 February: celebrated on 28 February in a non-leap year (`parentBirthdayMonthDays`).
4. A leader only sees parents from their own group, and gets `403` from `send-parent-wish` for another group's student.
5. Config round-trip:
   - `father` / `mother` templates with active ids save and load
   - an active id pointing at a template of another kind → `400`
   - `activeFatherTemplateId` is present (null) on a fresh config
6. `send-parent-wish`:
   - success logs `wish_type = 'parent_birthday'`, `recipient_type = 'father'` and `account_id`
   - a second call the same day → `409`
   - unknown student → `404`
   - no father phone → `404`
   - `role: "uncle"` → `400`
   - `studentId: "0812"` → `400`
   - number not connected → `400` with `code: "WHATSAPP_NOT_CONNECTED"`
7. Automated run:
   - `includeParentBirthdays: false` sends no parent wishes
   - `true` sends once per celebrant and returns `parentCount`
   - a second run the same day sends none
   - parents whose children all have status `left` are skipped

Run `npm run check` (typecheck + e2e) before committing.

---

## 4. Docs

Add the two lists, the new route and `includeParentBirthdays` to the birthday section of the docs / `AGENTS.md`. Say that `father` / `mother` templates are for the **parent's own** birthday, while `parent` is the message to parents on the **student's** birthday.

If you change a field name, path or status code, list it at the end of your reply so the app can be updated.
