import '../../../common_enums/laundry_status.dart';

class LaundryTicketModel {
  final dynamic id;
  final String aadhar;
  final String studentName;
  final String room;

  // Wash Items (count-based)
  final int pants;
  final int shirts;
  final int tShirts;
  final int towels;
  final int others;

  // Press Items (count-based)
  final int pressPants;
  final int pressShirts;
  final int pressTShirts;
  final int pressTowels;
  final int pressOthers;

  // Special Items (count-based)
  final int blanket;
  final int jacket;
  final int bedSheet;

  // Pricing Fields (set by staff on update)
  final double? washPrice;
  final double? pressPrice;
  final double? blanketPrice;
  final double? jacketPrice;
  final double? bedSheetPrice;

  final double totalAmount;
  final LaundryStatus status;

  final DateTime submitTime;
  final DateTime? acceptTime;
  final DateTime? washTime;
  final DateTime? receiveTime;

  const LaundryTicketModel({
    required this.id,
    this.aadhar = '',
    this.studentName = '',
    this.room = '',
    this.pants = 0,
    this.shirts = 0,
    this.tShirts = 0,
    this.towels = 0,
    this.others = 0,
    this.pressPants = 0,
    this.pressShirts = 0,
    this.pressTShirts = 0,
    this.pressTowels = 0,
    this.pressOthers = 0,
    this.blanket = 0,
    this.jacket = 0,
    this.bedSheet = 0,
    this.washPrice,
    this.pressPrice,
    this.blanketPrice,
    this.jacketPrice,
    this.bedSheetPrice,
    this.totalAmount = 0.0,
    required this.status,
    required this.submitTime,
    this.acceptTime,
    this.washTime,
    this.receiveTime,
  });

  int get totalWashItems => pants + shirts + tShirts + towels + others;
  int get totalPressItems =>
      pressPants + pressShirts + pressTShirts + pressTowels + pressOthers;
  int get totalSpecialItems => blanket + jacket + bedSheet;
  int get totalItemsCount =>
      totalWashItems + totalPressItems + totalSpecialItems;

  int get totalWash => totalWashItems;
  int get totalPress => totalPressItems;
  int get totalSpecial => totalSpecialItems;
  int get totalItems => totalItemsCount;
  double get totalPrice => totalAmount;

  // Compatibility getters with previous simple ticket schema
  int get itemCount => totalItemsCount > 0 ? totalItemsCount : 1;
  String get studentAadhar => aadhar;
  DateTime get submittedAt => submitTime;
  DateTime? get acceptedAt => acceptTime;
  DateTime? get washedAt => washTime;
  DateTime? get receivedAt => receiveTime;

  bool get isPending => status == LaundryStatus.pending;
  bool get isAccepted => status == LaundryStatus.accepted;
  bool get isWashed => status == LaundryStatus.washed;
  bool get isReceived => status == LaundryStatus.received;

  factory LaundryTicketModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    double parseDouble(dynamic val, [double def = 0.0]) {
      if (val == null) return def;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? def;
    }

    int parseInt(dynamic val, [int def = 0]) {
      if (val == null) return def;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? def;
    }

    final rawStatus = json['status']?.toString().toLowerCase() ?? 'pending';

    final ticketId = (json['id'] ?? json['_id'] ?? '').toString();
    final aadhar = (json['aadhar'] ??
            json['studentAadhar'] ??
            json['student_aadhar'] ??
            json['student_code'] ??
            json['bank_code'] ??
            json['bankCode'] ??
            (json['student'] is Map ? json['student']['aadhar'] ?? json['student']['student_code'] : null) ??
            '')
        .toString();
    final studentName = (json['studentName'] ??
            json['student_name'] ??
            json['name'] ??
            (json['student'] is Map ? json['student']['name'] : null) ??
            '')
        .toString();
    final room = (json['room'] ??
            json['roomNo'] ??
            json['room_no'] ??
            json['room_number'] ??
            (json['student'] is Map ? json['student']['room'] ?? json['student']['room_number'] : null) ??
            '')
        .toString();

    final Map<String, dynamic> itemSrc =
        (json['items'] is Map<String, dynamic>)
            ? json['items'] as Map<String, dynamic>
            : ((json['garments'] is Map<String, dynamic>)
                ? json['garments'] as Map<String, dynamic>
                : json);

    final Map<String, dynamic> priceSrc =
        (json['pricing'] is Map<String, dynamic>)
            ? json['pricing'] as Map<String, dynamic>
            : ((json['prices'] is Map<String, dynamic>)
                ? json['prices'] as Map<String, dynamic>
                : json);

