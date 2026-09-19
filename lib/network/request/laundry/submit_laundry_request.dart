class SubmitLaundryRequest {
  final int itemCount;
  final String note;

  const SubmitLaundryRequest({required this.itemCount, this.note = ''});
}

class LaundryRechargeRequest {
  final String studentAadhar;
  final double amount;

  const LaundryRechargeRequest({
    required this.studentAadhar,
    required this.amount,
  });
}
