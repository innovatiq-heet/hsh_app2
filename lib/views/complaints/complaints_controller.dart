import 'package:get/get.dart';
import '../../abstracts/mixins/aadhar_resolving_mixin.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/responses/complaints/complaint_response.dart';

class ComplaintsController extends GetxController
    with AadharResolvingMixin, LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();
  final FeesRepository _feesRepository = Get.find();
  final LaundryRepository _laundryRepository = Get.find();

  final complaints = <ComplaintResponse>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    final aadhar = await resolveAadhar(
      fromFeeSummary: _feesRepository.resolveAadhar,
      fromLaundryBalance: () async =>
          (await _laundryRepository.balance()).studentAadhar,
    );
    complaints.assignAll(await _repository.list(studentAadhar: aadhar));
  });
}
