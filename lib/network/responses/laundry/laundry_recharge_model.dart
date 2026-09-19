class LaundryRechargeModel {
  final dynamic id;
  final String aadhar;
  final double amount;
  final DateTime time;

  const LaundryRechargeModel({
    required this.id,
    required this.aadhar,
    required this.amount,
    required this.time,
  });

  factory LaundryRechargeModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    double parseDouble(dynamic val, [double def = 0.0]) {
      if (val == null) return def;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? def;
    }

    return LaundryRechargeModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      aadhar: (json['aadhar'] ?? json['studentAadhar'] ?? json['student_aadhar'] ?? '').toString(),
      amount: parseDouble(json['amount'] ?? json['rechargeAmount'] ?? json['recharge_amount']),
      time: parseDate(
        json['time'] ??
            json['createdAt'] ??
            json['created_at'] ??
            json['date'] ??
            json['timestamp'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'aadhar': aadhar,
        'amount': amount,
        'time': time.toIso8601String(),
      };
}
