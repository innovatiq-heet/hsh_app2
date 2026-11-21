import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/services/screen_time_service.dart';
import 'package:hsh_app2/features/screentime/controllers/screen_time_utils.dart';

/// The phone can block apps with the Accessibility service off (usage events
/// plus "Display over other apps"), because some UPI and bank apps refuse to
/// pay while a third-party accessibility service is on.
void main() {
  group('student setup', () {
    test('either Accessibility or Display over other apps completes the App blocker step', () {
      expect(ScreenTimeService.appBlockerReady(accessibility: true, overlay: false), isTrue);
      expect(ScreenTimeService.appBlockerReady(accessibility: false, overlay: true), isTrue);
      expect(ScreenTimeService.appBlockerReady(accessibility: true, overlay: true), isTrue);
      expect(ScreenTimeService.appBlockerReady(accessibility: false, overlay: false), isFalse);
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
        'accessibilityEnabled': false,
        'overlayPermission': true,
        'appBlocker': 'usage_events',
        'appBlockerActive': true,
      });
      expect(isAppBlockerOff(c), isFalse);
      expect(isStudentTampered({'compliance': c}), isFalse);
    });

    test('a phone with no way to block is flagged', () {
      final c = report({
        'accessibilityEnabled': false,
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
