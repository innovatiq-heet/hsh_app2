import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/models/auth/user_session.dart';
import 'package:hsh_app2/core/network/request/authentication/login_request.dart';
import 'package:hsh_app2/core/services/app_update_service.dart';
import 'package:hsh_app2/core/services/device_identity_service.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_utils.dart';
import 'package:hsh_app2/features/screentime/models/screen_time_alert.dart';
import 'package:hsh_app2/features/screentime/models/screen_time_policy.dart';
import 'package:hsh_app2/features/screentime/widgets/warden_logout_dialog.dart';

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore(this._fakeSession);
  final UserSession? _fakeSession;

  @override
  UserSession? get currentSession => _fakeSession;
}

UserSession _session({
  required UserRole role,
  bool isAlumni = false,
  String token = 'tok',
  String room = '415',
}) =>
    UserSession(
      id: '101',
      name: 'Test User',
      role: role,
      token: token,
      room: isAlumni ? 'N/A' : room,
      isAlumniFlag: isAlumni,
    );

void main() {
  tearDown(Get.reset);

  group('WardenLogoutGuard.requiresWardenCode', () {
    test('requires warden code only for active non-alumni student with token', () {
      expect(
        WardenLogoutGuard.requiresWardenCode(
          _FakeSessionStore(_session(role: UserRole.student)),
        ),
        isTrue,
      );
      expect(
        WardenLogoutGuard.requiresWardenCode(
          _FakeSessionStore(_session(role: UserRole.student, isAlumni: true)),
        ),
        isFalse,
      );
      expect(
        WardenLogoutGuard.requiresWardenCode(
          _FakeSessionStore(_session(role: UserRole.student, token: '')),
        ),
        isFalse,
      );
      expect(
        WardenLogoutGuard.requiresWardenCode(
          _FakeSessionStore(_session(role: UserRole.leader)),
        ),
        isFalse,
      );
      expect(
        WardenLogoutGuard.requiresWardenCode(
          _FakeSessionStore(_session(role: UserRole.warden)),
        ),
        isFalse,
      );
    });
  });

  group('ScreenTimePolicy restrictBrowsers', () {
    test('parses snake_case & camelCase and round-trips through copyWith/toJson', () {
      final p = ScreenTimePolicy.tryParse({
        'policy': {'is_locked': false, 'restrict_browsers': true},
      });
      expect(p, isNotNull);
      expect(p!.restrictBrowsers, isTrue);
      expect(p.toJson()['restrict_browsers'], isTrue);
      expect(p.copyWith(restrictBrowsers: false).restrictBrowsers, isFalse);
    });
  });

  group('ScreenTimeAlert and monitoringChecks security signals', () {
    test('parses new tamper/offline/secondary profile alerts with severity', () {
      for (final type in [
        ScreenTimeAlert.typePermissionRevoked,
        ScreenTimeAlert.typeClockTamper,
        ScreenTimeAlert.typeProlongedOffline,
        ScreenTimeAlert.typeSecondaryProfile,
      ]) {
        final a = ScreenTimeAlert.tryParse({
          'id': 5,
          'type': type,
          'message': 'msg',
          'student_id': 42,
        });
        expect(a, isNotNull);
        expect(a!.title, isNot('Screen time alert'));
        if (type != ScreenTimeAlert.typeProlongedOffline) {
          expect(a.isSevere, isTrue);
        }
      }
    });

    test('isStudentTampered and monitoringChecks detect clock and profile tampering', () {
      final clockOff = {
        'compliance': {
          'usageAccess': true,
          'appBlockerActive': true,
          'deviceAdminActive': true,
          'autoTimeEnabled': false,
          'clockDriftDetected': true,
          'multipleUsersOrProfiles': true,
          'deviceOwnerActive': true,
        },
      };
      expect(isStudentTampered(clockOff), isTrue);
      final checks = monitoringChecks(
        Map<String, dynamic>.from(clockOff['compliance'] as Map),
      );
      expect(
        checks.any((c) => c.label == 'Automatic time' && !c.on),
        isTrue,
      );
      expect(
        checks.any((c) => c.label == 'Clock sync' && !c.on),
        isTrue,
      );
      expect(
        checks.any((c) => c.label == 'Single user profile' && !c.on),
        isTrue,
      );
      expect(
        checks.any((c) => c.label == 'Device Owner lock' && c.on),
        isTrue,
      );
    });
  });

  group('AppUpdateService.evaluateVersionResponse', () {
    test('requires update when force_update is true and build < min_version_code', () {
      final info = AppUpdateService.evaluateVersionResponse({
        'success': true,
        'data': {
          'latest_version_code': 39,
          'min_version_code': 39,
          'latest_version_name': '1.2.2',
          'apk_url': '/apks/hsh-connect.apk',
          'update_message': 'Update required.',
          'force_update': true,
        },
      }, 38, mediaBaseUrl: 'https://example.com/');

      expect(info, isNotNull);
      expect(info!.minVersionCode, 39);
      expect(info.latestVersionName, '1.2.2');
      expect(info.downloadUrl, 'https://example.com/apks/hsh-connect.apk');
      expect(info.message, 'Update required.');
    });

    test('returns null when build meets min_version_code or force_update is false', () {
      expect(
        AppUpdateService.evaluateVersionResponse({
          'data': {
            'latest_version_code': 39,
            'min_version_code': 39,
            'force_update': true,
          },
        }, 39),
        isNull,
      );
      expect(
        AppUpdateService.evaluateVersionResponse({
          'data': {
            'latest_version_code': 39,
            'min_version_code': 39,
            'force_update': false,
          },
        }, 38),
        isNull,
      );
    });

    test('falls back to Play Store URL when apk_url is empty', () {
      final info = AppUpdateService.evaluateVersionResponse({
        'data': {
          'latest_version_code': 39,
          'force_update': true,
          'apk_url': '',
        },
      }, 38);
      expect(info, isNotNull);
      expect(
        info!.downloadUrl,
        'https://play.google.com/store/apps/details?id=com.avd_hsh.app',
      );
    });
  });

  group('DeviceIdentityService & LoginRequest device registration', () {
    test('generateUuidV4 returns valid lowercase RFC 4122 v4 UUIDs', () {
      final uuid1 = DeviceIdentityService.generateUuidV4();
      final uuid2 = DeviceIdentityService.generateUuidV4();
      final regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(regex.hasMatch(uuid1), isTrue);
      expect(regex.hasMatch(uuid2), isTrue);
      expect(uuid1, isNot(equals(uuid2)));
    });

    test('LoginRequest serializes client flag, device_uuid, and device metadata', () {
      const payload = DeviceIdentityPayload(
        deviceUuid: 'dev-uuid-123',
        deviceModel: 'Samsung SM-A146B',
        hardwareId: 'HW123',
        osVersion: 'Android 14',
        appVersion: '1.2.2+39',
      );
      final json = LoginRequest(
        studentId: '1016',
        code: '654321',
        deviceInfo: payload.toJson(),
      ).toJson();

      expect(json['client'], 'hsh_app2_mobile');
      expect(json['code'], '654321');
      expect(json['device_uuid'], 'dev-uuid-123');
      expect(json['device_model'], 'Samsung SM-A146B');
      expect(json['hardware_id'], 'HW123');
      expect(json['os_version'], 'Android 14');
      expect(json['app_version'], '1.2.2+39');
    });
  });
}
