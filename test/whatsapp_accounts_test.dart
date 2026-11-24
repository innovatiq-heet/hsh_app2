import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/models/whatsapp/whatsapp_account.dart';
import 'package:hsh_app2/core/network/repository/anniversary/anniversary_repository.dart';
import 'package:hsh_app2/core/network/repository/birthday/birthday_repository.dart';
import 'package:hsh_app2/core/network/repository/whatsapp/whatsapp_accounts_repository.dart';
import 'package:hsh_app2/features/whatsapp_accounts/controllers/whatsapp_numbers_controller.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:hsh_app2/features/whatsapp_accounts/widgets/send_from_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// WhatsApp multi-number: the accounts list, linking, and the number a send
/// goes out from (`accountId`), with HTTP faked offline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeApi api;

  Map<String, dynamic> account(String id, String label, String status, {String? phone, String? qr}) => {
        'id': id,
        'label': label,
        'accountId': id,
        'status': status,
        'qr': qr,
        'isRegistered': status == 'open',
        'user': phone == null ? null : {'phone': phone, 'name': label},
      };

  Map<String, dynamic> accountsBody({String? birthday, String? anniversary, bool second = true}) => {
        'success': true,
        'data': {
          'accounts': [
            account('default', 'Main', 'open', phone: '919800000001'),
            if (second) account('wa1', 'Anniversary', 'disconnected'),
          ],
          'defaults': {'birthday': birthday, 'anniversary': anniversary},
        },
      };

  void boot() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'admin-token',
      'user_session': jsonEncode({'role': 'admin', 'token': 'admin-token', 'name': 'Super Admin'}),
    });
    Get.put(SessionStore());
    api = FakeApi()..install();
  }

  setUp(boot);

  tearDown(Get.reset);

  group('accounts model', () {
    test('parses accounts, phone and defaults; Main is the fallback default', () async {
      api.on('GET /whatsapp/accounts', accountsBody(anniversary: 'wa1'));
      final data = await WhatsAppAccountsRepository().fetch();

      expect(data.accounts.map((a) => a.id), ['default', 'wa1']);
      expect(data.accounts.first.isOpen, isTrue);
      expect(data.accounts.first.isMain, isTrue);
      expect(data.accounts.first.phone, '919800000001');
      expect(data.accounts.last.isOpen, isFalse);
      expect(data.defaultFor('anniversary')?.id, 'wa1');
      // null means the Main number
      expect(data.defaultFor('birthday')?.id, 'default');
    });

    test('only open numbers can send; connecting, qr and pairing are busy', () {
      expect(const WhatsAppAccount(id: 'a', label: 'A', status: 'open').isOpen, isTrue);
      for (final s in ['connecting', 'qr', 'pairing']) {
        final a = WhatsAppAccount(id: 'a', label: 'A', status: s);
        expect(a.isOpen, isFalse, reason: s);
        expect(a.isBusy, isTrue, reason: s);
      }
      expect(const WhatsAppAccount(id: 'a', label: 'A', status: 'disconnected').isBusy, isFalse);
    });
  });

  group('sending from a chosen number', () {
    test('birthday and anniversary sends carry accountId only when one was chosen', () async {
      api.on('POST /whatsapp/birthday/trigger', {'success': true, 'data': {'count': 1}});
      api.on('POST /whatsapp/anniversary/trigger', {'success': true, 'data': {'count': 1}});
      api.on('POST /whatsapp/anniversary/send-single', {'success': true, 'data': {'sentCount': 2}});

      await BirthdayRepository().triggerWishes(accountId: 'wa1');
      expect(api.last('POST /whatsapp/birthday/trigger').data, {'accountId': 'wa1'});

      await BirthdayRepository().triggerWishes();
      expect(api.last('POST /whatsapp/birthday/trigger').data, <String, dynamic>{});

      await AnniversaryRepository().triggerWishes(force: true, accountId: 'wa1');
      expect(api.last('POST /whatsapp/anniversary/trigger').data, {'force': true, 'accountId': 'wa1'});

      await AnniversaryRepository().sendSingleWish(studentId: 7, target: 'both', accountId: 'wa1');
      expect(api.last('POST /whatsapp/anniversary/send-single').data['accountId'], 'wa1');
      expect(api.last('POST /whatsapp/anniversary/send-single').data['studentId'], 7);
    });

    test('with a single number, or when the list cannot load, nothing is asked', () async {
      api.on('GET /whatsapp/accounts', accountsBody(second: false));
      final one = await pickSendFromAccount(purpose: 'birthday');
      expect(one?.legacy, isTrue);
      expect(one?.accountId, isNull);

      api.routes.remove('GET /whatsapp/accounts');
      final failed = await pickSendFromAccount(purpose: 'anniversary');
      expect(failed?.legacy, isTrue);
    });
  });

  group('numbers screen controller', () {
    late WhatsAppNumbersController c;

    Future<WhatsAppNumbersController> start({bool admin = true}) async {
      c = WhatsAppNumbersController(isAdmin: admin);
      Get.put(c);
      await until(() => !c.isLoading.value, reason: 'numbers load');
      return c;
    }

    test('loads the numbers; a failed load shows the server message', () async {
      api.on('GET /whatsapp/accounts', accountsBody());
      await start();
      expect(c.accounts.length, 2);
      expect(c.hasError.value, isFalse);

      Get.reset();
      boot();
      api.on('GET /whatsapp/accounts', {'success': false, 'message': 'WhatsApp is not set up'}, status: 400);
      await start();
      expect(c.hasError.value, isTrue);
      expect(c.errorMessage.value, 'WhatsApp is not set up');
    });

    test('connect and disconnect name the number (accountId)', () async {
      api.on('GET /whatsapp/accounts', accountsBody());
      api.on('POST /whatsapp/connect', {'success': true});
      api.on('POST /whatsapp/disconnect', {'success': true});
      await start();

      await c.connect('wa1');
      expect(api.last('POST /whatsapp/connect').data, {'accountId': 'wa1'});
      await c.disconnect('wa1');
      expect(api.last('POST /whatsapp/disconnect').data, {'accountId': 'wa1'});
    });

    test('pairing normalizes the phone and sends it with the accountId', () async {
      api.on('GET /whatsapp/accounts', accountsBody());
      api.on('POST /whatsapp/disconnect', {'success': true});
      api.on('POST /whatsapp/pair', {'success': true, 'code': 'ABCD-1234'});
      await start();

      expect(await c.pair('wa1', '12'), isFalse); // not a phone number
      expect(api.called('POST /whatsapp/pair'), isEmpty);

      expect(await c.pair('wa1', '98765 43210'), isTrue);
      expect(api.last('POST /whatsapp/pair').data, {'phone': '919876543210', 'accountId': 'wa1'});
      expect(c.pairingCodes['wa1'], 'ABCD-1234');
    });

    test('add, rename, delete and defaults; a rejected change rolls the default back', () async {
      api.on('GET /whatsapp/accounts', accountsBody());
      api.on('POST /whatsapp/accounts', {'success': true, 'data': {'id': 'wa2', 'label': 'Alumni'}}, status: 201);
      api.on('PUT /whatsapp/accounts/wa1', {'success': true});
      api.on('DELETE /whatsapp/accounts/wa1', {'success': true});
      api.on('PUT /whatsapp/accounts/defaults', {'success': true, 'data': {}});
      await start();

      expect(await c.add('  Alumni  '), 'wa2');
      expect(api.last('POST /whatsapp/accounts').data, {'label': 'Alumni'});
      expect(await c.add('   '), isNull); // no empty names, no request
      expect(api.called('POST /whatsapp/accounts').length, 1);

      expect(await c.rename('wa1', 'Wishes'), isTrue);
      expect(api.last('PUT /whatsapp/accounts/wa1').data, {'label': 'Wishes'});
      expect(await c.remove('wa1'), isTrue);

      await c.setDefault('anniversary', 'wa1');
      expect(api.last('PUT /whatsapp/accounts/defaults').data, {'anniversary': 'wa1'});
      expect(c.data.value.anniversaryDefault, 'wa1');
      // Main is saved as null
      await c.setDefault('birthday', null);
      expect(api.last('PUT /whatsapp/accounts/defaults').data, {'birthday': null});

      api.on('PUT /whatsapp/accounts/defaults', {'success': false, 'message': 'No such number'}, status: 404);
      await c.setDefault('anniversary', 'gone');
      expect(c.data.value.anniversaryDefault, 'wa1'); // rolled back
    });

    test('a number being linked reads its own /status, where the QR is', () async {
      // The list leaves the QR out; the number's own status has it.
      api.on('GET /whatsapp/accounts', accountsBody());
      api.routes['GET /whatsapp/status'] = (r) => FakeReply(200, {
            'success': true,
            'data': r.queryParameters['accountId'] == 'wa1'
                ? {'status': 'qr', 'qr': 'QR-TEXT', 'isRegistered': false, 'user': null}
                : {'status': 'open'},
          });
      await start();

      c.watch('wa1');
      await c.refreshQuietly();
      expect(api.last('GET /whatsapp/status').queryParameters, {'accountId': 'wa1'});
      final a = c.byId('wa1')!;
      expect(a.status, 'qr');
      expect(a.qr, 'QR-TEXT');
      expect(a.label, 'Anniversary'); // label still from the list

      // Once scanned, the number turns open and polling for it can stop.
      api.routes['GET /whatsapp/status'] = (_) => const FakeReply(200, {
            'success': true,
            'data': {'status': 'open', 'user': {'phone': '919811111111', 'name': 'x'}},
          });
      await c.refreshQuietly();
      expect(c.byId('wa1')!.isOpen, isTrue);
      expect(c.byId('wa1')!.phone, '919811111111');
      c.unwatch('wa1');
    });

    test('a failed connect is kept to show in the link sheet', () async {
      api.on('GET /whatsapp/accounts', accountsBody());
      api.on('POST /whatsapp/connect', {'success': false, 'message': 'Socket not ready, retry'}, status: 409);
      await start();

      await c.connect('wa1');
      expect(c.lastErrors['wa1'], 'Socket not ready, retry');
    });

    test('a number the server refuses to remove stays in the list', () async {
      api.on('GET /whatsapp/accounts', accountsBody());
      api.on('DELETE /whatsapp/accounts/default', {'success': false, 'message': 'Cannot delete the main number'}, status: 400);
      await start();

      expect(await c.remove('default'), isFalse);
      expect(c.accounts.any((a) => a.isMain), isTrue);
    });
  });
}
