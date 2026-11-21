import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/whatsapp_accounts/controllers/whatsapp_numbers_controller.dart';
import 'package:hsh_app2/features/whatsapp_accounts/views/whatsapp_numbers_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/test_fonts.dart';

/// Opening the link sheet for a disconnected number from the real screen must
/// ask the server for a QR (`POST /whatsapp/connect {accountId}`) and then
/// show it. On a phone the sheet once threw during its first build (it
/// changed observables in initState) before the request went out, so it spun
/// forever; this test covers the flow, though the test binding does not raise
/// that particular build-phase error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadDeviceLikeFonts();
    await serveGoogleFontsAsAssets();
  });

  testWidgets('link sheet starts the QR and shows it', (tester) async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'admin-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
    });
    Get.put(SessionStore());
    final api = FakeApi()..install();

    var connected = false;
    Map<String, dynamic> wa1() => {
          'id': 'wa1',
          'label': 'Wishes',
          'status': connected ? 'qr' : 'disconnected',
          'qr': connected ? 'QR-TEXT' : null,
          'user': null,
        };
    api.routes['GET /whatsapp/accounts'] = (_) => FakeReply(200, {
          'success': true,
          'data': {
            'accounts': [
              {'id': 'default', 'label': 'Main', 'status': 'open', 'user': {'phone': '919800000001'}},
              wa1(),
            ],
            'defaults': {'birthday': null, 'anniversary': null},
          },
        });
    api.routes['GET /whatsapp/status'] = (_) => FakeReply(200, {'success': true, 'data': wa1()});
    api.routes['POST /whatsapp/connect'] = (_) {
      connected = true;
      return const FakeReply(200, {'success': true});
    };

    late WhatsAppNumbersController c;
    await tester.runAsync(() async {
      c = Get.put(WhatsAppNumbersController(isAdmin: true));
      await until(() => !c.isLoading.value, reason: 'numbers load');
    });

    /// Lets real async work (the fake HTTP) and frames run until [done].
    Future<void> settle(bool Function() done) async {
      for (var i = 0; i < 60 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // The real screen: its cards watch the same observables the sheet changes.
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: WhatsAppNumbersScreen()));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    await settle(() => c.byId('wa1')?.qr != null);
    await tester.pump();

    expect(api.called('POST /whatsapp/connect'), isNotEmpty);
    expect(api.last('POST /whatsapp/connect').data, {'accountId': 'wa1'});
    expect(find.text('Preparing QR code…'), findsNothing);
    expect(find.text('Server: Waiting for QR scan'), findsOneWidget);

    // Close the sheet so its timers stop before the test ends.
    Navigator.of(tester.element(find.text('Link a number'.toUpperCase()))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    Get.delete<WhatsAppNumbersController>();
    Get.reset();
  });

  testWidgets('renaming closes the dialog cleanly and saves the new name', (tester) async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'admin-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
    });
    Get.put(SessionStore());
    final api = FakeApi()..install();
    var label = '7778885383';
    api.routes['GET /whatsapp/accounts'] = (_) => FakeReply(200, {
          'success': true,
          'data': {
            'accounts': [
              {'id': 'default', 'label': 'Main', 'status': 'open', 'user': {'phone': '919800000001'}},
              {'id': 'wa1', 'label': label, 'status': 'open', 'user': {'phone': '917778885383'}},
            ],
            'defaults': {'birthday': null, 'anniversary': null},
          },
        });
    api.routes['PUT /whatsapp/accounts/wa1'] = (r) {
      label = (r.data as Map)['label'] as String;
      return const FakeReply(200, {'success': true});
    };

    late WhatsAppNumbersController c;
    await tester.runAsync(() async {
      c = Get.put(WhatsAppNumbersController(isAdmin: true));
      await until(() => !c.isLoading.value, reason: 'numbers load');
    });
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: WhatsAppNumbersScreen()));
    await tester.pump();

    // The second card's menu (the first is Main).
    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Second Number');
    await tester.tap(find.text('Save'));
    // Run the closing animation fully: the field must not use a disposed controller.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.last('PUT /whatsapp/accounts/wa1').data, {'label': 'Second Number'});
    expect(find.text('Second Number'), findsOneWidget);

    Get.delete<WhatsAppNumbersController>();
    Get.reset();
  });
}
