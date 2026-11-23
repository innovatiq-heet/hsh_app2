# Prompt: Alumni current address & work, edited by admins — backend (`HAMS_WEB`)

> Paste everything below the line into the backend chat (repo `HAMS_WEB`).

---

Admins talk to alumni on WhatsApp (Daily Alumni Connect) and want to note where an alumnus lives and works now: **city**, **company**, **role**, and optionally the **full current address**. The app shows this as a **Current address & work** section on the student's profile, with an Edit sheet.

The data already has a home: `alumni_profiles` (`current_city`, `current_company`, `current_designation`, keyed by `student_id`). Today only the alumnus can write it (`PUT /alumni/me`). Add an **admin** read / write for any student. The Flutter app is already built against the contract below. If you change a path, field or status code, list it at the end of your reply.

Read `AGENTS.md` first and follow `src/modules/alumni/alumni.routes.ts` (the `verifyDailyOutreachAdmin` guard and the numeric-id checks of `/daily-outreach/students/:studentId/contact`).

## 1. Schema (`src/config/db.ts`, migrations that tolerate re-runs)

```sql
ALTER TABLE alumni_profiles ADD COLUMN current_address VARCHAR(500) NULL;
ALTER TABLE alumni_profiles ADD COLUMN details_updated_at DATETIME NULL;
ALTER TABLE alumni_profiles ADD COLUMN details_updated_by VARCHAR(100) NULL;
```

## 2. Endpoints (guard: `verifyDailyOutreachAdmin`)

### `GET /api/alumni/admin/students/:studentId/current-details`

- `studentId` must match `^[1-9]\d*$` (≤ 2147483647), else `400`. Unknown student → `404`.
- No `alumni_profiles` row yet → `200` with all fields `null` (not 404).

```jsonc
{ "success": true, "data": {
    "student_id": 812,
    "current_city": "Ahmedabad",
    "current_company": "Infosys",
    "current_designation": "Software Engineer",
    "current_address": "B-12, Shyam Residency, Satellite",   // or null
    "details_updated_at": "2026-11-24T10:15:00.000Z",          // ISO, or null
    "details_updated_by": "Super Admin"                         // or null
} }
```

### `PUT /api/alumni/admin/students/:studentId/current-details`

- Body: any of `current_city`, `current_company`, `current_designation`, `current_address`. **Partial update:** only the keys present change. An empty string (after trim) or `null` clears that field.
- Limits: city, company and designation ≤ 100 characters, address ≤ 500 → `400` with a clear message. A body with none of the four keys → `400`.
- Upsert into `alumni_profiles`. A new row needs `name`: take it from `students.name` (`'Hostel Alumnus'` if missing). Never touch the other profile columns.
- Set `details_updated_at = NOW()` and `details_updated_by` = the signed-in admin's name (from the token, never from the body).
- Reply `200` with the same `data` shape as GET (the saved values).
- Make `PUT /alumni/me` keep `current_address`, `details_updated_*` as they are (its upsert must not null them).

## 3. Rules

1. Student identity: numeric `students.id` only (no bank codes, `student_code`, `HSH-…`), as everywhere.
2. Works for any student (resident or alumnus); the app shows it for alumni.
3. Trim every value before saving.

## 4. Tests (`tests/e2e/`)

- GET for a student without a profile → 200 with nulls; unknown id → 404; `0768` / `abc` → 400; non-admin → 403.
- PUT city only → only city changes; other fields stay; `details_updated_by` is the admin's name.
- PUT `""` clears a field; a 101-character company → 400; empty body → 400.
- A later `PUT /alumni/me` by the alumnus does not erase `current_address`.

Run `npm run check`, then commit and deploy.
