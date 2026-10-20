# Room Complaints & Staff Users

> **Last updated:** 2026-10-20 · **Repos:** `hsh_app2` (Flutter) and `hsh_api` (Node/Express/MySQL). Backend routes: `hsh_api/src/modules/complaints/complaints.routes.ts`, `hsh_api/src/modules/staffUsers/staffUsers.routes.ts`; e2e: `hsh_api/tests/e2e/complaints.e2e.test.ts`.

---

## 1. What this feature does

| Part | Who | Summary |
| :--- | :--- | :--- |
| **New complaint** | Student with a room | Pick a category, then an item from it; add an optional comment and one optional photo. The room is the student's own and cannot be edited. |
| **My Complaints** | Student | Their complaints, newest first, with status and detail (photo, timeline). Read-only: students cannot change the status. |
| **Complaints Desk** | `complain-solver`, platform admin | The queue with status tabs (Open / In progress / Resolved / Closed / All), a category filter and an exact room search, applied by the API, 50 at a time. Any status can move to any other. |
| **Overview** | `complain-solver`, platform admin | Counts per status and category, computed from the latest 200 complaints. |
| **Manage Users** | Platform admin | Create, edit, switch on/off and delete staff users (`complain-solver`, `laundry-man`). They sign in with their mobile number only. |

Staff users log in through the normal login field (number only) or SIM auto-login, and are routed on `user.role`: `complain-solver` opens the Complaints Desk, `laundry-man` the existing laundry module. Alumni (room `N/A`) cannot file complaints, so the button is hidden for them.

Entry points: student **Complaints** tab (also **More → Complaints**); operator console **Hostel Services & Staff → Complaints Desk** and **Manage User** (the latter for the admin role only).

---

## 2. API used by the app

All calls carry `Authorization: Bearer <token>`. Errors are `{ success: false, message }` and the app shows `message`, except 5xx, which shows "Something went wrong, try again".

| Method & path | Used by | Notes |
| :--- | :--- | :--- |
| `GET /complaint-categories` | New complaint, Desk filter, Overview | Never hard-code category ids. |
| `GET /complaint-items?categoryId=` | New complaint | Items of one category. |
| `GET /auth/me` | New complaint | `room_number` is the only room the API accepts. |
| `POST /complaints` | New complaint | JSON without a photo; `multipart/form-data` with the file in `image` when there is one. Never send `status` or `image_url`. |
| `GET /complaints/my?limit=&offset=` | My Complaints | `[]` when there are none. |
| `GET /complaints/:id` | Both detail screens | Someone else's complaint is 404 for a student; solvers also get `student`. |
| `GET /complaints/:id/image` | Photo | Needs the bearer token, so `Image.network` is given the `Authorization` header. |
| `GET /admin/complaints?status=&categoryId=&room_id=&studentId=&limit=&offset=` | Desk, Overview | `room_id` is an exact match; `limit` max 200. |
| `PATCH /admin/complaints/:id/status` `{status}` | Desk, solver detail | `OPEN`, `IN_PROGRESS`, `RESOLVED`, `CLOSED`. Returns the updated complaint. |
| `GET /admin/users` | Manage Users | `data` plus `roles` (fills the role dropdown). |
| `POST /admin/users` `{name, phone_number, role}` | Manage Users | 409 `message` says who already uses the number; shown as-is. |
| `PUT /admin/users/:id` | Manage Users | Partial: only the changed fields. `is_active` is a real boolean; `false` signs the user out at once. |
| `DELETE /admin/users/:id` | Manage Users | 404 if already gone. |

Status labels: students see `OPEN` as **Submitted** (then In progress, Resolved, Closed); solvers see **Open**.

---

## 3. App code

| Area | Files |
| :--- | :--- |
| Models | `lib/core/network/responses/complaints/` (`ComplaintResponse`, `ComplaintCategory`, `ComplaintItem`), `lib/core/enums/complaint_status.dart`, `lib/core/network/responses/staff_users/staff_user.dart` |
| Repositories | `lib/core/network/repository/complaints/complaints_repository.dart`, `lib/core/network/repository/staff_users/staff_users_repository.dart` |
| Student | `lib/features/complaints/` `complaints_*`, `add_complaint_*`, `complaint_detail_*` |
| Solver | `lib/features/complaints/` `complaint_orders_*` (Desk), `complaint_admin_detail_*`, `complaint_home_*` (Overview), `complaint_module_screen.dart` |
| Shared widgets | `lib/features/complaints/widgets/` (list card, timeline, issue and photo cards) |
| Manage Users | `lib/features/manage_users/` |
| Photo rules | `lib/core/utils/image_type.dart` (JPEG/PNG/WebP by content, 5 MB) |

---

## 4. Rules

- The complaint room comes from `/auth/me` and is read-only; any other room is 403.
- Photos: one file, JPEG/PNG/WebP, at most 5 MB. The app checks the file's bytes and sends that MIME type, because the API compares the declared type with the content (a generic `octet-stream` part is rejected). `image_picker` is called with `imageQuality`, which re-encodes iPhone HEIC to JPEG.
- A `401` whose message is "Staff account not found or inactive." (user deactivated or deleted) signs the user out like any expired token. Only "Student account not found or inactive." is left on screen.
- Staff sessions have no room and are never treated as alumni.
- After showing a success snackbar, close the page with `Navigator.of(context).pop()`, not `Get.back()`: in GetX 4 `Get.back()` closes the open snackbar instead of the route.

---

## 5. Tests

- `test/complaints_flow_test.dart`: payloads (JSON vs multipart, no `status`/`image_url`, room from `/auth/me`), items by `categoryId`, alumni blocked, photo validation, Desk filters sent to the API, status PATCH and rollback on error, 5xx message.
- `test/manage_users_test.dart`: list and roles, create with a normalized number, 409 message as-is, partial edit, on/off with rollback, delete.
- `test/staff_login_test.dart`: number login maps staff roles and is not alumni; a deactivated staff user is signed out on 401.
- `test/support/fake_api.dart`: fake Dio adapter for these tests, so real interceptors and 4xx/5xx handling run.

---

## 6. Known limitations

- The API has no count endpoint, so Desk tabs show no totals and the Overview covers the latest 200 complaints (it says so when capped).
- Room search is an exact match (`101`, not `10`).
- The old `/complains` API (free-text `compType`/`compDesc`, review and resolution notes, the "Inspect" tab) is no longer used by the app.
