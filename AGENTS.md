# AGENTS.md — HSH App (`hsh_app2`)

Rules and context for anyone (human or AI agent) changing this repo. Read this before editing; the feature invariants in section 4 exist because each one was a real bug.

## 1. What this repo is

- Flutter app (GetX) for Hari Saurabh Hostel: students, leaders, wardens / operator console, staff.
- Backend is the separate **`hsh_api`** repo (Node + Express + MySQL). It has its own `AGENTS.md`.
- Background behaviour on student phones (screen time, app blocking, geofence, location) is **native Android Kotlin**, so it runs with the Flutter UI closed. Caller ID is native on Android and iOS.
- Feature docs: [docs/GEOFENCING_DOCS.md](docs/GEOFENCING_DOCS.md), [docs/PARENT_CONTROL_DOCS.md](docs/PARENT_CONTROL_DOCS.md), [docs/PHONEBOOK_DOCS.md](docs/PHONEBOOK_DOCS.md), [docs/COMPLAINTS_DOCS.md](docs/COMPLAINTS_DOCS.md), [docs/BIRTHDAY_DOCS.md](docs/BIRTHDAY_DOCS.md), [docs/BROADCAST_DOCS.md](docs/BROADCAST_DOCS.md), [docs/FORMS_DOCS.md](docs/FORMS_DOCS.md), [docs/AMENITIES_SPEC.md](docs/AMENITIES_SPEC.md) (Amenities; replaced Room Keys, see [docs/ROOM_KEYS_DOCS.md](docs/ROOM_KEYS_DOCS.md)).

## 2. Commands

```bash
flutter pub get
bash scripts/check.sh                      # analyze + offline tests (what CI runs)
bash scripts/check.sh --android            # + compile native Android (Kotlin)
bash scripts/check.sh --api ../hsh_api     # + backend typecheck, JS mirrors, e2e (local MySQL)
flutter test --exclude-tags live           # offline tests only
flutter test test/screen_time_student_id_test.dart   # one file
```

Run `bash scripts/check.sh` before every push; add `--android` when you touch Kotlin, and `--api` when you touch an endpoint the app uses.

## 3. Layout and conventions

```text
lib/core/        constants (routes, pages, config, theme), models, network (ApiClient, repositories),
                 services (platform bridges), storage (SessionStore), utils
lib/features/<f>/bindings, controllers, views, widgets   (GetX per feature)
android/app/src/main/kotlin/com/example/hsh_app2/
  MainActivity.kt      MethodChannels: hsh/screen_time, hsh/geofence, hsh/caller_id
  screentime/          policy sync, app blocker, usage, geofence, location
  callerid/            call screening, popup, notification
ios/Runner/CallerIdPlugin.swift, ios/CallDirectoryExtension/   iOS caller ID
test/                  unit tests (offline); tag tests that hit real APIs with @Tags(['live'])
```

- **Routing/state:** GetX. Add routes in `lib/core/constants/app_routes.dart` + `app_pages.dart` with a binding.
- **HTTP:** always `Get.find<ApiClient>().dio` (adds the token). Repositories throw on failure; controllers show the error and roll back optimistic UI.
- **Platform code:** one Dart service per MethodChannel (`ScreenTimeService`, `GeofenceDeviceService`, `CallerIdService`), each a no-op on unsupported platforms. Keep channel method names in sync on both sides.
- **Reuse before adding:** shared widgets live in `lib/features/shared/widgets`, and date helpers in `lib/core/utils/date_formatting.dart`.
- **Roles:** gate screens with `UserRole` helpers: `canOperate` (admin/warden: phonebook, caller ID, operator console) and `canViewScreenTime` (admin/warden/leader). A leader sees only the students of their own group (`leaderGroupName`): every `/screen-time/students` request carries `group`, and app requests and directly opened students are checked against the group; admins and wardens get group chips. Manage Users is admin-only.
- **Closing after a snackbar:** in GetX 4, `Get.back()` closes an open snackbar instead of the route. After showing a success snackbar, close the page or sheet with `Navigator.of(context).pop()`.
- **Never commit** `android/key.properties`, keystores, `.env` files or new credentials.

## 4. Feature invariants (do not break)

**Student identity**