    return LaundryTicketModel(
      id: ticketId,
      aadhar: aadhar,
      studentName: studentName,
      room: room,
      pants: parseInt(itemSrc['pants']),
      shirts: parseInt(itemSrc['shirts']),
      tShirts: parseInt(itemSrc['tShirts'] ?? itemSrc['t_shirts']),
      towels: parseInt(itemSrc['towels']),
      others: parseInt(itemSrc['others']),
      pressPants: parseInt(itemSrc['pressPants'] ?? itemSrc['press_pants']),
      pressShirts: parseInt(itemSrc['pressShirts'] ?? itemSrc['press_shirts']),
      pressTShirts: parseInt(itemSrc['pressTShirts'] ?? itemSrc['press_t_shirts']),
      pressTowels: parseInt(itemSrc['pressTowels'] ?? itemSrc['press_towels']),
      pressOthers: parseInt(itemSrc['pressOthers'] ?? itemSrc['press_others']),
      blanket: parseInt(itemSrc['blanket']),
      jacket: parseInt(itemSrc['jacket']),
      bedSheet: parseInt(itemSrc['bedSheet'] ?? itemSrc['bed_sheet']),
      washPrice: priceSrc['washPrice'] != null
          ? parseDouble(priceSrc['washPrice'])
          : (priceSrc['wash_price'] != null
              ? parseDouble(priceSrc['wash_price'])
              : null),
      pressPrice: priceSrc['pressPrice'] != null
          ? parseDouble(priceSrc['pressPrice'])
          : (priceSrc['press_price'] != null
              ? parseDouble(priceSrc['press_price'])
              : null),
      blanketPrice: priceSrc['blanketPrice'] != null
          ? parseDouble(priceSrc['blanketPrice'])
          : (priceSrc['blanket_price'] != null
              ? parseDouble(priceSrc['blanket_price'])
              : null),
      jacketPrice: priceSrc['jacketPrice'] != null
          ? parseDouble(priceSrc['jacketPrice'])
          : (priceSrc['jacket_price'] != null
              ? parseDouble(priceSrc['jacket_price'])
              : null),
      bedSheetPrice: priceSrc['bedSheetPrice'] != null
          ? parseDouble(priceSrc['bedSheetPrice'])
          : (priceSrc['bed_sheet_price'] != null
              ? parseDouble(priceSrc['bed_sheet_price'])
              : null),
      totalAmount: parseDouble(
        json['totalAmount'] ??
            json['total_amount'] ??
            json['totalPrice'] ??
            json['total_price'] ??
            json['amount'],
      ),
      status: LaundryStatusX.fromApi(rawStatus),
      submitTime: parseDate(
        json['submitTime'] ??
            json['submit_time'] ??
            json['submittedAt'] ??
            json['submitted_at'] ??
            json['createdAt'] ??
            json['created_at'],
      ),
      acceptTime: parseNullableDate(
        json['acceptTime'] ??
            json['accept_time'] ??
            json['acceptedAt'] ??
            json['accepted_at'],
      ),
      washTime: parseNullableDate(
        json['washTime'] ??
            json['wash_time'] ??
            json['washedAt'] ??
            json['washed_at'],
      ),
      receiveTime: parseNullableDate(
        json['receiveTime'] ??
            json['receive_time'] ??
            json['receivedAt'] ??
            json['received_at'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'aadhar': aadhar,
        'studentName': studentName,
        'room': room,
        'pants': pants,
        'shirts': shirts,
        'tShirts': tShirts,
        'towels': towels,
        'others': others,
        'pressPants': pressPants,
        'pressShirts': pressShirts,
        'pressTShirts': pressTShirts,
        'pressTowels': pressTowels,
        'pressOthers': pressOthers,
        'blanket': blanket,
        'jacket': jacket,
        'bedSheet': bedSheet,
        'washPrice': washPrice,
        'pressPrice': pressPrice,
        'blanketPrice': blanketPrice,
        'jacketPrice': jacketPrice,
        'bedSheetPrice': bedSheetPrice,
        'totalAmount': totalAmount,
        'status': status.apiValue,
        'submitTime': submitTime.toIso8601String(),
        'acceptTime': acceptTime?.toIso8601String(),
        'washTime': washTime?.toIso8601String(),
        'receiveTime': receiveTime?.toIso8601String(),
      };
}
