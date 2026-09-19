import '../../../common_enums/laundry_status.dart';

class LaundryBalanceResponse {
  final String studentAadhar;
  final double balance;

  const LaundryBalanceResponse({
    required this.studentAadhar,
    required this.balance,
  });
}

class LaundryTicketResponse {
  final String id;
  final String studentName;
  final String room;
  final int itemCount;
  final double totalAmount;
  final LaundryStatus status;
  final DateTime submittedAt;
  final DateTime? acceptedAt;
  final DateTime? washedAt;
  final DateTime? receivedAt;

  const LaundryTicketResponse({
    required this.id,
    required this.studentName,
    required this.room,
    required this.itemCount,
    required this.totalAmount,
    required this.status,
    required this.submittedAt,
    this.acceptedAt,
    this.washedAt,
    this.receivedAt,
  });
}
