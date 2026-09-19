import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/laundry_status.dart';
import '../../common_enums/user_role.dart';
import '../../network/repository/laundry/laundry_repository.dart';
import '../../network/request/laundry/submit_laundry_request.dart';
import '../../network/responses/laundry/laundry_responses.dart';
import '../../storage/session_store.dart';

class LaundryOrdersController extends GetxController with LoadStateMixin {
  final LaundryRepository _repository = Get.find();

  final tickets = <LaundryTicketModel>[].obs;
  final Rxn<LaundryStatus> statusFilter = Rxn<LaundryStatus>();
  final searchQuery = ''.obs;
  final advancingTicketId = RxnString();
  final isAdmin = false.obs;

  int get pendingCount =>
      tickets.where((t) => t.status == LaundryStatus.pending).length;
  int get acceptedCount =>
      tickets.where((t) => t.status == LaundryStatus.accepted).length;
  int get washedCount =>
      tickets.where((t) => t.status == LaundryStatus.washed).length;
  int get receivedCount =>
      tickets.where((t) => t.status == LaundryStatus.received).length;
  int get activeCount =>
      tickets.where((t) => t.status != LaundryStatus.received).length;

  int countForStatus(LaundryStatus? status) {
    if (status == null) return tickets.length;
    return tickets.where((t) => t.status == status).length;
  }

  List<LaundryTicketModel> get filtered {
    return tickets.where((t) {
      if (statusFilter.value != null && t.status != statusFilter.value) {
        return false;
      }
      final query = searchQuery.value.trim().toLowerCase();
      if (query.isEmpty) return true;
      final tid = t.id.toString().toLowerCase();
      return tid.contains(query) ||
          t.aadhar.toLowerCase().contains(query) ||
          t.studentName.toLowerCase().contains(query) ||
          t.room.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    _checkRole();
    load();
  }

  Future<void> _checkRole() async {
    final role = await SessionStore.instance.role;
    isAdmin.value = role == UserRole.admin;
  }

  Future<void> load() => guard(() async {
    tickets.assignAll(await _repository.adminTickets());
  });

  Future<void> acceptTicket(String ticketId) async {
    advancingTicketId.value = ticketId;
    try {
      final updated = await _repository.updateTicket(
        ticketId,
        const UpdateLaundryTicketRequest(status: LaundryStatus.accepted),
      );
      final idx = tickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) tickets[idx] = updated;
      Get.snackbar('Success', 'Ticket #$ticketId marked as accepted.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to accept ticket: $e');
    } finally {
      advancingTicketId.value = null;
    }
  }

  Future<void> markWashed(
    String ticketId, {
    double? washPrice,
    double? pressPrice,
    double? blanketPrice,
    double? jacketPrice,
    double? bedSheetPrice,
  }) async {
    advancingTicketId.value = ticketId;
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
      final idx = tickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) tickets[idx] = updated;
      Get.snackbar(
        'Success',
        'Ticket #$ticketId marked as washed with updated pricing.',
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to mark ticket as washed: $e');
    } finally {
      advancingTicketId.value = null;
    }
  }

  Future<void> markReceived(String ticketId) async {
    advancingTicketId.value = ticketId;
    try {
      final updated = await _repository.updateTicket(
        ticketId,
        const UpdateLaundryTicketRequest(status: LaundryStatus.received),
      );
      final idx = tickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) tickets[idx] = updated;
      Get.snackbar('Success', 'Ticket #$ticketId marked as received.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to complete ticket: $e');
    } finally {
      advancingTicketId.value = null;
    }
  }

  Future<void> deleteTicket(String ticketId) async {
    advancingTicketId.value = ticketId;
    try {
      await _repository.deleteTicket(ticketId);
      tickets.removeWhere((t) => t.id == ticketId);
      Get.snackbar('Deleted', 'Ticket #$ticketId has been deleted.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete ticket: $e');
    } finally {
      advancingTicketId.value = null;
    }
  }
}
