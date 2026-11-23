/// Where an alumnus lives and works now, noted by admins
/// (`GET/PUT /alumni/admin/students/:id/current-details`).
class AlumniCurrentDetails {
  final String? city;
  final String? company;

  /// Job role / designation.
  final String? role;
  final String? address;
  final DateTime? updatedAt;
  final String? updatedBy;

  const AlumniCurrentDetails({
    this.city,
    this.company,
    this.role,
    this.address,
    this.updatedAt,
    this.updatedBy,
  });

  static const empty = AlumniCurrentDetails();

  bool get isEmpty => city == null && company == null && role == null && address == null;

  static String? _text(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty || s == 'null' ? null : s;
  }

  factory AlumniCurrentDetails.fromJson(Map<String, dynamic> json) => AlumniCurrentDetails(
        city: _text(json['current_city'] ?? json['currentCity']),
        company: _text(json['current_company'] ?? json['currentCompany']),
        role: _text(json['current_designation'] ?? json['currentDesignation']),
        address: _text(json['current_address'] ?? json['currentAddress']),
        updatedAt: DateTime.tryParse('${json['details_updated_at'] ?? json['detailsUpdatedAt'] ?? ''}')?.toLocal(),
        updatedBy: _text(json['details_updated_by'] ?? json['detailsUpdatedBy']),
      );

  /// Only the fields that differ from [before]; a cleared field is sent as "".
  static Map<String, String> changes(AlumniCurrentDetails before, AlumniCurrentDetails after) {
    final out = <String, String>{};
    void put(String key, String? was, String? now) {
      if ((was ?? '') != (now ?? '')) out[key] = now ?? '';
    }

    put('current_city', before.city, after.city);
    put('current_company', before.company, after.company);
    put('current_designation', before.role, after.role);
    put('current_address', before.address, after.address);
    return out;
  }
}
