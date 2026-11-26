import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/features/screentime/views/device_setup_screen.dart';

import 'support/test_fonts.dart';

/// Phone setup lists only the step names; what a step does is shown before its
/// permission is asked for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const step = 'Step 3 · Location — allow all the time';
  final disclosure = find.textContaining('Your location is collected every few minutes');

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

  testWidgets('the list shows step names without their details', (tester) async {
    await openSetup(tester);

    expect(find.text(step), findsOneWidget);
    expect(disclosure, findsNothing);
    expect(find.text('Allow location'), findsNothing);
    await close(tester);
  });

  testWidgets('tapping a step shows its disclosure before asking', (tester) async {
    await openSetup(tester);

    await tester.tap(find.text(step));
    await tester.pumpAndSettle();
    expect(disclosure, findsOneWidget);
    expect(find.text('Allow location'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(disclosure, findsNothing);
    expect(find.text(step), findsOneWidget);
    await close(tester);
  });
}
