import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'phone_number_normalizer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/phonebook_models.dart';
import 'phonebook_database_service.dart';

class PhonebookSyncService {
  static final PhonebookSyncService instance = PhonebookSyncService._internal();
  PhonebookSyncService._internal();

  static const String liveApiUrl =
      'https://api.avdvvn.org/public/getStudentBasicDetails';
  static const String liveAuthToken = 'aF92Kx7QmN4Lp8Vz';

  final _storage = const FlutterSecureStorage();
  static const _kLastSync = 'phonebook_last_sync';
  static const _kCachedCount = 'phonebook_cached_count';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );

  Future<DateTime?> getLastSyncTime() async {
    final raw = await _storage.read(key: _kLastSync);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<int> getCachedStudentCount() async {
    final raw = await _storage.read(key: _kCachedCount);
    if (raw == null) {
      return await PhonebookDatabaseService.instance.getStudentCount();
    }
    return int.tryParse(raw) ?? 0;
  }

  /// Pulls all student contact records from live AVD VVN directory and updates SQLite cache
  Future<PhonebookSyncResult> syncDirectory({bool force = false}) async {
    try {
      final response = await _dio.get(
        liveApiUrl,
        options: Options(
          headers: {'x-hsh-auth-token': liveAuthToken},
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode != 200) {
        return PhonebookSyncResult(
          success: false,
          totalStudents: 0,
          totalPhones: 0,
          errorMessage: 'Server responded with code ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.data.toString());
      final List rawList =
          decoded is List ? decoded : (decoded['data'] as List? ?? []);

      final records = <Map<String, dynamic>>[];
      final uniqueStudents = <String>{};
      final nowIso = DateTime.now().toIso8601String();

      for (int i = 0; i < rawList.length; i++) {
        final s = rawList[i];
        if (s is! Map) continue;

        final rawFirst = (s['firstName'] ?? s['first_name'] ?? '').toString().trim();
        final rawMiddle = (s['middleName'] ?? s['middle_name'] ?? s['fatherName'] ?? s['father_name'] ?? '').toString().trim();
        final rawLast = (s['lastName'] ?? s['last_name'] ?? s['surname'] ?? '').toString().trim();
        final rawFull = (s['name'] ?? s['fullName'] ?? '').toString().trim();

        final nameParts = [rawFirst, rawMiddle, rawLast]
            .where((p) => p.isNotEmpty)
            .toList();

        String fullName;
        if (nameParts.length >= 3) {
          fullName = nameParts.join(' ');
        } else if (rawFull.isNotEmpty && rawFull.split(RegExp(r'\s+')).length >= 3) {
          fullName = rawFull;
        } else if (nameParts.isNotEmpty) {
          fullName = nameParts.join(' ');
        } else if (rawFull.isNotEmpty) {
          fullName = rawFull;
        } else {
          fullName = 'Unknown Student';
        }

        final bankCode = s['bankCode']?.toString().trim();
        final aadhar = s['aadhar']?.toString().trim();
        final rawRoom = s['room']?.toString().trim();
        final group = s['groupName']?.toString().trim();
        final status = s['status']?.toString().toLowerCase().trim() ?? '';

        final isRoomNa = rawRoom == null ||
            rawRoom.isEmpty ||
            rawRoom.toLowerCase() == 'n/a' ||
            rawRoom.toLowerCase() == 'none' ||
            rawRoom.toLowerCase() == 'null';
        final isAlumni = isRoomNa ||
            status.contains('alumni') ||
            status.contains('left') ||
            status.contains('former') ||
            status.contains('pass');

        final room = isRoomNa ? null : rawRoom;

        final studentCode = (bankCode != null && bankCode.isNotEmpty)
            ? 'HSH-$bankCode'
            : (aadhar != null && aadhar.length >= 4
                ? 'HSH-${aadhar.substring(aadhar.length - 4)}'
                : 'HSH-${i + 1}');

        final enrollment = (bankCode != null && bankCode.isNotEmpty)
            ? bankCode
            : (room != null
                ? 'Room $room'
                : (isAlumni
                    ? 'Alumni'
                    : (aadhar != null && aadhar.length >= 6
                        ? aadhar.substring(aadhar.length - 6)
                        : 'AVD-${i + 1}')));

        String dept;
        String? cleanGroup;
        if (group != null &&
            group.isNotEmpty &&
            group.toLowerCase() != 'not available') {
          final lowerGroup = group.toLowerCase().trim();
          if (lowerGroup == 'param') {
            cleanGroup = 'Param';
          } else if (lowerGroup == 'pavitra') {
            cleanGroup = 'Pavitra';
          } else if (lowerGroup == 'pulkit') {
            cleanGroup = 'Pulkit';
          } else if (lowerGroup == 'paramanand' || lowerGroup == 'parmanand') {
            cleanGroup = 'Paramanand';
          } else {
            cleanGroup = group[0].toUpperCase() + group.substring(1);
          }
        }

        if (isAlumni) {
          dept = cleanGroup != null ? '$cleanGroup • Alumni' : 'Alumni';
        } else if (cleanGroup != null) {
          dept = room != null ? '$cleanGroup • Room $room' : cleanGroup;
        } else if (room != null) {
          dept = 'Room $room';
        } else {
          dept = 'Alumni';
        }

        final batch = isAlumni
            ? 'ALUMNI'
            : (s['status']?.toString().replaceAll('-', ' ').toUpperCase() ?? 'ACTIVE');
        final email = s['email']?.toString();
        uniqueStudents.add(studentCode);

        // 1. Student Personal Mobile
        final phone = s['phone']?.toString().trim();
        if (phone != null && phone.isNotEmpty) {
          records.add({
            'internal_id': 'stu_${i + 1}',
            'student_id': studentCode,
            'name': fullName,
            'enrollment_number': enrollment,
            'department': dept,
            'batch': batch,
            'email': email,
            'phone_raw': phone,
            'phone': PhoneNumberNormalizer.normalize(phone) ?? phone,
            'is_primary': 1,
            'phone_label': 'Student Mobile',
            'updated_at': nowIso,
          });
        }

        // 2. Father Phone
        final fatherPhone = s['fatherPhone']?.toString().trim();
        if (fatherPhone != null &&
            fatherPhone.isNotEmpty &&
            fatherPhone != phone) {
          final fatherLabel = (rawMiddle.isNotEmpty)
              ? 'Father ($rawMiddle)'
              : 'Father Contact';
          records.add({
            'internal_id': 'stu_${i + 1}',
            'student_id': studentCode,
            'name': fullName,
            'enrollment_number': enrollment,
            'department': dept,
            'batch': batch,
            'email': email,
            'phone_raw': fatherPhone,
            'phone': PhoneNumberNormalizer.normalize(fatherPhone) ?? fatherPhone,
            'is_primary': 0,
            'phone_label': fatherLabel,
            'updated_at': nowIso,
          });
        }

        // 3. Mother Phone
        final motherPhone = s['motherPhone']?.toString().trim();
        if (motherPhone != null &&
            motherPhone.isNotEmpty &&
            motherPhone != phone &&
            motherPhone != fatherPhone) {
          records.add({
            'internal_id': 'stu_${i + 1}',
            'student_id': studentCode,
            'name': fullName,
            'enrollment_number': enrollment,
            'department': dept,
            'batch': batch,
            'email': email,
            'phone_raw': motherPhone,
            'phone': PhoneNumberNormalizer.normalize(motherPhone) ?? motherPhone,
            'is_primary': 0,
            'phone_label': 'Mother Contact',
            'updated_at': nowIso,
          });
        }

        // 4. WhatsApp Number (if distinct)
        final whatsApp = s['whatsAppNumber']?.toString().trim();
        if (whatsApp != null &&
            whatsApp.isNotEmpty &&
            whatsApp != phone &&
            whatsApp != fatherPhone &&
            whatsApp != motherPhone) {
          records.add({
            'internal_id': 'stu_${i + 1}',
            'student_id': studentCode,
            'name': fullName,
            'enrollment_number': enrollment,
            'department': dept,
            'batch': batch,
            'email': email,
            'phone_raw': whatsApp,
            'phone': PhoneNumberNormalizer.normalize(whatsApp) ?? whatsApp,
            'is_primary': 0,
            'phone_label': 'WhatsApp',
            'updated_at': nowIso,
          });
        }
      }

      // Sync into SQLite
      final totalPhones = await PhonebookDatabaseService.instance.syncRecords(
        records,
        fullReplace: true,
      );

      final studentCount = uniqueStudents.length;

      await _storage.write(key: _kLastSync, value: nowIso);
      await _storage.write(key: _kCachedCount, value: studentCount.toString());

      return PhonebookSyncResult(
        success: true,
        totalStudents: studentCount,
        totalPhones: totalPhones,
        syncTime: DateTime.now(),
      );
    } catch (e) {
      developer.log('Phonebook sync error: $e', name: 'PhonebookSyncService');
      return PhonebookSyncResult(
        success: false,
        totalStudents: 0,
        totalPhones: 0,
        errorMessage: e.toString(),
      );
    }
  }
}