- Screen Time and every warden action identify a student **only by the numeric `students.id`** (the `id` of a `/screen-time/students` entry). Never send a bank code / `student_code` / `HSH-…` id as an identifier. Bank codes are numeric (`0768`, `1043`) and collide with other students' ids; this once made a lock hit the wrong student.
- The phonebook has no `students.id`; it opens Screen Time with `{name, room}` only, and the warden picks the student. Do not add bank-code or name auto-matching.
- Exception, bookmark only: phonebook **Favourites** (`/phonebook/calls`, `/phonebook/favourites`) store the phonebook's `student_key` (`HSH-…`) as an opaque string per user. Neither side may resolve it to a `students.id` or use it for any action on a student.
- A broadcast picture is uploaded first (`POST /broadcasts/image`) and referenced only by the returned `image_id`; the app never sends a URL or file path in `POST /broadcasts`. A failed or refused upload leaves a text-only send, and Send waits while an upload runs.
- Broadcast recipients and Forms & Polls `target_student_ids` send numeric `students.id` only: the shared `StudentPickerSource` / `studentIdOf` reads a row's `id` (positive integer, no leading zero), never `student_id` / `student_code`, and never the phonebook cache.
- Amenities (which replaced Room Keys) gives an item to a student by numeric `students.id` only, picked from `StudentPickerSource` or taken from a location's residents list; never the phonebook cache or a bank code. A student's profile loads their items through `StudentIdResolver`. Every `PUT /amenities/...` is a partial update.
- Exception, display only: birthday cards borrow a student's group/status from the synced phonebook by bank code (`PhonebookDatabaseService.groupInfoByBankCode`). Never use that lookup to pick a student for an action.
- A phonebook screen that must save something for a student (tags, an alumnus's current address & work) gets the numeric `students.id` through `StudentIdResolver`: the id the opener already has (e.g. Daily Alumni Connect), else the **exact 12-digit Aadhar** when exactly one student in `/students?all=true` has it, else the admin confirms the student from a list. Never by bank code, never by name alone.

**Parental control / screen time**

- The **native side is the only writer** of the enforced policy (`PolicyStore.applyPolicyJson`). Flutter only calls `ScreenTimeService.refreshPolicy()`. Do not reintroduce Flutter-side policy pushes.
- Responses are applied in **`policy_version` order**; an older version is discarded.
- Warden writes are targeted: `POST /screen-time/apps/rule` for one app; `PUT /screen-time/policies/:id` with **only the fields being changed** (it is a partial update). Never send a full policy object.
- `AppBlockerAccessibilityService` must re-check the **app already on screen** when the policy changes. Never block protected packages (dialer, emergency, keyboard, launcher, Settings, this app). When unsure which app is in front, fail open rather than block the wrong one.
- While `AppBlockerAccessibilityService` is not connected, `UsageAppBlocker` (in `PolicyPollService`) enforces the same `PolicyEvaluator` rules from usage events, because some UPI and bank apps refuse to pay while a third-party accessibility service is on. It needs Usage access plus "Display over other apps" on Android 10+, and must never run while the accessibility service is connected (no double block screens or block events). Setup's App blocker step accepts either one (`ScreenTimeService.appBlockerReady`).
- **One exception inside Settings:** `SelfProtection` sends the student home when Settings shows *this app's* App info page (name plus a Force stop / Uninstall control), because a force-stopped app enforces nothing. Never widen it to other Settings screens (the Accessibility page is needed during setup). Our own flows that open App info (`openAppSettings()`) must call `ScreenTimeService.allowAppSettings()` first. This needs `canRetrieveWindowContent="true"` on the accessibility service, so the Play accessibility disclosure must mention it.
- **One exception inside SystemUI:** `SelfProtection.offersToStopOwnApp` closes the Android 13+ Active apps panel (notification shade, "N apps are active") only while it shows a Stop button in the same row as *this app's* name. Never close the shade for anything else: other apps' rows and notification actions must stay usable.
- Per-app time limits are enforced on the phone: `PolicyStore` keeps each app's `daily_limit_minutes` from the `apps` rules of `/policies/me` (`DevicePolicy.appLimits`), and a payload without `apps` (the ping echo) must keep the stored limits. The warden UI reads a limit from the loaded policy (`appLimitFor`), not from the usage row, whose `dailyLimitMinutes` is 0 for every app without a rule.
- `POST /screen-time/ping` **adds** the minutes it receives, so the phone sends deltas from an "already reported" baseline. That baseline is trusted only for the login and day it was lined up with the server (`PolicyStore.sentConfirmedDate`). After a login, a reinstall or a new day, `ScreenTimeSync` reads `GET /screen-time/live` and starts from the server's numbers (`UsageBaseline`) before reporting; never re-send a day from an empty baseline (it doubled the day).
- A `null` bedtime means "no bedtime" (never a 23:00–05:00 default).
- Curfews come from `policy.curfew_sessions` (sessions on and not paused, plus the personal bedtime), times in **IST**; an overnight window belongs to the day it starts; block while **any** runs. A payload without the key keeps the stored list; an empty list means no curfew; only a server that never sent it falls back to `bedtime_start/end`. Kotlin `CurfewSchedule` and Dart `curfew_schedule.dart` must stay identical to the backend.
- A missing `restrict_app_installs` means the Play Store (and other stores/installers) is **allowed** by default; only an explicit `true` restricts it. The warden switch sends only that field.

**Geofence and location**

- The curfew geofence **never locks phones** (removed 2026-10-05). It only reports breaches. Phone locking exists only in Screen Time.
- Phones take a location fix every `checkIntervalMinutes` (warden setting on the Campus Geofence screen, default 2), all day. During curfew the same fixes feed breach detection.
- Breach events are queued natively and uploaded with `POST /screen-time/ping`; the queue is cleared only after a 2xx.
- `ScreenTimeSync.stop()` (logout) must call `PolicyStore.clearStudentState()` so the next student never inherits queued events, gate passes or state.
- **The location step in `device_setup_screen.dart` is the user-facing disclosure** required by Google Play. If what is collected or how often changes, update that text in the same change.

**Caller ID**

- Caller ID runs only for `canOperate` sessions; `SessionStore` turns it off for other roles and on logout.
- Android reads the phonebook SQLite file **read-only**; Dart and Kotlin number normalization must stay identical.
- iOS directory entries must be sorted ascending with no duplicate numbers, or CallKit rejects the whole batch.

**Amenities**

- Admins and wardens only (`canOperate`); `AmenitiesHomeController.ensureOperator` refuses anyone else before any request.
- Nothing is hard-coded per kind of asset: categories, types (code prefix, individual or bulk tracking, unit) and locations come from the server and are managed in the app.
- History is append-only: the app never deletes an asset, assignment or event. It retires an asset (status `retired`) and deactivates a category, type or location.
- Scanning reads any QR text containing `HSH-XXX-00000` (`AmenityFormat.assetCodeIn`) and looks it up with `GET /amenities/assets/by-code/:code`.
- Bulk quantities that exceed stock come back as `409` with a message; show it as is.

**Complaints and staff users**

- A complaint's room is the student's own room from `/auth/me`, shown read-only. `POST /complaints` never carries `status` or `image_url`; a photo goes in the multipart `image` field with its real MIME type (the API checks it against the bytes).
- Complaint photos need the bearer token: pass the `Authorization` header to `Image.network`.
- Staff (`complain-solver`, `laundry-man`) have no room and are never alumni. A `401 "Staff account not found or inactive."` (deactivated or deleted) must sign them out.
- `PUT /admin/users/:id` is a partial update: send only the changed fields.

## 5. Tests

- `test/screen_time_student_id_test.dart`: drives `StudentScreenTimeController` with fake HTTP (a Dio interceptor) and asserts no request ever carries a bank code. Copy this pattern for controller tests.
- `test/geofence_location_models_test.dart`, `test/parental_geofence_contract_test.dart`: payload contracts with `hsh_api`.
- `test/amenities_test.dart`: Amenities paths, partial bodies, numeric student ids, QR code extraction and the home controller.
- `test/complaints_flow_test.dart`, `test/manage_users_test.dart`, `test/staff_login_test.dart` use `test/support/fake_api.dart`, a fake Dio adapter, so the real interceptors and 4xx/5xx handling run. Prefer it for new repository/controller tests.
- Tests that call real services are tagged `live` and skipped in CI. Prefer offline tests.
- Backend behaviour (auth, breaches, gate passes, locations, long-poll sync, id-only resolution) is covered by `hsh_api/tests/e2e/screentime-geofence.e2e.test.ts` (`npm run test:e2e` there).
- A new rule or a bug fix gets a test that fails without the change.

## 6. CI

`.github/workflows/ci.yml` runs on pushes to `master` / `MVP-*`, on pull requests, and manually:

| Job | What it does |
| :--- | :--- |
| `app` | `bash scripts/check.sh`: pub get, analyze, offline tests |
| `android` | Compiles the native Android code |
| `backend` | Checks out `hsh_api` (`vars.HSH_API_REPOSITORY`, branch `vars.HSH_API_REF`, default `dev`) and runs `npm run check` against a MySQL 8 service |

The backend job needs the `HSH_API_TOKEN` secret (read access to hsh_api); without it the job is skipped with a warning.

## 7. Docs

When behaviour, an endpoint, a MethodChannel or a permission changes, update the matching `docs/*.md` (and `hsh_api/AGENTS.md` for backend rules) in the same change, and refresh its "Last updated" line.
