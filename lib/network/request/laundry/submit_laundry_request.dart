import '../../../common_enums/laundry_status.dart';

class SubmitLaundryTicketRequest {
  final int pants;
  final int pressPants;
  final int shirts;
  final int pressShirts;
  final int tShirts;
  final int pressTShirts;
  final int towels;
  final int pressTowels;
  final int others;
  final int pressOthers;
  final int blanket;
  final int jacket;
  final int bedSheet;
  final String? aadhar;

  const SubmitLaundryTicketRequest({
    this.pants = 0,
    this.pressPants = 0,
    this.shirts = 0,
    this.pressShirts = 0,
    this.tShirts = 0,
    this.pressTShirts = 0,
    this.towels = 0,
    this.pressTowels = 0,
    this.others = 0,
    this.pressOthers = 0,
    this.blanket = 0,
    this.jacket = 0,
    this.bedSheet = 0,
    this.aadhar,
  });

  int get totalItems =>
      pants +
      pressPants +
      shirts +
      pressShirts +
      tShirts +
      pressTShirts +
      towels +
      pressTowels +
      others +
      pressOthers +
      blanket +
      jacket +
      bedSheet;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'pants': pants,
      'pressPants': pressPants,
      'shirts': shirts,
      'pressShirts': pressShirts,
      'tShirts': tShirts,
      'pressTShirts': pressTShirts,
      'towels': towels,
      'pressTowels': pressTowels,
      'others': others,
      'pressOthers': pressOthers,
      'blanket': blanket,
      'jacket': jacket,
      'bedSheet': bedSheet,
    };
    if (aadhar != null && aadhar!.isNotEmpty) {
      map['aadhar'] = aadhar;
    }
    return map;
  }
}

/// Backwards-compatible alias for previous simple count requests
typedef SubmitLaundryRequest = SubmitLaundryTicketRequest;

class UpdateLaundryTicketRequest {
  final LaundryStatus? status;
  final double? washPrice;
  final double? pressPrice;
  final double? blanketPrice;
  final double? jacketPrice;
  final double? bedSheetPrice;

  // Optional item count corrections
  final int? pants;
  final int? pressPants;
  final int? shirts;
  final int? pressShirts;
  final int? tShirts;
  final int? pressTShirts;
  final int? towels;
  final int? pressTowels;
  final int? others;
  final int? pressOthers;
  final int? blanket;
  final int? jacket;
  final int? bedSheet;

  const UpdateLaundryTicketRequest({
    this.status,
    this.washPrice,
    this.pressPrice,
    this.blanketPrice,
    this.jacketPrice,
    this.bedSheetPrice,
    this.pants,
    this.pressPants,
    this.shirts,
    this.pressShirts,
    this.tShirts,
    this.pressTShirts,
    this.towels,
    this.pressTowels,
    this.others,
    this.pressOthers,
    this.blanket,
    this.jacket,
    this.bedSheet,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (status != null) map['status'] = status!.apiValue;
    if (washPrice != null) map['washPrice'] = washPrice;
    if (pressPrice != null) map['pressPrice'] = pressPrice;
    if (blanketPrice != null) map['blanketPrice'] = blanketPrice;
    if (jacketPrice != null) map['jacketPrice'] = jacketPrice;
    if (bedSheetPrice != null) map['bedSheetPrice'] = bedSheetPrice;

    if (pants != null) map['pants'] = pants;
    if (pressPants != null) map['pressPants'] = pressPants;
    if (shirts != null) map['shirts'] = shirts;
    if (pressShirts != null) map['pressShirts'] = pressShirts;
    if (tShirts != null) map['tShirts'] = tShirts;
    if (pressTShirts != null) map['pressTShirts'] = pressTShirts;
    if (towels != null) map['towels'] = towels;
    if (pressTowels != null) map['pressTowels'] = pressTowels;
    if (others != null) map['others'] = others;
    if (pressOthers != null) map['pressOthers'] = pressOthers;
    if (blanket != null) map['blanket'] = blanket;
    if (jacket != null) map['jacket'] = jacket;
    if (bedSheet != null) map['bedSheet'] = bedSheet;

    return map;
  }
}

class LaundryRechargeRequest {
  final String studentAadhar;
  final double amount;

  const LaundryRechargeRequest({
    required this.studentAadhar,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'aadhar': studentAadhar,
        'amount': amount,
      };
}
