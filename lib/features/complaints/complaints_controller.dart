import 'package:get/get.dart';
import '../../../core/abstracts/mixins/load_state_mixin.dart';
import '../../../core/network/repository/complaints/complaints_repository.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/services/aadhar_service.dart';

class ComplaintsController extends GetxController with LoadStateMixin {
  final ComplaintsRepository _repository = Get.find();
  final AadharService _aadharService = Get.find();

  final complaints = <ComplaintResponse>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
        final aadhar = await _aadharService.resolve();
        complaints.assignAll(await _repository.list(studentAadhar: aadhar));
      });
}
