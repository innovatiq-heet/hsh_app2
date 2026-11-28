import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/network/repository/broadcasts/broadcasts_repository.dart';
import 'package:hsh_app2/core/network/repository/tags/tags_repository.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/broadcast/controllers/broadcast_compose_controller.dart';
import 'package:hsh_app2/features/broadcast/utils/broadcast_rich_text.dart';
import 'package:hsh_app2/features/broadcast/views/broadcast_compose_screen.dart';
import 'package:hsh_app2/features/broadcast/widgets/rich_message_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadDeviceLikeFonts();
    await serveGoogleFontsAsAssets();
  });

  tearDown(Get.reset);

  group('RichBroadcastTextController WYSIWYG', () {
    test('tapping Bold / Italic / Underline / Strikethrough styles text without showing symbols', () {
      final ctrl = RichBroadcastTextController(text: 'Notice')
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 6);

      ctrl.toggleStyle(BroadcastStyleFlags.bold);
      ctrl.toggleStyle(BroadcastStyleFlags.italic);
      ctrl.toggleStyle(BroadcastStyleFlags.underline);
      ctrl.toggleStyle(BroadcastStyleFlags.strike);

      // Visible editor text stays 100% clean with zero syntax symbols.
      expect(ctrl.text, 'Notice');
      expect(
        ctrl.styleAt(0),
        BroadcastStyleFlags.bold |
            BroadcastStyleFlags.italic |
            BroadcastStyleFlags.underline |
            BroadcastStyleFlags.strike,
      );
      expect(ctrl.toFormattedMarkup(), '~<u>_*Notice*_</u>~');
      expect(BroadcastRichTextHelper.toPlainText(ctrl.toFormattedMarkup()), 'Notice');

      // Toggling Bold off preserves Italic + Underline + Strikethrough.
      ctrl.toggleStyle(BroadcastStyleFlags.bold);
      expect(ctrl.text, 'Notice');
      expect(
        ctrl.styleAt(0),
        BroadcastStyleFlags.italic |
            BroadcastStyleFlags.underline |
            BroadcastStyleFlags.strike,
      );
      expect(ctrl.toFormattedMarkup(), '~<u>_Notice_</u>~');

      ctrl.clearFormatting();
      expect(ctrl.styleAt(0), BroadcastStyleFlags.none);
      expect(ctrl.toFormattedMarkup(), 'Notice');
    });

    test('tapping Bold before typing makes newly typed characters bold with no symbols', () {
      final ctrl = RichBroadcastTextController(text: 'Hello ');
      ctrl.selection = const TextSelection.collapsed(offset: 6);

      // Turn Bold ON, then type "World"
      ctrl.toggleStyle(BroadcastStyleFlags.bold);
      expect(ctrl.activeMask & BroadcastStyleFlags.bold, isNonZero);

      ctrl.value = const TextEditingValue(
        text: 'Hello World',
        selection: TextSelection.collapsed(offset: 11),
      );

      expect(ctrl.text, 'Hello World');
      expect(ctrl.styleAt(0), BroadcastStyleFlags.none);
      expect(ctrl.styleAt(6), BroadcastStyleFlags.bold);
      expect(ctrl.toFormattedMarkup(), 'Hello *World*');

      // Turn Bold OFF, then type "!"
      ctrl.toggleStyle(BroadcastStyleFlags.bold);
      ctrl.value = const TextEditingValue(
        text: 'Hello World!',
        selection: TextSelection.collapsed(offset: 12),
      );
      expect(ctrl.styleAt(11), BroadcastStyleFlags.none);
      expect(ctrl.toFormattedMarkup(), 'Hello *World*!');
    });

    test('bullet and numbered lists preserve existing character formatting', () {
      final ctrl = RichBroadcastTextController(text: 'First\nSecond');
      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      ctrl.toggleStyle(BroadcastStyleFlags.bold);

      ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 12);
      ctrl.toggleList(numbered: false);
      expect(ctrl.text, '• First\n• Second');
      expect(ctrl.toFormattedMarkup(), '• *First*\n• Second');

      ctrl.toggleList(numbered: true);
      expect(ctrl.text, '1. First\n2. Second');
      expect(ctrl.toFormattedMarkup(), '1. *First*\n2. Second');
    });

    test('numbered and bullet lists stay selected and auto-continue 1, 2, 3 on Enter until empty line', () {
      final ctrl = RichBroadcastTextController();

      // Tap Numbered list on empty field -> inserts "1. " and marks active.
      ctrl.toggleList(numbered: true);
      expect(ctrl.text, '1. ');
      expect(ctrl.isNumberedActive, isTrue);
      expect(ctrl.isBulletActive, isFalse);

      // Type "One" and press Enter -> auto-inserts "2. ".
      ctrl.value = const TextEditingValue(
        text: '1. One',
        selection: TextSelection.collapsed(offset: 6),
      );
      ctrl.value = const TextEditingValue(
        text: '1. One\n',
        selection: TextSelection.collapsed(offset: 7),
      );
      expect(ctrl.text, '1. One\n2. ');
      expect(ctrl.selection.extentOffset, 10);
      expect(ctrl.isNumberedActive, isTrue);

      // Type "Two" and press Enter -> auto-inserts "3. ".
      ctrl.value = const TextEditingValue(
        text: '1. One\n2. Two',
        selection: TextSelection.collapsed(offset: 13),
      );
      ctrl.value = const TextEditingValue(
        text: '1. One\n2. Two\n',
        selection: TextSelection.collapsed(offset: 14),
      );
      expect(ctrl.text, '1. One\n2. Two\n3. ');

      // Press Enter on empty "3. " -> exits numbered list cleanly.
      ctrl.value = const TextEditingValue(
        text: '1. One\n2. Two\n3. \n',
        selection: TextSelection.collapsed(offset: 18),
      );
      expect(ctrl.text, '1. One\n2. Two\n');
      expect(ctrl.isNumberedActive, isFalse);

      // Bullet list behaves identically.
      final bulletCtrl = RichBroadcastTextController();
      bulletCtrl.toggleList(numbered: false);
      expect(bulletCtrl.text, '• ');
      expect(bulletCtrl.isBulletActive, isTrue);
      bulletCtrl.value = const TextEditingValue(
        text: '• First',
        selection: TextSelection.collapsed(offset: 7),
      );
      bulletCtrl.value = const TextEditingValue(
        text: '• First\n',
        selection: TextSelection.collapsed(offset: 8),
      );
      expect(bulletCtrl.text, '• First\n• ');
      expect(bulletCtrl.isBulletActive, isTrue);
    });
  });

  group('BroadcastComposeScreen WYSIWYG without Title', () {
    testWidgets('hides Title field and formats selected text cleanly without symbols',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'token',
        'user_session': jsonEncode({'role': 'admin', 'name': 'Admin', 'token': 'token'}),
      });
      Get.testMode = true;
      Get.put(SessionStore());
      final api = FakeApi()..install();
      api.on('GET /tags', {'success': true, 'data': []});
      api.on('GET /students', {'success': true, 'data': []});
      Get.put(TagsRepository());
      Get.put(BroadcastsRepository());
      final c = Get.put(BroadcastComposeController());

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const GetMaterialApp(home: BroadcastComposeScreen()),
      );
      await tester.pumpAndSettle();

      // Title field & complex Write/Preview switches are absent.
      expect(find.byType(RichMessageComposer), findsOneWidget);
      expect(find.text('Title (Optional)'), findsNothing);
      expect(find.text('Preview'), findsNothing);

      // Select "Meeting" and tap Bold + Underline + Strikethrough.
      c.messageController.value = const TextEditingValue(
        text: 'Meeting at 7pm',
        selection: TextSelection(baseOffset: 0, extentOffset: 7),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.format_bold_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.format_underlined_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.strikethrough_s_rounded));
      await tester.pump();

      // Editor keeps pure readable text with zero markup symbols shown.
      expect(c.messageController.text, 'Meeting at 7pm');
      // Underlying send payload carries the clean formatted markup.
      expect(c.trimmedMessage, '~<u>*Meeting*</u>~ at 7pm');
    });
  });
}
