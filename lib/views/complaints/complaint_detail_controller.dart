import 'package:get/get.dart';
import '../../network/repository/complaints/complaints_repository.dart';
import '../../network/responses/complaints/complaint_response.dart';

class ComplaintDetailController extends GetxController {
  final ComplaintsRepository _repository = Get.find();
  late final String complaintId = Get.arguments as String;

  final isLoading = true.obs;
  final complaint = Rxn<ComplaintResponse>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    complaint.value = await _repository.detail(complaintId);
    isLoading.value = false;
  }
}
