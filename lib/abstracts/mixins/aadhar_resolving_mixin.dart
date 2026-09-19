import '../../storage/session_store.dart';

/// Aadhar is never returned by login — it's resolved from the fee-summary
/// call, falling back to the laundry-balance call, then cached locally.
/// Controllers that need the student's aadhar (attendance, leave, fees,
/// laundry) mix this in instead of re-implementing the lookup.
mixin AadharResolvingMixin {
  String? _aadhar;

  String? get resolvedAadhar => _aadhar;

  Future<String> resolveAadhar({
    Future<String?> Function()? fromFeeSummary,
    Future<String?> Function()? fromLaundryBalance,
  }) async {
    if (_aadhar != null) return _aadhar!;

    final cached = await SessionStore.instance.cachedAadhar;
    if (cached != null && cached.isNotEmpty) {
      _aadhar = cached;
      return cached;
    }

    final fromFee = await fromFeeSummary?.call();
    if (fromFee != null && fromFee.isNotEmpty) {
      _aadhar = fromFee;
      await SessionStore.instance.cacheAadhar(fromFee);
      return fromFee;
    }

    final fromLaundry = await fromLaundryBalance?.call();
    if (fromLaundry != null && fromLaundry.isNotEmpty) {
      _aadhar = fromLaundry;
      await SessionStore.instance.cacheAadhar(fromLaundry);
      return fromLaundry;
    }

    throw StateError('Unable to resolve student aadhar from any source.');
  }
}
