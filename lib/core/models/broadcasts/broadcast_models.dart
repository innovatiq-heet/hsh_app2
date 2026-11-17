import '../students/pickable_student.dart';
import '../tags/student_tag_model.dart';

export '../students/pickable_student.dart';

/// Models for Broadcast messages (`/broadcasts`, `/me/broadcasts`).
/// See docs/BROADCAST_DOCS.md for the API contract.

int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toUtc();

String _str(dynamic v) => v?.toString() ?? '';

enum BroadcastStatus { sending, sent, failed, unknown }

BroadcastStatus _status(dynamic v) {
  switch (v?.toString().toLowerCase()) {
    case 'sending':
      return BroadcastStatus.sending;
    case 'sent':
      return BroadcastStatus.sent;
    case 'failed':
      return BroadcastStatus.failed;
    default:
      return BroadcastStatus.unknown;
  }
}

enum PushStatus { pending, sent, failed, noDevice, unknown }

PushStatus _pushStatus(dynamic v) {
  switch (v?.toString().toLowerCase()) {
    case 'pending':
      return PushStatus.pending;
    case 'sent':
      return PushStatus.sent;
    case 'failed':
      return PushStatus.failed;
    case 'no_device':
      return PushStatus.noDevice;
    default:
      return PushStatus.unknown;
  }
}

enum BroadcastChannel { both, app, whatsapp }

BroadcastChannel _channel(dynamic v) {
  switch (v?.toString().toLowerCase()) {
    case 'app':
      return BroadcastChannel.app;
    case 'whatsapp':
      return BroadcastChannel.whatsapp;
    default:
      return BroadcastChannel.both;
  }
}

extension BroadcastChannelExt on BroadcastChannel {
  String get displayLabel {
    switch (this) {
      case BroadcastChannel.both:
        return 'Both (App & WhatsApp)';
      case BroadcastChannel.app:
        return 'In-App Only';
      case BroadcastChannel.whatsapp:
        return 'WhatsApp Only';
    }
  }
}

enum WhatsAppStatus { pending, queued, sent, failed, skipped, noPhone, unknown }

WhatsAppStatus _whatsAppStatus(dynamic v) {
  switch (v?.toString().toLowerCase()) {
    case 'pending':
      return WhatsAppStatus.pending;
    case 'queued':
      return WhatsAppStatus.queued;
    case 'sent':
      return WhatsAppStatus.sent;
    case 'failed':
      return WhatsAppStatus.failed;
    case 'skipped':
      return WhatsAppStatus.skipped;
    case 'no_phone':
      return WhatsAppStatus.noPhone;
    default:
      return WhatsAppStatus.unknown;
  }
}

/// A student picked individually for a broadcast.
typedef BroadcastStudent = PickableStudent;

/// Result of `POST /broadcasts/preview`.
class BroadcastPreview {
  final int recipientCount;
  final int noDeviceCount;
  final int noWhatsappCount;
  final bool isWhatsAppConnected;
  final List<BroadcastStudent> sample;

  const BroadcastPreview({
    required this.recipientCount,
    this.noDeviceCount = 0,
    this.noWhatsappCount = 0,
    this.isWhatsAppConnected = false,
    this.sample = const [],
  });

  static const empty = BroadcastPreview(recipientCount: 0);

  factory BroadcastPreview.fromJson(Map<String, dynamic> json) {
    final sample = <BroadcastStudent>[];
    if (json['sample'] is List) {
      for (final s in (json['sample'] as List).whereType<Map>()) {
        sample.add(BroadcastStudent(
          id: _int(s['id']),
          name: _str(s['name']),
          room: _str(s['room']),
        ));
      }
    }
    return BroadcastPreview(
      recipientCount: _int(json['recipient_count']),
      noDeviceCount: _int(json['no_device_count']),
      noWhatsappCount: _int(json['no_whatsapp_count']),
      isWhatsAppConnected: json['whatsapp_connected'] == true,
      sample: sample,
    );
  }
}

/// One recipient row of `GET /broadcasts/:id`.
class BroadcastRecipient {
  final int studentId;
  final String name;
  final String room;
  final String matchedBy;
  final PushStatus pushStatus;
  final WhatsAppStatus whatsAppStatus;
  final String whatsappPhone;
  final DateTime? whatsappSentAt;
  final DateTime? readAt;

