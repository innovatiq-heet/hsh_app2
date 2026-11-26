import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/alumni/alumni_models.dart';
import 'package:hsh_app2/core/network/repository/alumni/alumni_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/alumni/controllers/alumni_daily_outreach_controller.dart';
import 'package:hsh_app2/features/alumni/views/alumni_daily_outreach_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/test_fonts.dart';

String _day(int back) {
  final d = DateTime.now().subtract(Duration(days: back));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Records what the screen asks the server for.
class FakeAlumniRepository extends AlumniRepository {
  final groupsAsked = <String?>[];
  final contacted = <(int, String?)>[];
  final skipped = <int>[];
  int historyCalls = 0;
  int failLoads = 0;

  AlumniDailyOutreachDataModel today({String group = 'Param', List<AlumniOutreachStudentModel>? students}) =>
      AlumniDailyOutreachDataModel(
        groupName: group,
        date: _day(0),
        targetDailyCount: 5,
        contactedTodayCount: 1,
        totalAlumniInGroup: 135,
        totalMessagedAlumni: 12,
        messageTemplate: 'Jai Swaminarayan {first_name} from {group_name} (room {room})',
        students:
            students ??
            const [
              AlumniOutreachStudentModel(
                studentId: 101,
                name: 'Alum One',
                pastRoom: '101',
                phone: '9876543210',
                groupName: 'Param',
                status: 'messaged',
                message: 'Hello Alum One',
              ),
              AlumniOutreachStudentModel(
                studentId: 102,
                name: 'Alum Two',
                pastRoom: '102',
                phone: '9876543211',
                graduationYear: 2019,
                currentDesignation: 'Engineer',
                currentCompany: 'Tata',
                groupName: 'Param',
              ),
            ],
      );

  @override
  Future<AlumniDailyOutreachDataModel> getDailyOutreach({String? group}) async {
    groupsAsked.add(group);
    if (failLoads > 0) {
      failLoads--;
      throw Exception('Server unreachable');
    }
    return today(group: group ?? 'Param');
  }

  @override
  Future<void> markOutreachContacted(int studentId, {String? message, String channel = 'whatsapp'}) async {
    contacted.add((studentId, message));
  }

  @override
  Future<AlumniDailyOutreachDataModel> skipAndReplaceAlumnus(int studentId) async {
    skipped.add(studentId);
    return today(
      students: const [
        AlumniOutreachStudentModel(studentId: 101, name: 'Alum One', groupName: 'Param', status: 'messaged'),
        AlumniOutreachStudentModel(
          studentId: 103,
          name: 'Alum Three',
          pastRoom: '103',
          phone: '9876543212',
          groupName: 'Param',
        ),
      ],
    );
  }

  @override
  Future<List<AlumniOutreachHistoryModel>> getOutreachHistory({
    String? group,
    String? scope,
    int limit = 100,
  }) async {
    historyCalls++;
    return [
      AlumniOutreachHistoryModel(
        id: 1,
        studentId: 101,
        name: 'Alum One',
        phone: '9876543210',
        whatsappNumber: '9876543210',
        pastRoom: '101',
        outreachDate: _day(0),
        contactedAt: '${_day(0)}T10:30:00Z',
        message: 'Hi',
        leaderName: 'Ravi',
        outreachScope: 'leader',
        sentByRole: 'leader',
      ),
      AlumniOutreachHistoryModel(
        id: 2,
        studentId: 90,
        name: 'Old Friend',
        pastRoom: '90',
        outreachDate: _day(1),
        leaderName: 'Ravi',
      ),
      AlumniOutreachHistoryModel(
        id: 3,
        studentId: 91,
        name: 'Older Friend',
        pastRoom: '91',
        outreachDate: _day(1),
        leaderName: 'Ravi',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAlumniRepository repo;

  setUpAll(() async {
    await loadDeviceLikeFonts();
    await serveGoogleFontsAsAssets();
  });

  Future<void> signIn(String role) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': role, 'token': 'token', 'name': 'Ravi Leader'}),
    });
    Get.testMode = true;
    FakeApi().install();
    final session = Get.put(SessionStore());
    await until(() => session.currentSession != null, reason: 'the session');
    repo = FakeAlumniRepository();
  }

  tearDown(Get.reset);

  Future<AlumniDailyOutreachController> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = Get.put(AlumniDailyOutreachController(repository: repo));
    await tester.pumpWidget(const GetMaterialApp(home: AlumniDailyOutreachScreen()));
    await tester.pumpAndSettle();
    return c;
  }

  /// Lets a snackbar run out so no timer outlives the test.
  Future<void> settleSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  group('controller', () {
    test('lists the alumni still to contact first', () async {
      await signIn('leader');
      final c = Get.put(AlumniDailyOutreachController(repository: repo));
      await until(() => c.outreachData.value != null, reason: 'today');

      expect(c.isLeader.value, isTrue);
      expect(repo.groupsAsked, [null], reason: 'a leader gets their own group');
      expect(c.orderedStudents.map((s) => s.name), ['Alum Two', 'Alum One']);
      expect(c.pendingCount, 1);
    });

    test('fills the template; an own message wins until it is cleared', () async {
      await signIn('leader');
      final c = Get.put(AlumniDailyOutreachController(repository: repo));
      await until(() => c.outreachData.value != null, reason: 'today');
      final two = c.orderedStudents.first;

      expect(c.getFormattedMessage(two), 'Jai Swaminarayan Alum from Param (room 102)');
      c.setCustomMessage(two.studentId, '  Hi Alum, how are you?  ');
      expect(c.getFormattedMessage(two), 'Hi Alum, how are you?');
      expect(c.hasCustomMessage(two.studentId), isTrue);
      c.setCustomMessage(two.studentId, '   ');
      expect(c.hasCustomMessage(two.studentId), isFalse);
    });

    test('history is grouped by day, newest first', () async {
      await signIn('leader');
      final c = Get.put(AlumniDailyOutreachController(repository: repo));
      await c.loadHistory();
      final days = c.historyByDay;
      expect(days.map((d) => d.key), [_day(0), _day(1)]);
      expect(days.last.value.map((h) => h.name), ['Old Friend', 'Older Friend']);
    });

    test('nothing is recorded when WhatsApp does not open', () async {
      await signIn('leader');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      final c = Get.put(AlumniDailyOutreachController(repository: repo));
      await until(() => c.outreachData.value != null, reason: 'today');

      await c.openWhatsApp(c.orderedStudents.first);

      expect(repo.contacted, isEmpty);
      expect(c.pendingCount, 1);
    });

    test('marking done counts once and updates the progress', () async {
      await signIn('leader');
      final c = Get.put(AlumniDailyOutreachController(repository: repo));
      await until(() => c.outreachData.value != null, reason: 'today');
      final two = c.orderedStudents.first;

      await Future.wait([c.markContacted(two), c.markContacted(two)]);

      expect(repo.contacted, [(102, 'Jai Swaminarayan Alum from Param (room 102)')]);
      expect(c.outreachData.value!.contactedTodayCount, 2);
      expect(c.outreachData.value!.totalMessagedAlumni, 13);
      expect(c.pendingCount, 0);
    });
  });

  group('screen', () {
    testWidgets('a leader sees progress, pending alumni first, and no group picker', (tester) async {
      await tester.runAsync(() => signIn('leader'));
      await pumpScreen(tester);

      expect(find.text('Daily Alumni Connect'), findsWidgets);
      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('Today\'s connects'), findsOneWidget);
      expect(find.text('135'), findsOneWidget);
      expect(find.text('GROUP'), findsNothing);
      expect(find.text('Message'), findsWidgets); // the leader's tab name
      expect(find.text('Template'), findsNothing);

      final two = tester.getTopLeft(find.text('Alum Two')).dy;
      final one = tester.getTopLeft(find.text('Alum One')).dy;
      expect(two, lessThan(one), reason: 'still to contact comes first');
      expect(find.text('Room 102 · Batch of 2019'), findsOneWidget);
      expect(find.byTooltip('Send on WhatsApp'), findsOneWidget);
      expect(find.byTooltip('Send again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an admin can switch group and edit the template', (tester) async {
      await tester.runAsync(() => signIn('admin'));
      await pumpScreen(tester);

      expect(find.text('GROUP'), findsOneWidget);
      await tester.tap(find.text('Pavitra'));
      await tester.pumpAndSettle();
      expect(repo.groupsAsked.last, 'Pavitra');

      await tester.tap(find.text('Template'));
      await tester.pumpAndSettle();
      expect(find.text('Save template'), findsOneWidget);
      expect(find.text('PREVIEW FOR ALUM ONE'), findsOneWidget);
    });

    testWidgets('history puts contact actions, sender scope, and status filter in reach', (tester) async {
      await tester.runAsync(() => signIn('admin'));
      await pumpScreen(tester);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('Contact history'), findsOneWidget);
      expect(find.text('All senders'), findsOneWidget);
      expect(find.text('By Leaders'), findsOneWidget);
      expect(find.text('By Admin'), findsOneWidget);
      expect(find.text('Not Reachable'), findsWidgets);
      expect(find.text('04:00 PM'), findsOneWidget); // 10:30Z displayed in IST

      await tester.tap(find.text('Alum One'));
      await tester.pumpAndSettle();
      expect(find.text('Sent message'), findsOneWidget);
      expect(find.text('Hi'), findsOneWidget);
      expect(find.text('Edit WhatsApp'), findsOneWidget);
      expect(find.text('Set status'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not Reachable').first);
      await tester.pumpAndSettle();
      expect(find.text('No matching connects found.'), findsOneWidget);
    });

    testWidgets('canceling a WhatsApp number edit closes the sheet cleanly', (tester) async {
      await tester.runAsync(() => signIn('admin'));
      await pumpScreen(tester);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alum One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit WhatsApp'));
      await tester.pumpAndSettle();

      expect(find.text('Update WhatsApp contact'), findsOneWidget);
      expect(find.text('Primary Mobile (unchanged): 9876543210'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Update WhatsApp contact'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mark as done from the menu moves the alumnus to done', (tester) async {
      await tester.runAsync(() => signIn('leader'));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('More').first); // Alum Two, the pending one
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as done'));
      await tester.pumpAndSettle();

      expect(repo.contacted.single.$1, 102);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.byTooltip('Send on WhatsApp'), findsNothing);
      await settleSnackbars(tester);
    });

    testWidgets('skip asks first; cancel keeps the alumnus', (tester) async {
      await tester.runAsync(() => signIn('leader'));
      await pumpScreen(tester);

      Future<void> openSkip() async {
        await tester.tap(find.byTooltip('More').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skip and replace'));
        await tester.pumpAndSettle();
      }

      await openSkip();
      expect(find.text('Skip Alum Two?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.skipped, isEmpty);
      expect(find.text('Skip Alum Two?'), findsNothing);

      await openSkip();
      await tester.tap(find.widgetWithText(FilledButton, 'Skip and replace'));
      await tester.pumpAndSettle();
      expect(repo.skipped, [102]);
      expect(find.text('Alum Three'), findsOneWidget);
      expect(find.text('Alum Two'), findsNothing);
      await settleSnackbars(tester);
    });

    testWidgets('editing one alumnus\'s message', (tester) async {
      await tester.runAsync(() => signIn('leader'));
      final c = await pumpScreen(tester);

      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit message'));
      await tester.pumpAndSettle();
      expect(find.text('Message for Alum Two'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Hi Alum, long time!');
      await tester.tap(find.text('Save message'));
      await tester.pumpAndSettle();

      expect(find.text('Message for Alum Two'), findsNothing);
      expect(c.hasCustomMessage(102), isTrue);
      expect(c.getFormattedMessage(c.orderedStudents.first), 'Hi Alum, long time!');
    });

    testWidgets('history loads once, grouped by day', (tester) async {
      await tester.runAsync(() => signIn('leader'));
      await pumpScreen(tester);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('2 alumni'), findsOneWidget);
      expect(find.text('Older Friend'), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(repo.historyCalls, 1);
    });

    testWidgets('a failed load shows the error with a retry', (tester) async {
      await tester.runAsync(() => signIn('leader'));
      repo.failLoads = 1;
      await pumpScreen(tester);

      expect(find.text('Could not load today\'s alumni'), findsOneWidget);
      expect(find.text('Server unreachable'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Alum Two'), findsOneWidget);
    });
  });
}
