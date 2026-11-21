/// One WhatsApp number the server keeps connected (`GET /whatsapp/accounts`).
class WhatsAppAccount {
  /// The number that existed before multi-number support. Cannot be deleted.
  static const mainId = 'default';

  final String id;
  final String label;

  /// `disconnected` | `connecting` | `qr` | `pairing` | `open`. Only `open` can send.
  final String status;

  /// Text to draw as a QR code, only while [status] is `qr`.
  final String? qr;
  final bool isRegistered;

  /// Linked phone (digits with country code); null until fully linked.
  final String? phone;
  final String? profileName;

  const WhatsAppAccount({
    required this.id,
    required this.label,
    required this.status,
    this.qr,
    this.isRegistered = false,
    this.phone,
    this.profileName,
  });

  bool get isOpen => status == 'open';
  bool get isMain => id == mainId;

  /// Still working towards being linked or connected: worth polling.
  bool get isBusy => status == 'connecting' || status == 'qr' || status == 'pairing';

  String get statusLabel => switch (status) {
    'open' => 'Connected',
    'connecting' => 'Connecting…',
    'qr' => 'Waiting for QR scan',
    'pairing' => 'Waiting for pairing code',
    _ => 'Not connected',
  };

  factory WhatsAppAccount.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['accountId'] ?? mainId).toString();
    final user = json['user'];
    final qr = json['qr']?.toString();
    final label = (json['label'] ?? '').toString().trim();
    return WhatsAppAccount(
      id: id,
      label: label.isNotEmpty ? label : (id == mainId ? 'Main' : id),
      status: (json['status'] ?? 'disconnected').toString(),
      qr: qr == null || qr.isEmpty ? null : qr,
      isRegistered: json['isRegistered'] == true,
      phone: user is Map && user['phone'] != null ? user['phone'].toString() : null,
      profileName: user is Map && user['name'] != null ? user['name'].toString() : null,
    );
  }
}

/// Accounts plus which one the scheduled daily runs send from.
class WhatsAppAccountsData {
  final List<WhatsAppAccount> accounts;

  /// Account id for the scheduled birthday / anniversary run; null means Main.
  final String? birthdayDefault;
  final String? anniversaryDefault;

  const WhatsAppAccountsData({
    this.accounts = const [],
    this.birthdayDefault,
    this.anniversaryDefault,
  });

  factory WhatsAppAccountsData.fromJson(Map<String, dynamic> json) {
    final list = json['accounts'];
    final defaults = json['defaults'];
    String? pick(String key) {
      if (defaults is! Map) return null;
      final v = defaults[key]?.toString();
      return v == null || v.isEmpty ? null : v;
    }

    return WhatsAppAccountsData(
      accounts: list is List
          ? [for (final a in list) if (a is Map) WhatsAppAccount.fromJson(Map<String, dynamic>.from(a))]
          : const [],
      birthdayDefault: pick('birthday'),
      anniversaryDefault: pick('anniversary'),
    );
  }

  WhatsAppAccount? byId(String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The account a scheduled run of [purpose] (`birthday` / `anniversary`) uses.
  WhatsAppAccount? defaultFor(String purpose) {
    final id = purpose == 'anniversary' ? anniversaryDefault : birthdayDefault;
    return byId(id) ?? byId(WhatsAppAccount.mainId);
  }
}