  const BroadcastRecipient({
    required this.studentId,
    required this.name,
    required this.room,
    required this.matchedBy,
    required this.pushStatus,
    this.whatsAppStatus = WhatsAppStatus.unknown,
    this.whatsappPhone = '',
    this.whatsappSentAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory BroadcastRecipient.fromJson(Map<String, dynamic> json) => BroadcastRecipient(
        studentId: _int(json['student_id']),
        name: _str(json['name']),
        room: _str(json['room']),
        matchedBy: _str(json['matched_by']),
        pushStatus: _pushStatus(json['push_status']),
        whatsAppStatus: _whatsAppStatus(json['whatsapp_status']),
        whatsappPhone: _str(json['whatsapp_phone']),
        whatsappSentAt: _date(json['whatsapp_sent_at']),
        readAt: _date(json['read_at']),
      );
}

/// A sent broadcast, as the admin sees it.
class Broadcast {
  final int id;
  final String? title;
  final String message;
  final BroadcastChannel channels;
  final List<StudentTag> tags;
  final List<int> studentIds;
  final BroadcastStatus status;
  final int recipientCount;
  final int pushSent;
  final int pushFailed;
  final int noDevice;
  final int whatsappSent;
  final int whatsappFailed;
  final int noWhatsapp;
  final int readCount;
  final String senderName;
  final DateTime? createdAt;
  final DateTime? completedAt;

  /// Only filled by `GET /broadcasts/:id`.
  final List<BroadcastRecipient> recipients;

  const Broadcast({
    required this.id,
    this.title,
    required this.message,
    this.channels = BroadcastChannel.both,
    this.tags = const [],
    this.studentIds = const [],
    this.status = BroadcastStatus.unknown,
    this.recipientCount = 0,
    this.pushSent = 0,
    this.pushFailed = 0,
    this.noDevice = 0,
    this.whatsappSent = 0,
    this.whatsappFailed = 0,
    this.noWhatsapp = 0,
    this.readCount = 0,
    this.senderName = '',
    this.createdAt,
    this.completedAt,
    this.recipients = const [],
  });

  bool get isSending => status == BroadcastStatus.sending;
  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty) ? title!.trim() : 'Announcement';

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    final tags = <StudentTag>[];
    if (json['tags'] is List) {
      for (final t in (json['tags'] as List).whereType<Map>()) {
        tags.add(StudentTag.fromJson(Map<String, dynamic>.from(t)));
      }
    }
    final ids = <int>[];
    if (json['student_ids'] is List) {
      for (final v in json['student_ids'] as List) {
        final id = _int(v);
        if (id > 0) ids.add(id);
      }
    }
    final recipients = <BroadcastRecipient>[];
    if (json['recipients'] is List) {
      for (final r in (json['recipients'] as List).whereType<Map>()) {
        recipients.add(BroadcastRecipient.fromJson(Map<String, dynamic>.from(r)));
      }
    }
    final sender = json['sender'];
    final rawTitle = json['title']?.toString();
    return Broadcast(
      id: _int(json['id']),
      title: (rawTitle != null && rawTitle.trim().isNotEmpty) ? rawTitle.trim() : null,
      message: _str(json['message']),
      channels: _channel(json['channels']),
      tags: tags,
      studentIds: ids,
      status: _status(json['status']),
      recipientCount: _int(json['recipient_count']),
      pushSent: _int(json['push_sent']),
      pushFailed: _int(json['push_failed']),
      noDevice: _int(json['no_device']),
      whatsappSent: _int(json['whatsapp_sent']),
      whatsappFailed: _int(json['whatsapp_failed']),
      noWhatsapp: _int(json['no_whatsapp']),
      readCount: _int(json['read_count']),
      senderName: sender is Map ? _str(sender['name']) : '',
      createdAt: _date(json['created_at']),
      completedAt: _date(json['completed_at']),
      recipients: recipients,
    );
  }
}

/// A page of broadcasts with the server's total.
class BroadcastPage {
  final List<Broadcast> items;
  final int total;

  const BroadcastPage(this.items, this.total);
}

/// One message in a student's inbox.
class InboxBroadcast {
  final int id;
  final String? title;
  final String message;
  final String senderName;
  final DateTime? createdAt;
  final DateTime? readAt;

  const InboxBroadcast({
    required this.id,
    this.title,
    required this.message,
    this.senderName = '',
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;
  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty)
          ? title!.trim()
          : (senderName.isNotEmpty ? 'Notice from $senderName' : 'Notice');

  InboxBroadcast copyWith({DateTime? readAt, bool clearRead = false}) => InboxBroadcast(
        id: id,
        title: title,
        message: message,
        senderName: senderName,
        createdAt: createdAt,
        readAt: clearRead ? null : (readAt ?? this.readAt),
      );

  factory InboxBroadcast.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString();
    return InboxBroadcast(
      id: _int(json['id']),
      title: (rawTitle != null && rawTitle.trim().isNotEmpty) ? rawTitle.trim() : null,
      message: _str(json['message']),
      senderName: _str(json['sender_name']),
      createdAt: _date(json['created_at']),
      readAt: _date(json['read_at']),
    );
  }
}

/// A page of the inbox with the server's totals.
class InboxPage {
  final List<InboxBroadcast> items;
  final int total;
  final int unreadCount;

  const InboxPage(this.items, this.total, this.unreadCount);
}
