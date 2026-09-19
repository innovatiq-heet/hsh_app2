import 'package:get/get.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/responses/laundry/laundry_responses.dart';

class LaundryTicketDetailController extends GetxController {
  final LaundryRepository _repository = Get.find();
  late final String ticketId = Get.arguments as String;

  final isLoading = true.obs;
  final ticket = Rxn<LaundryTicketResponse>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    ticket.value = await _repository.ticketDetail(ticketId);
    isLoading.value = false;
  }
}
