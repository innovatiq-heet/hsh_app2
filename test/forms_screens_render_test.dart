import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/forms/form_models.dart';
import 'package:hsh_app2/core/network/repository/forms/forms_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/forms/controllers/form_editor_controller.dart';
import 'package:hsh_app2/features/forms/controllers/forms_list_controller.dart';
import 'package:hsh_app2/features/forms/views/form_editor_screen.dart';
import 'package:hsh_app2/features/forms/views/forms_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/test_fonts.dart';

/// Renders the Forms & Polls screens on a phone-sized screen, so layout
/// errors (overflows, bad constraints) show up offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  setUpAll(() async {
    await loadDeviceLikeFonts();
    await serveGoogleFontsAsAssets();
  });

  Future<void> signIn() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'token', 'name': 'Admin'}),
    });
    final session = Get.put(SessionStore());
    await until(() => session.currentSession != null, reason: 'the session');
    api = FakeApi()..install();
    Get.put(FormsRepository());
    Get.put(TagsRepository());
    api.on('GET /tags', {'success': true, 'data': []});
  }

  Map<String, dynamic> formJson(int id, String type, String status) => {
    'id': id,
    'title': 'Hostel feedback survey for this semester',
    'description': 'Tell us how the hostel is doing',
    'form_type': type,
    'fields': [
      {'id': 'q1', 'label': 'Choose item', 'type': type == 'poll' ? 'poll' : 'radio', 'required': true, 'options': ['A', 'B']},
      if (type == 'form') {'id': 'q2', 'label': 'Comments', 'type': 'textarea', 'required': false, 'options': []},
    ],
    'target_audience': 'current',
    'start_time': '2026-11-11 18:00:00',
    'end_time': '2026-11-12 21:00:00',
    'is_active': status != 'disabled',
    'is_mandatory': id == 1,
    'total_targeted': 420,
    'total_viewed': 180,
    'total_responded': 125,
    'seen_not_answered': 55,
    'status': status,
  };

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  tearDown(Get.reset);

  testWidgets('the editor shows a simple poll, then a form with several questions', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    final c = Get.put(FormEditorController());
    await tester.pumpWidget(const GetMaterialApp(home: FormEditorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('New poll'), findsWidgets);
    expect(find.text('Create poll'), findsOneWidget);
    expect(find.text('Add question'), findsNothing, reason: 'a poll is one question');
    expect(find.text('Answer required'), findsNothing);
    // Title, description, the question and its two starting options.
    expect(find.byType(TextField), findsNWidgets(5));
    expect(find.text('Option 2'), findsOneWidget);

    await tester.tap(find.text('Form'));
    await tester.pumpAndSettle();
    expect(c.kind.value, FormKind.form);
    expect(find.text('Create form'), findsOneWidget);
    expect(find.text('Add question'), findsOneWidget);
    expect(find.text('Answer required'), findsOneWidget);

    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    expect(c.questions, hasLength(2));

    // The audience opens up when "Selected" is chosen.
    await tester.scrollUntilVisible(find.text('Selected'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Selected'));
    await tester.pumpAndSettle();
    expect(find.text('Floors'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list shows each poll or form as a short coloured card', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    api.on('GET /forms', {
      'success': true,
      'data': [formJson(1, 'poll', 'active'), formJson(2, 'form', 'disabled'), formJson(3, 'form', 'expired')],
    });
    Get.put(FormsListController());
    await tester.pumpWidget(const GetMaterialApp(home: FormsListScreen()));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.text('Hostel feedback survey for this semester'), findsWidgets);
    expect(find.text('Poll'), findsWidgets);
    expect(find.text('Paused'), findsWidgets);
    expect(find.textContaining('125 of 420 answered'), findsWidgets);
    expect(find.textContaining('seen, not answered'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a poll is one question; switching to Form brings the others back', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    final c = Get.put(FormEditorController());
    await tester.pumpWidget(const GetMaterialApp(home: FormEditorScreen()));
    await tester.pumpAndSettle();
    expect(c.questions, hasLength(1));

    c.setKind(FormKind.form);
    c.addQuestion();
    c.addQuestion(FormFieldType.text);
    await tester.pumpAndSettle();
    expect(c.questions, hasLength(3));

    c.setKind(FormKind.poll);
    await tester.pumpAndSettle();
    expect(c.questions, hasLength(1), reason: 'a poll has one question');
    expect(find.text('Your question'), findsOneWidget);

    c.setKind(FormKind.form);
    await tester.pumpAndSettle();
    expect(c.questions.map((q) => q.id), ['q1', 'q2', 'q3'], reason: 'nothing was lost');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a text question becomes a choice question when the form turns into a poll', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    final c = Get.put(FormEditorController());
    await tester.pumpWidget(const GetMaterialApp(home: FormEditorScreen()));
    await tester.pumpAndSettle();

    c.setKind(FormKind.form);
    c.updateQuestion(0, c.questions[0].copyWith(type: FormFieldType.text, options: const []));
    await tester.pumpAndSettle();
    c.setKind(FormKind.poll);
    await tester.pumpAndSettle();

    expect(c.questions.single.type, FormFieldType.poll);
    expect(c.questions.single.options, hasLength(2));
    expect(find.text('Option 2'), findsOneWidget, reason: 'the poll shows its two options');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list has no second New button: the one at the bottom right is enough', (tester) async {
    phone(tester);
    await tester.runAsync(signIn);
    api.on('GET /forms', {'success': true, 'data': []});
    Get.put(FormsListController());
    await tester.pumpWidget(const GetMaterialApp(home: FormsListScreen()));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.text('No polls or forms yet'), findsOneWidget);
    expect(find.text('New poll or form'), findsOneWidget, reason: 'only the button at the bottom right');
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
