import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hsh_app2/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HshApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
  });
}
