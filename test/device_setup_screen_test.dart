import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/features/screentime/views/device_setup_screen.dart';

import 'support/test_fonts.dart';

/// Phone setup lists only step numbers, with no step name or description.
/// Tapping an unfinished step goes straight to its system permission screen,
/// with no explanation shown first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const step = 'Step 3 · ';

  setUpAll(loadDeviceLikeFonts);
  tearDown(Get.reset);

  Future<void> openSetup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: DeviceSetupScreen()));
    await tester.pumpAndSettle();
  }

  /// Disposes the screen so its permission poll timer stops.
  Future<void> close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('the list shows step numbers without names or details', (tester) async {
    await openSetup(tester);

    expect(find.text(step), findsOneWidget);
    expect(find.textContaining('Shares your location every few minutes'), findsNothing);
    await close(tester);
  });

  testWidgets('tapping a step opens no dialog', (tester) async {
    await openSetup(tester);

    await tester.tap(find.text(step));
    await tester.pumpAndSettle();

    // No dialog appears; the list is still showing (the system settings
    // screen this would open is out of process, so nothing else changes).
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(step), findsOneWidget);
    await close(tester);
  });
}
