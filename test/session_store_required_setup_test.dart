import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the four required device-setup steps were ever all granted at
/// once (`requiredSetupEverCompleted`), used to tell a first-time setup from
/// a later regression that needs a warden code. Persisted, and cleared on
/// logout so the next student on a handed-down phone starts fresh.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('defaults to false, true once marked, persists across instances', () async {
    final store = Get.put(SessionStore());
    expect(await store.requiredSetupEverCompleted, isFalse);

    await store.markRequiredSetupCompleted();
    expect(await store.requiredSetupEverCompleted, isTrue);

    // A fresh SessionStore (e.g. after an app restart) reads the same value
    // back from SharedPreferences, not just an in-memory flag.
    Get.delete<SessionStore>(force: true);
    final reloaded = Get.put(SessionStore());
    expect(await reloaded.requiredSetupEverCompleted, isTrue);
  });

  test('logout clears it, so the next student on this phone starts fresh', () async {
    final store = Get.put(SessionStore());
    await store.markRequiredSetupCompleted();
    expect(await store.requiredSetupEverCompleted, isTrue);

    await store.saveSession(token: 't', role: UserRole.student, email: 'a@b.com', name: 'A', room: '101');
    await store.logout();

    expect(await store.requiredSetupEverCompleted, isFalse);
  });
}
