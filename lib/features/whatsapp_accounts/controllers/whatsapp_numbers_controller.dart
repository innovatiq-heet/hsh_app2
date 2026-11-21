import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/whatsapp/whatsapp_account.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/whatsapp/whatsapp_accounts_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';

/// WhatsApp Numbers: every number the server keeps connected, with link /
/// disconnect for each, and (admin only) add, rename, delete and which number
/// the scheduled birthday / anniversary runs send from.
class WhatsAppNumbersController extends GetxController with LoadStateMixin {
  WhatsAppNumbersController({WhatsAppAccountsRepository? repo, bool? isAdmin})
      : _repo = repo ?? WhatsAppAccountsRepository(),
        isAdmin = isAdmin ??
            (Get.isRegistered<SessionStore>() &&
                Get.find<SessionStore>().currentSession?.role == UserRole.admin);

  final WhatsAppAccountsRepository _repo;

  /// Only admins add, rename or delete numbers and change the defaults.
  final bool isAdmin;

  final data = const WhatsAppAccountsData().obs;
  List<WhatsAppAccount> get accounts => data.value.accounts;

  /// Numbers with a request in flight.
  final busyIds = <String>{}.obs;

  /// Pairing code issued per number, with the phone it was issued for.
  final pairingCodes = <String, String>{}.obs;
  final pairingPhones = <String, String>{}.obs;

  /// Last error the server gave for a number (shown in its link sheet).
  final lastErrors = <String, String>{}.obs;

  Timer? _poll;
  bool _refreshing = false;

