import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hsh_app2/features/shared/widgets/student_contact_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'StudentContactCard in phonebook shows room number and small call & whatsapp icons',
    (tester) async {
      String? calledNumber;
      String? whatsAppNumber;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentContactCard(
              name: 'Ketan Patel',
              room: '102',
              groupName: 'Param',
              primaryPhone: '9876543210',
              onTap: () {},
              onCall: (num) => calledNumber = num,
              onWhatsApp: (num) => whatsAppNumber = num,
            ),
          ),
        ),
      );

      // Shows room number
      expect(find.text('Room 102'), findsOneWidget);
      // Does not show ID or DOB
      expect(find.textContaining('ID:'), findsNothing);

      // Shows small WhatsApp and Call icon buttons
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
      expect(find.byType(FaIcon), findsOneWidget);

      // Tap WhatsApp button invokes callback
      await tester.tap(find.byType(FaIcon));
      expect(whatsAppNumber, '9876543210');

      // Tap Call button invokes callback
      await tester.tap(find.byIcon(Icons.phone_rounded));
      expect(calledNumber, '9876543210');
    },
  );

  testWidgets(
    'StudentContactCard handles alumni without allotted room',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentContactCard(
              name: 'Jayesh Parmar',
              isAlumni: true,
              primaryPhone: '9876543211',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Alumni'), findsOneWidget);
    },
  );
}
