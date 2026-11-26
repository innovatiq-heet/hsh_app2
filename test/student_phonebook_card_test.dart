import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/tags/student_tag_model.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/phonebook/controllers/phonebook_controller.dart';
import 'package:hsh_app2/features/phonebook/models/phonebook_models.dart';
import 'package:hsh_app2/features/phonebook/views/student_detail_screen.dart';
import 'package:hsh_app2/features/shared/widgets/student_contact_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestPhonebookController extends PhonebookController {
  final bool leaderView;
  _TestPhonebookController({this.leaderView = false});

  @override
  bool get isLeaderView => leaderView;

  @override
  Future<void> syncNow({bool silent = false}) async {}

  @override
  Future<List<StudentTag>?> refreshStudentTags(PhonebookStudent student) async => [];
}

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
              onCall: (phone) => calledNumber = phone,
              onWhatsApp: (phone) => whatsAppNumber = phone,
            ),
          ),
        ),
      );

      // Shows room number and group chip
      expect(find.text('Room 102'), findsOneWidget);
      expect(find.text('Param'), findsOneWidget);
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

  testWidgets(
    'StudentDetailScreen defaults to collapsed view and master toggle shows Expand all',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Admin'}),
      });
      Get.testMode = true;
      Get.put(SessionStore());
      final controller = Get.put<PhonebookController>(_TestPhonebookController());

      try {
        const student = PhonebookStudent(
          id: '1095',
          studentId: '1095',
          name: 'Aaditya Hemangbhai Patel',
          enrollmentNumber: '1095',
          department: 'Pavitra • Room 305',
          batch: 'ACTIVE',
          room: '305',
          groupName: 'Pavitra',
          phones: [
            PhonebookContact(
              phone: '9876543210',
              phoneNormalized: '9876543210',
              label: 'Mobile',
            ),
          ],
        );

        await tester.pumpWidget(
          const GetMaterialApp(
            home: StudentDetailScreen(student: student),
          ),
        );
        await tester.pump();

        // Master toggle shows 'Expand all' because cards are collapsed by default
        expect(find.text('Expand all'), findsOneWidget);
        expect(find.text('Collapse all'), findsNothing);

        // Tapping 'Expand all' expands all sections and changes to 'Collapse all'
        await tester.tap(find.text('Expand all'));
        await tester.pump();

        expect(find.text('Collapse all'), findsOneWidget);
        expect(find.text('Expand all'), findsNothing);

        // Tapping 'Collapse all' collapses sections again
        await tester.tap(find.text('Collapse all'));
        await tester.pump();

        expect(find.text('Expand all'), findsOneWidget);
        expect(find.text('Collapse all'), findsNothing);
      } finally {
        controller.onClose();
        Get.reset();
      }
    },
  );

  testWidgets(
    'StudentDetailScreen shows Portal & Attendance, Documents, and Status for admins',
    (tester) async {
      const student = PhonebookStudent(
        id: '1095',
        studentId: '1095',
        name: 'Aaditya Hemangbhai Patel',
        enrollmentNumber: '1095',
        department: 'Pavitra • Room 305',
        batch: 'ACTIVE',
        room: '305',
        groupName: 'Pavitra',
        status: 'active',
        phones: [
          PhonebookContact(
            phone: '9876543210',
            phoneNormalized: '9876543210',
            label: 'Mobile',
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'auth_token': 'token',
        'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Admin'}),
      });
      Get.testMode = true;
      Get.put(SessionStore());
      final adminController = Get.put<PhonebookController>(_TestPhonebookController(leaderView: false));
      try {
        await tester.pumpWidget(
          const GetMaterialApp(home: StudentDetailScreen(student: student)),
        );
        await tester.pump();

        expect(find.text('HOSTEL PORTAL & ATTENDANCE'), findsOneWidget);
        expect(find.text('DOCUMENTS'), findsOneWidget);

        await tester.tap(find.text('Expand all'));
        await tester.pump();

        expect(find.text('Status'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
      } finally {
        adminController.onClose();
        Get.reset();
      }
    },
  );

  testWidgets(
    'StudentDetailScreen hides Portal & Attendance, Documents, and Status for leaders',
    (tester) async {
      const student = PhonebookStudent(
        id: '1095',
        studentId: '1095',
        name: 'Aaditya Hemangbhai Patel',
        enrollmentNumber: '1095',
        department: 'Pavitra • Room 305',
        batch: 'ACTIVE',
        room: '305',
        groupName: 'Pavitra',
        status: 'active',
        phones: [
          PhonebookContact(
            phone: '9876543210',
            phoneNormalized: '9876543210',
            label: 'Mobile',
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'auth_token': 'token',
        'user_session': jsonEncode({'role': 'leader', 'token': 'token', 'name': 'Leader'}),
      });
      Get.testMode = true;
      Get.put(SessionStore());
      final leaderController = Get.put<PhonebookController>(_TestPhonebookController(leaderView: true));
      try {
        await tester.pumpWidget(
          const GetMaterialApp(home: StudentDetailScreen(student: student)),
        );
        await tester.pump();

        expect(find.text('HOSTEL PORTAL & ATTENDANCE'), findsNothing);
        expect(find.text('DOCUMENTS'), findsNothing);

        await tester.tap(find.text('Expand all'));
        await tester.pump();

        expect(find.text('Status'), findsNothing);
        expect(find.text('ACTIVE'), findsNothing);
        expect(find.text('HOSTEL PORTAL & ATTENDANCE'), findsNothing);
        expect(find.text('DOCUMENTS'), findsNothing);
      } finally {
        leaderController.onClose();
        Get.reset();
      }
    },
  );
}
