import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/whatsapp/whatsapp_account.dart';
import 'package:hsh_app2/features/whatsapp_accounts/widgets/send_from_sheet.dart';

import 'support/test_fonts.dart';

/// The "Send from" sheet at phone size: the default number is preselected,
/// a number that is not connected cannot be picked, and nothing is sent until
/// Send is tapped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadDeviceLikeFonts();
    await serveGoogleFontsAsAssets();
  });

  const accounts = [
    WhatsAppAccount(id: 'default', label: 'Main', status: 'open', phone: '919712977261'),
    WhatsAppAccount(id: 'wa1', label: 'Second Number', status: 'open', phone: '917778885383'),
    WhatsAppAccount(id: 'wa2', label: 'Spare', status: 'disconnected'),
  ];

  Future<SendFromChoice?> Function() openSheet(WidgetTester tester) {
    SendFromChoice? result;
    var done = false;
    return () async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<SendFromChoice>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const SendFromSheet(
                    accounts: accounts,
                    defaultId: 'wa1',
                    preselectedId: 'wa1',
                    purpose: 'birthday',
                  ),
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(done, isFalse);
      return result;
    };
  }

  testWidgets('default is preselected and sent; offline numbers cannot be picked', (tester) async {
    await openSheet(tester)();

    expect(tester.takeException(), isNull); // no overflow at phone width
    expect(find.text('Choose a WhatsApp number'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('+91 97129 77261'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Send from Second Number'), findsOneWidget);

    // Tapping a disconnected number changes nothing.
    await tester.tap(find.text('Spare'));
    await tester.pumpAndSettle();
    expect(find.text('Send from Second Number'), findsOneWidget);

    // Picking another connected number only changes the selection.
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    expect(find.text('Send from Main'), findsOneWidget);
    expect(find.byType(SendFromSheet), findsOneWidget);
  });

  testWidgets('Send returns the chosen number', (tester) async {
    SendFromChoice? result;
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<SendFromChoice>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SendFromSheet(accounts: accounts, defaultId: 'wa1', preselectedId: 'wa1'),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send from Main'));
    await tester.pumpAndSettle();

    expect(result?.accountId, 'default');
    expect(result?.label, 'Main');
    expect(find.byType(SendFromSheet), findsNothing);
  });

  test('phone numbers are shown in a readable form', () {
    expect(formatWhatsAppPhone('919712977261'), '+91 97129 77261');
    expect(formatWhatsAppPhone('447700900123'), '+447700900123');
  });
}
