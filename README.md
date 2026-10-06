# HSH App (`hsh_app2`)

The Flutter app for **Hari Saurabh Hostel**. One app serves three kinds of users:

| Who | Main features |
| :--- | :--- |
| **Students / leaders** | BLE + QR attendance, leave, fees, laundry, complaints, notes, profile. Android phones are also enrolled in screen-time monitoring and the curfew geofence. |
| **Wardens / operator console** (admin role) | Operator home: student phonebook with caller ID, screen time & parental controls, campus geofence & curfew breaches, live student locations, admissions, approvals, attendance tools. |
| **Staff** (laundry, complaint solver, attendance) | Their own module screens. |

The backend is a separate repo, **`hsh_api`** (Node.js + Express + MySQL). The app points at it through `AppConfig.host` in [lib/core/constants/app_config.dart](lib/core/constants/app_config.dart).

## Feature documentation

| Document | Feature |
| :--- | :--- |
| [docs/GEOFENCING_DOCS.md](docs/GEOFENCING_DOCS.md) | Campus geofence, curfew breaches, gate passes, Student Locations |
| [docs/PARENT_CONTROL_DOCS.md](docs/PARENT_CONTROL_DOCS.md) | Screen time, remote lock, blocked apps, bedtime, daily limit |
| [docs/PHONEBOOK_DOCS.md](docs/PHONEBOOK_DOCS.md) | Student phonebook and caller ID (Android + iOS) |
| [ios/CALLER_ID_SETUP.md](ios/CALLER_ID_SETUP.md) / [ios/CALLER_ID_HANDOFF.md](ios/CALLER_ID_HANDOFF.md) | iOS caller-ID extension setup |
| [APP_THEME_AND_COLORS.md](APP_THEME_AND_COLORS.md) | Theme, colours, typography |

## Getting started

**Requirements:** Flutter stable **3.44 or newer**. The committed `pubspec.lock` requires Flutter ≥ 3.44 / Dart ≥ 3.12; an older Flutter will silently downgrade packages in `pubspec.lock`, so don't commit that. You also need Android Studio / Android SDK, and Xcode on macOS for iOS builds.

```bash
flutter pub get
flutter run                                  # pick a connected device
bash scripts/check.sh                        # analyze + offline tests (same as CI)
bash scripts/check.sh --android --api ../hsh_api   # + native Android compile + backend e2e
```

Rules for contributors and AI agents, including feature invariants that must not break, are in [AGENTS.md](AGENTS.md). CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs the same checks on every push and pull request.

- **Backend URL:** change `AppConfig.host` to point at a local or staging `hsh_api`. The phone's background services receive the same base URL when monitoring starts.
- **Student monitoring needs a real Android phone.** Usage access, the Accessibility app blocker, background location and the foreground service can't be exercised on an emulator in a meaningful way. Students are walked through these permissions on the device-setup screen after login.
- **iOS caller ID** requires a paid Apple Developer team and the App Group described in [ios/CALLER_ID_SETUP.md](ios/CALLER_ID_SETUP.md).
- **Tests that call live services:** `test/attendance_schedule_test.dart` and `test/student_profile_test.dart` hit real APIs, so they are tagged `live` and skipped by `scripts/check.sh` and CI. Run them with `flutter test --tags live`.
- **Over-the-air updates:** the app uses Shorebird code push (`shorebird.yaml`, `shorebird_code_push`). Release builds should be made with `shorebird release`; plain `flutter build` binaries don't receive patches.

## Project structure

```text
lib/
  core/            constants (routes, pages, config, theme), models, network (ApiClient, repositories),
                   services (platform bridges), storage (SessionStore), utils
  features/<name>/ bindings/ controllers/ views/ widgets/   — GetX per feature
android/app/src/main/kotlin/com/example/hsh_app2/
  MainActivity.kt  MethodChannels: hsh/screen_time, hsh/geofence, hsh/caller_id
  screentime/      monitoring, app blocker, policy sync, geofence + location sampling
  callerid/        Call Screening service, popup card, notification
ios/
  Runner/CallerIdPlugin.swift, CallDirectoryExtension/   — iOS caller ID
docs/              feature documentation
scripts/           maintenance scripts (Play Store internal-track upload, one-off helpers)
test/              unit and widget tests
```

**Conventions:**

- State management and routing use **GetX**; routes live in `lib/core/constants/app_routes.dart` and `app_pages.dart`.
- HTTP goes through `ApiClient` (Dio) with the session token.
- Platform features are behind MethodChannels with a Dart service per channel (`ScreenTimeService`, `GeofenceDeviceService`, `CallerIdService`).
- Background behaviour on Android is native Kotlin, so it keeps working with the Flutter UI closed.

## Roles in code

`UserRole` in [lib/core/enums/user_role.dart](lib/core/enums/user_role.dart) maps the login role. Two gates matter for the features above:

- `canOperate` (admin, warden): phonebook, caller ID, operator console.
- `canViewScreenTime` (admin, warden): screen-time dashboard.

The operator console signs in with the admin role in the app; the backend sees an `operator` token and admits it to supervisor endpoints together with platform-admin staff.
