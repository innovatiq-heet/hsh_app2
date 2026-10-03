import 'package:get/get.dart';
import '../../../core/abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/models/student_profile/student_profile_model.dart';
import '../../../core/network/repository/fees/fees_repository.dart';
import '../../../core/network/repository/laundry/laundry_repository.dart';
import '../../../core/network/repository/student_profile/student_profile_repository.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';

class StudentProfileController extends GetxController
    with AadharResolvingMixin, LoadStateMixin {
  final StudentProfileRepository _repository = Get.find();
  final FeesRepository _feesRepository = Get.find();
  final LaundryRepository _laundryRepository = Get.find();

  final Rxn<StudentProfileModel> profile = Rxn<StudentProfileModel>();

  @override
  void onInit() {
    super.onInit();
    final cached = Get.find<SessionStore>().currentStudentProfile;
    if (cached != null) {
      profile.value = cached;
    }
    loadProfile(showLoading: cached == null);
  }

  Future<void> loadProfile({bool forceRefresh = false, bool showLoading = true}) => guard(() async {
    final sessionStore = Get.find<SessionStore>();
    if (profile.value == null) {
      final cached = await sessionStore.studentProfile;
      if (cached != null) {
        profile.value = cached;
      }
    }
    final cachedPhone = await sessionStore.cachedPhone;
    final cachedEmail = await sessionStore.email;
    final cachedName = await sessionStore.name;
    final cachedStudentCode = await sessionStore.cachedStudentCode;
    String? aadhar = await sessionStore.cachedAadhar;

    if (aadhar == null || aadhar.isEmpty) {
      try {
        aadhar = await resolveAadhar(
          fromFeeSummary: _feesRepository.resolveAadhar,
          fromLaundryBalance: () async =>
              (await _laundryRepository.balance()).studentAadhar,
        );
      } catch (_) {
        // Fall back gracefully; fetchProfile will resolve from external API
      }
    }

    try {
      profile.value = await _repository.fetchProfile(
        aadhar: aadhar,
        phone: cachedPhone,
        email: cachedEmail,
        studentCode: cachedStudentCode,
        name: cachedName,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      if (aadhar != null && aadhar.isNotEmpty) {
        await Get.find<SessionStore>().clearAadhar();
      }
      rethrow;
    }
  }, showLoading: showLoading);

  /// Pull-to-refresh / post-edit reload entry point — same as the initial
  /// load, kept as a distinct name so call sites read intent rather than
  /// implementation. (Not named `refresh()`: GetX's `ListNotifierMixin`
  /// already defines that, for forcing a `GetBuilder` rebuild.)
  Future<void> refreshProfile() => loadProfile(forceRefresh: true, showLoading: true);

  Future<void> logout() async {
    await Get.find<SessionStore>().logout();
    Get.offAllNamed(Routes.login);
  }
}
