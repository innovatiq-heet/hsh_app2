import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/settings/views/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

/// Settings rows that depend on the role: the privacy disclosures are for
/// admins only, device setup is for current students.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const disclosures = 'Privacy & Permissions Disclosures';
  const deviceSetup = 'Device Permissions & Setup';

  setUpAll(loadDeviceLikeFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(Get.reset);

  Future<void> openSettings(WidgetTester tester, UserRole role) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = Get.put(SessionStore());
    await store.saveSession(
      token: 't',
      role: role,
      email: 'user@example.com',
      name: 'Test User',
      room: '204',
    );
    await tester.pumpWidget(const GetMaterialApp(home: SettingScreen()));
    await tester.pump();
  }

  testWidgets('an admin sees the privacy disclosures, not device setup',
      (tester) async {
    await openSettings(tester, UserRole.admin);

    expect(find.text(disclosures), findsOneWidget);
    expect(find.text(deviceSetup), findsNothing);
  });

  testWidgets('a student sees device setup, not the privacy disclosures',
      (tester) async {
    await openSettings(tester, UserRole.student);

    expect(find.text(disclosures), findsNothing);
    expect(find.text(deviceSetup), findsOneWidget);
  });

  for (final role in UserRole.values.where((r) => r != UserRole.admin)) {
    testWidgets('${role.name} does not see the privacy disclosures',
        (tester) async {
      await openSettings(tester, role);

      expect(find.text(disclosures), findsNothing);
    });
  }
}
