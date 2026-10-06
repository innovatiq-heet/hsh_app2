# AGENTS.md — HSH App (`hsh_app2`)

Rules and context for anyone (human or AI agent) changing this repo. Read this before editing; the feature invariants in section 4 exist because each one was a real bug.

## 1. What this repo is

- Flutter app (GetX) for Hari Saurabh Hostel: students, leaders, wardens / operator console, staff.
- Backend is the separate **`hsh_api`** repo (Node + Express + MySQL). It has its own `AGENTS.md`.
- Background behaviour on student phones (screen time, app blocking, geofence, location) is **native Android Kotlin**, so it runs with the Flutter UI closed. Caller ID is native on Android and iOS.
- Feature docs: [docs/GEOFENCING_DOCS.md](docs/GEOFENCING_DOCS.md), [docs/PARENT_CONTROL_DOCS.md](docs/PARENT_CONTROL_DOCS.md), [docs/PHONEBOOK_DOCS.md](docs/PHONEBOOK_DOCS.md).

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
- **Roles:** gate screens with `UserRole` helpers: `canOperate` (admin/warden: phonebook, caller ID, operator console) and `canViewScreenTime` (admin/warden).
- **Never commit** `android/key.properties`, keystores, `.env` files or new credentials.

## 4. Feature invariants (do not break)

**Student identity**

- Screen Time and every warden action identify a student **only by the numeric `students.id`** (the `id` of a `/screen-time/students` entry). Never send a bank code / `student_code` / `HSH-…` id as an identifier. Bank codes are numeric (`0768`, `1043`) and collide with other students' ids; this once made a lock hit the wrong student.
- The phonebook has no `students.id`; it opens Screen Time with `{name, room}` only, and the warden picks the student. Do not add bank-code or name auto-matching.

**Parental control / screen time**

- The **native side is the only writer** of the enforced policy (`PolicyStore.applyPolicyJson`). Flutter only calls `ScreenTimeService.refreshPolicy()`. Do not reintroduce Flutter-side policy pushes.
- Responses are applied in **`policy_version` order**; an older version is discarded.
- Warden writes are targeted: `POST /screen-time/apps/rule` for one app; `PUT /screen-time/policies/:id` with **only the fields being changed** (it is a partial update). Never send a full policy object.
- `AppBlockerAccessibilityService` must re-check the **app already on screen** when the policy changes. Never block protected packages (dialer, emergency, keyboard, launcher, Settings, this app). When unsure which app is in front, fail open rather than block the wrong one.
- A `null` bedtime means "no bedtime" (never a 23:00–05:00 default).

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

## 5. Tests

- `test/screen_time_student_id_test.dart`: drives `StudentScreenTimeController` with fake HTTP (a Dio interceptor) and asserts no request ever carries a bank code. Copy this pattern for controller tests.
- `test/geofence_location_models_test.dart`, `test/parental_geofence_contract_test.dart`: payload contracts with `hsh_api`.
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
