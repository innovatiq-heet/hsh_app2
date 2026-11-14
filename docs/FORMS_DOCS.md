# Forms & Polls

> **Last updated:** 2026-11-12 · **Repos:** `hsh_app2` (Flutter) and `hsh_api` (`src/modules/forms/`, e2e `tests/e2e/forms.e2e.test.ts`). The app is built against the backend handoff of 2026-11-11.

---

## 1. What this feature does

| Part | Who | Summary |
| :--- | :--- | :--- |
| **List** | Admin, warden | Every poll and form, with status (Active / Upcoming / Paused / Ended), answered of targeted, viewed, and seen-not-answered. Filter by status. Menu: Results, Edit, Pause/Activate, Delete. |
| **Editor** | Admin, warden | Poll or Form; title and description; questions of 9 types with options; audience; open–close times; Active and Required switches. Edits send only the changed fields. |
| **Results** | Admin, warden | Summary (targeted / answered / seen, not answered / never seen), a bar per option for choice questions, typed answers for text and number, and lists of who answered, who saw it, and who didn't answer. |
| **Polls & Forms** | Students (including leaders and alumni) | Open polls and forms, required ones first. Opening one records a view. Answer and submit once; afterwards the student sees their own answers. |

Entry points:
- Admin and warden: **Operator console → Hostel Services & Staff → Forms & Polls**. Every screen also checks the role on open (`FormsManagerGate`, `canOperate`).
- Students: **Dashboard → Hostel updates → Polls & Forms**. (It is also on the All services screen, but students cannot reach that screen.)

## 2. Rules

1. **Only admins and wardens manage forms.** The API allows `operator` and `platform-admin` tokens; anyone else is sent back before any request is made.
2. **Picked students are numeric `students.id` only**, through the shared `StudentPickerSource` and `studentIdOf` (the same rule as Broadcast, AGENTS.md §4). Alumni can be picked here.
3. **Audience:** `all`, `current`, `alumni`, or `selected`. With `selected`, students can answer if they match any of the picked students, floors or tags. The API's `students` and `floors` audiences are read as `selected`, and the app always sends `selected`. Targets are sent as `null` unless the audience is `selected`.
4. **Floors** are ids 0–9 (0 = Ground), the same numbering as the rest of the app (`FloorStringsRepository`).
5. **Times:** the API returns IST with no zone (`2026-11-11 18:00:00`), which `parseFormTime` reads as IST. The app sends ISO-8601 UTC (`…Z`), which the API accepts and converts.
6. **The editor checks the API's own rules** before sending:
   - a title, and at least one question, each with text;
   - poll and single-choice questions need at least 2 options, multiple-choice and dropdown at least 1, with no duplicates;
   - the close time is after the open time;
   - a `selected` audience has at least one target.
7. **Edits keep question ids**, so earlier answers still match. When a form already has answers, the editor warns before questions are changed.
8. **Answers** are keyed by `field.id ?? field.key ?? field.label`, and encoded by type:

   | Type | Sent as |
   | :--- | :--- |
   | checkbox | `List<String>`, in option order |
   | boolean | `bool` |
   | rating | `int`, 1–5 |
   | number | `num` |
   | text, textarea | trimmed `String` |
   | poll, radio, select | the option `String` |

   Unanswered optional questions are left out. Missing required answers and invalid values are caught before sending.
9. **A failed save or submit keeps everything on screen** and shows the server's `message`. A double tap submits once. Pausing a form shows at once and is rolled back if the request fails.

## 3. API (base `/forms`, under `AppConfig.baseUrl` = `…/api`)

| Method & path | Who | Notes |
| :--- | :--- | :--- |
| `GET /forms` | manager | List with stats and `status` |
| `POST /forms` | manager | Full body (below); returns top-level `form_id` |
| `GET /forms/:id` | manager | One form in `data` |
| `PUT /forms/:id` | manager | Partial update: only changed keys |
| `POST /forms/:id/toggle` | manager | Returns top-level `is_active` |
| `DELETE /forms/:id` | manager | Deletes the form with its views and responses |
| `GET /forms/:id/analytics` | manager | `form`, `summary`, `field_analytics` (keyed by field id), `responses`, `seen_not_answered`, `not_responded` |
| `GET /forms/student/active` | student | Open, eligible forms with `has_viewed`, `has_submitted`, `my_response` |
| `POST /forms/:id/view` | student | Records a view; a failure is ignored |
| `POST /forms/:id/submit` | student | `{ answers }`; `400` if already submitted, invalid, paused or outside the open window |
| `GET /forms/student/:id/my-response` | student | `404` until submitted |

Body for `POST` and `PUT`:
```json
{ "title", "description", "form_type": "poll|form",
  "fields": [{ "id", "label", "type", "required", "options"? }],
  "target_audience", "target_student_ids", "target_floors", "target_tags",
  "start_time", "end_time", "is_active", "is_mandatory" }
```

Analytics person lists (`responses`, etc.) have no fixed shape in the handoff. The app reads `name` / `student_name`, `room` / `room_number`, `submitted_at` / `viewed_at` and `answers`.

## 4. Code

| Path | What |
| :--- | :--- |
| `lib/core/models/forms/form_models.dart` | `HostelForm`, `FormFieldDef`, `StudentForm`, `FormResponse`, `FormAnalytics`, `parseFormTime` |
| `lib/core/network/repository/forms/forms_repository.dart` | All 11 calls (registered in `GlobalBindings`) |
| `lib/features/forms/controllers/` | `FormsManagerGate`, list, editor, results and student controllers |
| `lib/features/forms/views/` | List, editor, results, student list and fill screens |
| `lib/features/forms/widgets/forms_widgets.dart` | Status badge, kind chip, result bar, `AnswerInput` (all 9 types), `describeAnswer` |
| Shared with Broadcast | `PickableStudent`, `studentIdOf`, `StudentPickerSource`, `StudentPickerHost`, `StudentPickerSheet` |
| Routes | `operatorForms`, `operatorFormEditor`, `operatorFormAnalytics`, `studentForms`, `studentFormFill` |

## 5. Tests (offline, `test/support/fake_api.dart`)

- `test/forms_admin_test.dart`:
  - IST parsing and the ISO UTC output;
  - the answer-key order;
  - the `students`/`floors` aliases, and floor 0 kept;
  - the list with stats and the status filter;
  - roles (a warden is allowed, a student is sent away before any request);
  - pause shown at once and rolled back on failure;
  - delete;
  - each editor validation rule;
  - the create body;
  - targets `null` unless selected;
  - **edit sends only changed fields** (none → no request);
  - a 400 keeps the form;
  - an invalid form is never sent.
- `test/forms_student_test.dart`:
  - order and earlier answers;
  - one view, and a failed view doesn't block answering;
  - per-type encoding and answer keys;
  - optional answers left out;
  - client-side validation;
  - a 400 message keeps state;
  - a double tap submits once;
  - `my-response` 404 → null.

## 6. Not covered yet

- A required form doesn't block or prompt the student on the home screen. It is only listed first and marked **Required**.
- No push notification when a form opens (Broadcast can be used for that).
- Checked only offline; the layout and the live API still need a look on a device.
