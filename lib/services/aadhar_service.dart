import 'package:get/get.dart';
import '../core/network/api_exception.dart';
import '../core/network/repository/fees/fees_repository.dart';
import '../core/network/repository/laundry/laundry_repository.dart';
import '../../core/storage/session_store.dart';

/// Resolves a student's Aadhar number using a cascading fallback strategy,
/// then caches the result in [SessionStore].
///
/// Previously this logic was a mixin that forced every using controller to
/// inject [FeesRepository] and [LaundryRepository] directly — leaking
/// unrelated dependencies into their constructors. Now it lives in one
/// registered service that controllers simply `Get.find()`.
///
/// Resolution order:
///   1. In-memory cache (fastest — already resolved this session).
///   2. [SessionStore] persistent cache (survives hot-restart).
///   3. [FeesRepository.resolveAadhar] — fee summary endpoint.
///   4. [LaundryRepository.balance] — laundry balance endpoint.
///   5. Throws [ApiException] if all sources fail.
class AadharService extends GetxService {
  final FeesRepository _feesRepo = Get.find();
  final LaundryRepository _laundryRepo = Get.find();
  final SessionStore _session = Get.find();

  String? _cached;

  /// Returns the resolved Aadhar or throws [ApiException].
  Future<String> resolve() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;

    final persisted = await _session.cachedAadhar;
    if (persisted != null && persisted.isNotEmpty) {
      _cached = persisted;
      return _cached!;
    }

    final fromFee = await _feesRepo.resolveAadhar();
    if (fromFee != null && fromFee.isNotEmpty) {
      _cached = fromFee;
      await _session.cacheAadhar(fromFee);
      return _cached!;
    }

    try {
      final balance = await _laundryRepo.balance();
      final fromLaundry = balance.studentAadhar;
      if (fromLaundry.isNotEmpty) {
        _cached = fromLaundry;
        await _session.cacheAadhar(fromLaundry);
        return _cached!;
      }
    } catch (_) {
      // Laundry endpoint is a best-effort fallback; swallow its errors.
    }

    final email = await _session.email;
    final accountDesc =
        (email != null && email.isNotEmpty) ? email : 'your account';
    throw ApiException(
      'No student profile is linked with $accountDesc yet. '
      'Please contact the hostel administration or warden to register your profile.',
      statusCode: 404,
    );
  }

  /// Clears the in-memory cache (call after logout).
  void invalidate() => _cached = null;
}