  /// Numbers with a link sheet open, and how many. They are polled even while
  /// they still read `disconnected` (the server starts the QR a moment after
  /// Connect), and their own `GET /status?accountId=` is read too, because
  /// that is where the QR is guaranteed to be.
  final _watched = <String, int>{};

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) => guard(() async {
        try {
          data.value = await _repo.fetch();
        } on ApiException {
          rethrow;
        } catch (e) {
          throw ApiException(e.toString().replaceFirst('Exception: ', ''));
        }
        _syncPolling();
      }, showLoading: showLoading);

  /// Quiet refresh used by polling and after every action.
  Future<void> refreshQuietly() async {
    if (_refreshing) return; // a slow server must not stack requests
    _refreshing = true;
    try {
      var next = data.value;
      try {
        next = await _repo.fetch();
      } catch (e) {
        debugPrint('[WhatsAppNumbers] list failed: $e');
      }
      for (final id in _watched.keys.toList()) {
        try {
          final own = await _repo.status(id);
          debugPrint('[WhatsAppNumbers] $id status=${own.status} qr=${own.qr != null} phone=${own.phone}');
          next = _merge(next, own, previous: data.value.byId(id));
        } catch (e) {
          debugPrint('[WhatsAppNumbers] $id status failed: $e');
        }
      }
      data.value = next;
      // A linked number no longer needs its code or its error.
      for (final a in accounts) {
        if (a.isOpen) {
          pairingCodes.remove(a.id);
          pairingPhones.remove(a.id);
          lastErrors.remove(a.id);
        }
      }
    } finally {
      _refreshing = false;
    }
    _syncPolling();
  }

  /// [own] (from `/status?accountId=`) wins over the list entry for status, QR
  /// and phone; the label comes from the list. While still waiting for a scan,
  /// a QR the list leaves out is kept from the last poll.
  static WhatsAppAccountsData _merge(WhatsAppAccountsData data, WhatsAppAccount own, {WhatsAppAccount? previous}) {
    final listed = data.byId(own.id);
    if (listed == null) return data;
    final waiting = own.status == 'qr' || listed.status == 'qr';
    final merged = WhatsAppAccount(
      id: listed.id,
      label: listed.label,
      status: own.status,
      qr: own.qr ?? listed.qr ?? (waiting ? previous?.qr : null),
      isRegistered: own.isRegistered || listed.isRegistered,
      phone: own.phone ?? listed.phone,
      profileName: own.profileName ?? listed.profileName,
    );
    return WhatsAppAccountsData(
      accounts: [for (final a in data.accounts) a.id == own.id ? merged : a],
      birthdayDefault: data.birthdayDefault,
      anniversaryDefault: data.anniversaryDefault,
    );
  }

  /// Poll every 3 s while any number is connecting / waiting; stop otherwise.
  void _syncPolling() {
    final needed = _watched.isNotEmpty || accounts.any((a) => a.isBusy) || pairingCodes.isNotEmpty;
    if (needed && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => refreshQuietly());
    } else if (!needed) {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// A link sheet opened / closed: keeps the status polling alive meanwhile.
  void watch(String id) {
    _watched[id] = (_watched[id] ?? 0) + 1;
    _syncPolling();
  }

  void unwatch(String id) {
    final n = (_watched[id] ?? 1) - 1;
    if (n <= 0) {
      _watched.remove(id);
    } else {
      _watched[id] = n;
    }
    _syncPolling();
  }

  WhatsAppAccount? byId(String id) => data.value.byId(id);

  bool isBusy(String id) => busyIds.contains(id);

  Future<T?> _busy<T>(String id, Future<T> Function() run, String failTitle) async {
    if (busyIds.contains(id)) return null;
    busyIds.add(id);
    lastErrors.remove(id);
    try {
      return await run();
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[WhatsAppNumbers] $id $failTitle: $message');
      lastErrors[id] = message;
      AppSnackbar.error(failTitle, message);
      return null;
    } finally {
      busyIds.remove(id);
    }
  }

  /// Starts linking by QR; the QR shows up through polling.
  Future<void> connect(String id) async {
    pairingCodes.remove(id);
    pairingPhones.remove(id);
    await _busy(id, () => _repo.connect(id), 'Could Not Connect');
    await refreshQuietly();
  }

  /// Digits with country code, as WhatsApp's pairing API needs ("919876543210").
  /// A bare 10-digit number is treated as Indian (91). Null if it can't be a phone number.
  static String? normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length == 10) digits = '91$digits';
    if (digits.length < 11 || digits.length > 15) return null;
    return digits;
  }

  /// Gets a pairing code for [id]. Returns true when a code was issued.
  Future<bool> pair(String id, String phoneInput) async {
    final phone = normalizePhone(phoneInput);
    if (phone == null) {
      AppSnackbar.warning('Invalid Number', 'Enter the WhatsApp number on this phone, e.g. 98765 43210.');
      return false;
    }
    final code = await _busy<String>(id, () async {
      // The pairing API needs an idle session: drop a pending QR one first.
      final current = byId(id);
      if (current != null && current.status != 'disconnected') {
        try {
          await _repo.disconnect(id);
          await Future.delayed(const Duration(milliseconds: 800));
        } catch (_) {}
      }
      return _repo.pair(id, phone);
    }, 'Pairing Failed');
    if (code == null) return false;
    pairingCodes[id] = code;
    pairingPhones[id] = phone;
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (_) {}
    AppSnackbar.success('Pairing Code Copied', 'Open WhatsApp and paste it under Linked devices.');
    await refreshQuietly();
    return true;
  }

  void clearPairing(String id) {
    pairingCodes.remove(id);
    pairingPhones.remove(id);
  }

  Future<void> disconnect(String id) async {
    clearPairing(id);
    final ok = await _busy(id, () async {
      await _repo.disconnect(id);
      return true;
    }, 'Disconnect Failed');
    if (ok == true) AppSnackbar.success('Disconnected', 'That WhatsApp number was unlinked.');
    await refreshQuietly();
  }

  /// Adds an empty slot and returns its id, ready to be linked.
  Future<String?> add(String label) async {
    final name = label.trim();
    if (name.isEmpty) {
      AppSnackbar.warning('Name Needed', 'Give the number a name, e.g. "Anniversary".');
      return null;
    }
    final id = await _busy<String>('new', () => _repo.add(name), 'Could Not Add Number');
    await refreshQuietly();
    return id;
  }

  Future<bool> rename(String id, String label) async {
    final name = label.trim();
    if (name.isEmpty) {
      AppSnackbar.warning('Name Needed', 'The name cannot be empty.');
      return false;
    }
    final ok = await _busy(id, () async {
      await _repo.rename(id, name);
      return true;
    }, 'Rename Failed');
    await refreshQuietly();
    return ok == true;
  }

  Future<bool> remove(String id) async {
    clearPairing(id);
    final ok = await _busy(id, () async {
      await _repo.delete(id);
      return true;
    }, 'Could Not Remove');
    await refreshQuietly();
    return ok == true;
  }

  /// Saves the number the scheduled run of [purpose] sends from; null = Main.
  Future<void> setDefault(String purpose, String? accountId) async {
    final previous = data.value;
    data.value = WhatsAppAccountsData(
      accounts: previous.accounts,
      birthdayDefault: purpose == 'birthday' ? accountId : previous.birthdayDefault,
      anniversaryDefault: purpose == 'anniversary' ? accountId : previous.anniversaryDefault,
    );
    try {
      await _repo.setDefaults({purpose: accountId});
    } catch (e) {
      data.value = previous;
      AppSnackbar.error('Could Not Save', e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
