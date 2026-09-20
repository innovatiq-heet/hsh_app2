import 'package:get/get.dart';
import '../../abstracts/mixins/load_state_mixin.dart';
import '../../common_enums/transaction_status.dart';
import '../../network/repository/fees/fees_repository.dart';
import '../../network/responses/fees/fee_responses.dart';

class FeesController extends GetxController with LoadStateMixin {
  final FeesRepository _repository = Get.find();

  final summary = Rxn<FeeSummaryResponse>();
  final debits = <FeeDebitResponse>[].obs;
  final deposits = <DepositEntryResponse>[].obs;
  final transactions = <FeeTransactionResponse>[].obs;

  final Rxn<String> academicYearFilter = Rxn<String>();
  final Rxn<TransactionStatus> transactionStatusFilter = Rxn<TransactionStatus>();

  List<String> get academicYears =>
      debits.map((e) => e.academicYear).toSet().toList()
        ..sort((a, b) => b.compareTo(a));

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() => guard(() async {
    final results = await Future.wait([
      _repository.summary(),
      _repository.debits(),
      _repository.deposits(),
      _repository.transactions(),
    ]);
    summary.value = results[0] as FeeSummaryResponse;
    debits.assignAll(results[1] as List<FeeDebitResponse>);
    deposits.assignAll(results[2] as List<DepositEntryResponse>);
    transactions.assignAll(results[3] as List<FeeTransactionResponse>);
  });

  List<FeeDebitResponse> get filteredDebits => academicYearFilter.value == null
      ? debits
      : debits
            .where((d) => d.academicYear == academicYearFilter.value)
            .toList();

  List<FeeTransactionResponse> get filteredTransactions =>
      transactionStatusFilter.value == null
          ? transactions
          : transactions
              .where((t) => t.status == transactionStatusFilter.value)
              .toList();
}
