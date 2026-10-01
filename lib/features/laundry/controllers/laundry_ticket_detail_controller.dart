import 'package:get/get.dart';
import '../../../core/enums/laundry_status.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/repository/laundry/laundry_repository.dart';
import '../../../core/network/request/laundry/submit_laundry_request.dart';
import '../../../core/network/responses/laundry/laundry_responses.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';

class LaundryTicketDetailController extends GetxController {
  final LaundryRepository _repository = Get.find();
  late final String ticketId = (Get.arguments ?? '').toString();

  final isLoading = true.obs;
  final isUpdating = false.obs;
  final canOperate = false.obs;
  final ticket = Rxn<LaundryTicketModel>();

  @override
  void onInit() {
    super.onInit();
    _checkRole();
    load();
  }

  Future<void> _checkRole() async {
    final role = await Get.find<SessionStore>().role;
    canOperate.value = role.canOperateLaundry;
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      ticket.value = await _repository.ticketDetail(ticketId);
    } catch (e) {
      AppSnackbar.error('Error', 'Could not load ticket details: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> acceptTicket() async {
    isUpdating.value = true;
    try {
      final updated = await _repository.updateTicket(
        ticketId,
        const UpdateLaundryTicketRequest(status: LaundryStatus.accepted),
      );
      ticket.value = updated;
      AppSnackbar.success('Success', 'Ticket #$ticketId marked as accepted.');
    } catch (e) {
      AppSnackbar.error('Error', 'Failed to accept ticket: $e');
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> markWashed({
    double? washPrice,
    double? pressPrice,
    double? blanketPrice,
    double? jacketPrice,
    double? bedSheetPrice,
  }) async {
    isUpdating.value = true;
    try {
      final updated = await _repository.updateTicket(
        ticketId,
        UpdateLaundryTicketRequest(
          status: LaundryStatus.washed,
          washPrice: washPrice,
          pressPrice: pressPrice,
          blanketPrice: blanketPrice,
          jacketPrice: jacketPrice,
          bedSheetPrice: bedSheetPrice,
        ),
      );
      ticket.value = updated;
      AppSnackbar.success(
        'Success',
        'Ticket #$ticketId marked as washed with pricing.',
      );
    } catch (e) {
      AppSnackbar.error('Error', 'Failed to update ticket: $e');
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> markReceived() async {
    isUpdating.value = true;
    try {
      final updated = await _repository.updateTicket(
        ticketId,
        const UpdateLaundryTicketRequest(status: LaundryStatus.received),
      );
      ticket.value = updated;
      AppSnackbar.success('Success', 'Ticket #$ticketId marked as delivered & received.');
    } catch (e) {
      AppSnackbar.error('Error', 'Failed to complete ticket: $e');
    } finally {
      isUpdating.value = false;
    }
  }
}
