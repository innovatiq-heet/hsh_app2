import 'package:flutter/material.dart';

class GeofencePolicyModel {
  final String id;
  final String name;
  final TimeOfDay startTime; // e.g. 22:00 (10:00 PM)
  final TimeOfDay endTime;   // e.g. 06:00 (06:00 AM)
  final bool isActive;
  final bool enforcePhoneLock;
  final int checkIntervalMinutes;
  final List<String> repeatDays; // ['Mon', 'Tue', 'Wed', ...] or ['Daily']

  const GeofencePolicyModel({
    this.id = 'default_curfew',
    this.name = 'Hostel Night Curfew',
    this.startTime = const TimeOfDay(hour: 22, minute: 0),
    this.endTime = const TimeOfDay(hour: 6, minute: 0),
    this.isActive = true,
    this.enforcePhoneLock = false,
    this.checkIntervalMinutes = 10,
    this.repeatDays = const ['Daily'],
  });

  /// Checks if a given [DateTime] falls inside the curfew restriction interval.
  /// Handles overnight intervals (e.g., 22:00 to 06:00) accurately.
  bool isWithinCurfew(DateTime dateTime) {
    if (!isActive) return false;

    final currentMins = dateTime.hour * 60 + dateTime.minute;
    final startMins = startTime.hour * 60 + startTime.minute;
    final endMins = endTime.hour * 60 + endTime.minute;

    if (startMins <= endMins) {
      // Normal same-day interval (e.g. 14:00 to 18:00)
      return currentMins >= startMins && currentMins < endMins;
    } else {
      // Overnight interval across midnight (e.g. 22:00 to 06:00)
      return currentMins >= startMins || currentMins < endMins;
    }
  }

  String formatTimeRange() {
    final startStr = _formatTimeOfDay(startTime);
    final endStr = _formatTimeOfDay(endTime);
    return '$startStr - $endStr';
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  GeofencePolicyModel copyWith({
    String? id,
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isActive,
    bool? enforcePhoneLock,
    int? checkIntervalMinutes,
    List<String>? repeatDays,
  }) {
    return GeofencePolicyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      enforcePhoneLock: enforcePhoneLock ?? this.enforcePhoneLock,
      checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
      repeatDays: repeatDays ?? this.repeatDays,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'isActive': isActive,
      'enforcePhoneLock': enforcePhoneLock,
      'checkIntervalMinutes': checkIntervalMinutes,
      'repeatDays': repeatDays,
    };
  }

  factory GeofencePolicyModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String? str, TimeOfDay fallback) {
      if (str == null || !str.contains(':')) return fallback;
      final parts = str.split(':');
      final h = int.tryParse(parts[0]) ?? fallback.hour;
      final m = int.tryParse(parts[1]) ?? fallback.minute;
      return TimeOfDay(hour: h, minute: m);
    }

    return GeofencePolicyModel(
      id: (json['id'] ?? 'default_curfew').toString(),
      name: (json['name'] ?? 'Hostel Night Curfew').toString(),
      startTime: parseTime(json['startTime']?.toString() ?? json['start_time']?.toString(), const TimeOfDay(hour: 22, minute: 0)),
      endTime: parseTime(json['endTime']?.toString() ?? json['end_time']?.toString(), const TimeOfDay(hour: 6, minute: 0)),
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      enforcePhoneLock: json['enforcePhoneLock'] ?? json['enforce_phone_lock'] ?? false,
      checkIntervalMinutes: (json['checkIntervalMinutes'] ?? json['check_interval_minutes'] as int?) ?? 10,
      repeatDays: (json['repeatDays'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['Daily'],
    );
  }
}
