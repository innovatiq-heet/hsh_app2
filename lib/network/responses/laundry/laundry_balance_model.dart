class LaundryBalanceModel {
  final String aadhar;
  final double totalRecharges;
  final double totalSpend;
  final double balance;

  const LaundryBalanceModel({
    this.aadhar = '',
    this.totalRecharges = 0.0,
    this.totalSpend = 0.0,
    this.balance = 0.0,
  });

  String get studentAadhar => aadhar;

  factory LaundryBalanceModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, [double def = 0.0]) {
      if (val == null) return def;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? def;
    }

    return LaundryBalanceModel(
      aadhar: json['aadhar']?.toString() ??
          json['studentAadhar']?.toString() ??
          json['student_code']?.toString() ??
          json['bank_code']?.toString() ??
          json['bankCode']?.toString() ??
          '',
      totalRecharges: parseDouble(
        json['totalRecharges'] ?? json['total_recharges'] ?? json['total_recharged'],
      ),
      totalSpend: parseDouble(json['totalSpend'] ?? json['total_spend'] ?? json['total_spent']),
      balance: parseDouble(json['balance'] ?? json['current_balance']),
    );
  }

  Map<String, dynamic> toJson() => {
        'aadhar': aadhar,
        'totalRecharges': totalRecharges,
        'totalSpend': totalSpend,
        'balance': balance,
      };
}
