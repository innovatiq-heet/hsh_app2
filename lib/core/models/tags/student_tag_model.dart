import 'package:flutter/material.dart';

/// Represents a student tag defined in the backend (`student_tags`).
class StudentTag {
  final int id;
  final String name;
  final String colorHex;
  final bool isSystem;
  final String? description;
  final int studentCount;
  final DateTime? assignedAt;

  const StudentTag({
    required this.id,
    required this.name,
    this.colorHex = '#6366f1',
    this.isSystem = false,
    this.description,
    this.studentCount = 0,
    this.assignedAt,
  });

  static Color parseHexColor(String? hexString, {Color defaultColor = const Color(0xFF6366F1)}) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    String hex = hexString.replaceAll('#', '').trim();
    if (hex.length == 6) {
      hex = 'FF$hex';
    } else if (hex.length == 8) {
      // already has alpha
    } else {
      return defaultColor;
    }
    final val = int.tryParse(hex, radix: 16);
    if (val == null) return defaultColor;
    return Color(val);
  }

  Color get color => parseHexColor(colorHex);

  Color get displayColor => color;

  Color get backgroundColor => color.withValues(alpha: 0.12);

  Color get borderColor => color.withValues(alpha: 0.35);

  factory StudentTag.fromJson(Map<String, dynamic> json) {
    DateTime? assigned;
    if (json['assigned_at'] != null) {
      assigned = DateTime.tryParse(json['assigned_at'].toString());
    }

    return StudentTag(
      id: int.tryParse(json['id']?.toString() ?? json['tag_id']?.toString() ?? '0') ?? 0,
      name: (json['name'] ?? json['tag_name'] ?? '').toString().trim(),
      colorHex: (json['color'] ?? json['tag_color'] ?? '#6366f1').toString().trim(),
      isSystem: json['is_system'] == true || json['is_system'] == 1 || json['type'] == 'SYSTEM',
      description: json['description']?.toString(),
      studentCount: int.tryParse(json['student_count']?.toString() ?? '0') ?? 0,
      assignedAt: assigned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': colorHex,
      'is_system': isSystem ? 1 : 0,
      'description': description,
      'student_count': studentCount,
      if (assignedAt != null) 'assigned_at': assignedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentTag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
