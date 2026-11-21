import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/features/screentime/views/device_setup_screen.dart';

void main() {
  testWidgets('Accessibility consent requires an affirmative action', (
    tester,
  ) async {
    bool? consent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                consent = await AccessibilityProminentDisclosureDialog.show(
                  context,
                );
              },
              child: const Text('Review and enable'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Review and enable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('hostel server'), findsOneWidget);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(consent, isFalse);

    await tester.tap(find.text('Review and enable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and open Settings'));
    await tester.pumpAndSettle();
    expect(consent, isTrue);
  });
}
