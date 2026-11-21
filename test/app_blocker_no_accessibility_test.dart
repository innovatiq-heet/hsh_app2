import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_utils.dart';

/// The app blocks apps without an Accessibility service (usage events plus
/// "Display over other apps"): Google Play rejected the Accessibility use, and
/// some UPI and bank apps refuse to pay while a third-party one is on.
void main() {
  group('no Accessibility service', () {
    test('the manifest declares no AccessibilityService', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, isNot(contains('BIND_ACCESSIBILITY_SERVICE')));
      expect(manifest, isNot(contains('android.accessibilityservice')));
    });

    test('the app no longer ships an accessibility service config', () {
      expect(File('android/app/src/main/res/xml/accessibility_service_config.xml').existsSync(), isFalse);
    });
  });

  group('removal protection (device admin)', () {
    test('the manifest declares the HSH device admin, bound by the system only', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('.screentime.HshDeviceAdmin'));
      expect(manifest, contains('android.permission.BIND_DEVICE_ADMIN'));
      expect(manifest, contains('@xml/hsh_device_admin'));
    });

    test('the device admin asks for no admin powers', () {
      final policies = File('android/app/src/main/res/xml/hsh_device_admin.xml').readAsStringSync();
      for (final power in ['force-lock', 'wipe-data', 'reset-password', 'limit-password', 'disable-camera']) {
        expect(policies, isNot(contains(power)), reason: power);
      }
    });

    test('a phone with device admin turned off is flagged for the warden', () {
      final c = {
        'usageAccess': true,
        'appBlockerActive': true,
        'locationPermission': 'always',
        'locationEnabled': true,
        'deviceAdminActive': false,
      };
      expect(isStudentTampered({'compliance': c}), isTrue);
      expect(isStudentTampered({'compliance': {...c, 'deviceAdminActive': true}}), isFalse);
    });
  });

  group('warden compliance', () {
    Map<String, dynamic> report(Map<String, dynamic> blocker) => {
          'usageAccess': true,
          'locationPermission': 'always',
          'locationEnabled': true,
          ...blocker,
        };

    test('a phone blocking from usage events is not flagged', () {
      final c = report({
        'overlayPermission': true,
        'appBlocker': 'usage_events',
        'appBlockerActive': true,
      });
      expect(isAppBlockerOff(c), isFalse);
      expect(isStudentTampered({'compliance': c}), isFalse);
    });

    test('a phone without Display over other apps is flagged', () {
      final c = report({
        'overlayPermission': false,
        'appBlocker': 'off',
        'appBlockerActive': false,
      });
      expect(isAppBlockerOff(c), isTrue);
      expect(isStudentTampered({'compliance': c}), isTrue);
    });

    test('older builds without appBlockerActive still go by Accessibility', () {
      expect(isAppBlockerOff(report({'accessibilityEnabled': false})), isTrue);
      expect(isAppBlockerOff(report({'accessibilityEnabled': true})), isFalse);
    });
  });
}
