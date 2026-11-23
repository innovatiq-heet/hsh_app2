import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/utils/apple_search_utils.dart';
import '../../../core/utils/string_formatting.dart';
import '../models/phonebook_models.dart';
import 'phone_number_normalizer.dart';

typedef PhonebookGroupInfo = ({String? group, String? status});
typedef PhonebookLocationOption = ({String name, int count});

class PhonebookDatabaseService {
  static final PhonebookDatabaseService instance =
      PhonebookDatabaseService._internal();
  PhonebookDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'student_phonebook_cache.db');

    return await openDatabase(
      path,
      version: 8,
      onUpgrade: _onUpgrade,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE student_cache (
            id TEXT PRIMARY KEY,
            student_id TEXT NOT NULL,
            name TEXT NOT NULL,
            enrollment_number TEXT NOT NULL,
            department TEXT NOT NULL,
            batch TEXT NOT NULL,
            email TEXT,
            phone TEXT NOT NULL,
            phone_normalized TEXT NOT NULL,
            is_primary INTEGER DEFAULT 1,
            phone_label TEXT DEFAULT 'Mobile',
            updated_at TEXT,
            dob TEXT,
            aadhar TEXT,
            address TEXT,
            pin_code TEXT,
            father_name TEXT,
            mother_name TEXT,
            father_phone TEXT,
            mother_phone TEXT,
            father_dob TEXT,
            father_business TEXT,
            mother_dob TEXT,
            mother_business TEXT,
            anniversary TEXT,
            course TEXT,
            semester TEXT,
            study_institute TEXT,
            city TEXT,
            district TEXT,
            state TEXT,
            whatsapp_number TEXT,
            status TEXT,
            bank_code TEXT,
            room_num TEXT,
            group_name TEXT,
            floor_num INTEGER,
            tags TEXT
          )
        ''');

        await db.execute('CREATE INDEX idx_phone ON student_cache (phone)');
        await db.execute('CREATE INDEX idx_phone_norm ON student_cache (phone_normalized)');
        await db.execute('CREATE INDEX idx_student_name ON student_cache (name)');
        await db.execute('CREATE INDEX idx_student_id ON student_cache (student_id)');
        await db.execute('CREATE INDEX idx_room ON student_cache (room_num)');
        await db.execute('CREATE INDEX idx_group ON student_cache (group_name)');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final rows = await db.query('student_cache', columns: ['id', 'phone', 'phone_normalized']);
      final batch = db.batch();
      for (final r in rows) {
        final n = PhoneNumberNormalizer.normalize(r['phone']?.toString() ?? r['phone_normalized']?.toString());
        if (n != null && n != r['phone_normalized']) {
          batch.update('student_cache', {'phone_normalized': n}, where: 'id = ?', whereArgs: [r['id']]);
        }
      }
      await batch.commit(noResult: true);
    }

    if (oldVersion < 3) {
      final newCols = [
        'dob TEXT',
        'aadhar TEXT',
        'address TEXT',
        'pin_code TEXT',
        'father_name TEXT',
        'father_phone TEXT',
        'mother_phone TEXT',
        'whatsapp_number TEXT',
        'status TEXT',
        'bank_code TEXT',
        'room_num TEXT',
        'group_name TEXT',
        'floor_num INTEGER'
      ];
      for (final col in newCols) {
        try {
          await db.execute('ALTER TABLE student_cache ADD COLUMN $col');
        } catch (_) {}
      }
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_room ON student_cache (room_num)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_group ON student_cache (group_name)'); } catch (_) {}
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE student_cache ADD COLUMN mother_name TEXT');
      } catch (_) {}
    }

    if (oldVersion < 5) {
      // Floors were derived from the room's first digit, which left the ground
      // floor (rooms 1–18) with no floor. Recompute them from the room.
      final rows = await db.query('student_cache', columns: ['id', 'room_num', 'floor_num']);
      final batch = db.batch();
      for (final r in rows) {
        final floor = PhonebookStudent.floorOfRoom(r['room_num']?.toString());
        if (floor != r['floor_num']) {
          batch.update('student_cache', {'floor_num': floor}, where: 'id = ?', whereArgs: [r['id']]);
        }
      }
      await batch.commit(noResult: true);
    }

    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE student_cache ADD COLUMN tags TEXT');
      } catch (_) {}
    }

    if (oldVersion < 7) {
      final newCols = [
        'father_dob TEXT',
        'father_business TEXT',
        'mother_dob TEXT',
        'mother_business TEXT',
        'anniversary TEXT',
        'city TEXT',
        'district TEXT',
        'state TEXT',
      ];
      for (final col in newCols) {
        try {
          await db.execute('ALTER TABLE student_cache ADD COLUMN $col');
        } catch (_) {}
      }
    }

    if (oldVersion < 8) {
      // Education (Education details card): branch, semester and college.
      for (final col in ['course TEXT', 'semester TEXT', 'study_institute TEXT']) {
        try {
          await db.execute('ALTER TABLE student_cache ADD COLUMN $col');
        } catch (_) {}
      }
    }
  }

  /// Everything caller ID needs, one row per phone number.
  Future<List<Map<String, dynamic>>> callerIdRows() async {
    final db = await database;
    return db.query(
      'student_cache',
      columns: ['student_id', 'name', 'department', 'phone', 'phone_normalized', 'phone_label'],
    );
  }

  /// Bulk syncs records into local cache within a transaction
  Future<int> syncRecords(
    List<Map<String, dynamic>> rawRecords, {
    bool fullReplace = false,
  }) async {
    final db = await database;
    int count = 0;

    await db.transaction((txn) async {
      if (fullReplace) {
        await txn.delete('student_cache');
      }

      final batch = txn.batch();
      for (final r in rawRecords) {
        final cacheId =
            '${r['student_id']}_${r['phone'] ?? r['phone_normalized']}_${r['phone_label']}';
        batch.insert(
          'student_cache',
          {
            'id': cacheId,
            'student_id': r['student_id'] ?? '',
            'name': r['name'] ?? '',
            'enrollment_number': r['enrollment_number'] ?? '',
            'department': r['department'] ?? '',
            'batch': r['batch'] ?? '',
            'email': r['email'],
            'phone': r['phone_raw'] ?? r['phone'] ?? '',
            'phone_normalized': r['phone'] ?? r['phone_normalized'] ?? '',
            'is_primary':
                (r['is_primary'] == 1 || r['is_primary'] == true) ? 1 : 0,
            'phone_label': r['phone_label'] ?? 'Mobile',
            'updated_at': r['updated_at'] ?? DateTime.now().toIso8601String(),
            'dob': r['dob'],
            'aadhar': r['aadhar'],
            'address': r['address'],
            'pin_code': r['pin_code'],
            'father_name': r['father_name'],
            'mother_name': r['mother_name'],
            'father_phone': r['father_phone'],
            'mother_phone': r['mother_phone'],
            'father_dob': r['father_dob'],
            'father_business': r['father_business'],
            'mother_dob': r['mother_dob'],
            'mother_business': r['mother_business'],
            'anniversary': r['anniversary'],
            'course': r['course'],
            'semester': r['semester'],
            'study_institute': r['study_institute'],
            'city': r['city'],
            'district': r['district'],
            'state': r['state'],
            'whatsapp_number': r['whatsapp_number'],
            'status': r['status'],
            'bank_code': r['bank_code'],
            'room_num': r['room_num'],
            'group_name': r['group_name'],
            'floor_num': r['floor_num'],
            'tags': r['tags'] is String ? r['tags'] : (r['tags'] != null ? jsonEncode(r['tags']) : null),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
      await batch.commit(noResult: true);
    });

    return count;
  }

  /// Searches student records grouping multiple phones under each unique student
  Future<List<PhonebookStudent>> searchStudents({
    String query = '',
    String? group,
    int? floor,
    String? status, // 'all', 'active', 'alumni'
    String? tag,
    String? state,
    String? district,
    String? city,
    bool? hasDob,
    bool? hasParent,
    bool? hasWhatsApp,
    bool? hasAddress,
    bool? hasAadhar,
    String sortBy = 'name_asc', // 'name_asc', 'name_desc', 'room_asc', 'room_desc', 'floor_asc', 'floor_desc'
    int? limit,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    final tokens = AppleSearchUtils.tokenize(query);
    if (tokens.isNotEmpty) {
      for (final rawToken in tokens) {
        final token = rawToken.trim();
        final lower = token.toLowerCase();
        final cleanedNum = token.replaceAll(RegExp(r'\D'), '');
        final stem = AppleSearchUtils.getGujaratiNameStem(lower);

        final tokenClauses = <String>[];
        final tokenArgs = <dynamic>[];

        // 1. Phone matching if token contains 3+ digits
        if (cleanedNum.isNotEmpty && cleanedNum.length >= 3) {
          tokenClauses.add('phone LIKE ? OR phone_normalized LIKE ? OR father_phone LIKE ? OR mother_phone LIKE ? OR whatsapp_number LIKE ?');
          tokenArgs.addAll(['%$cleanedNum%', '%$cleanedNum%', '%$cleanedNum%', '%$cleanedNum%', '%$cleanedNum%']);
        }

        // 2. Base text matching across student details
        tokenClauses.add(
          'name LIKE ? OR student_id LIKE ? OR enrollment_number LIKE ? OR aadhar LIKE ? OR bank_code LIKE ? OR father_name LIKE ? OR mother_name LIKE ? OR room_num LIKE ? OR city LIKE ? OR district LIKE ? OR state LIKE ? OR father_business LIKE ? OR mother_business LIKE ?',
        );
        tokenArgs.addAll([
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
          '%$token%',
        ]);

        // 3. Stem matching (e.g. searching "krutarthbhai" matches "Krutarth")
        if (stem != null && stem.length >= 3) {
          tokenClauses.add('name LIKE ? OR father_name LIKE ? OR mother_name LIKE ?');
          tokenArgs.addAll(['%$stem%', '%$stem%', '%$stem%']);
        }

        whereClauses.add('(${tokenClauses.join(' OR ')})');
        whereArgs.addAll(tokenArgs);
      }
    }

    // Group / Wing filter
    if (group != null && group != 'All') {
      final g = group.trim().toLowerCase();
      if (g == 'alumni') {
        whereClauses.add('(LOWER(department) LIKE "%alumni%" OR LOWER(status) LIKE "%left%" OR LOWER(status) LIKE "%cancel%" OR room_num IS NULL OR room_num = "" OR LOWER(room_num) = "alumni" OR LOWER(room_num) = "n/a")');
      } else if (g == 'param') {
        whereClauses.add(
          '(LOWER(department) LIKE ? AND LOWER(department) NOT LIKE ?)',
        );
        whereArgs.addAll(['%param%', '%paramanand%']);
      } else {
        whereClauses.add('(LOWER(department) LIKE ? OR LOWER(group_name) LIKE ?)');
        whereArgs.addAll(['%$g%', '%$g%']);
      }
    }

    // Floor filter
    if (floor != null) {
      whereClauses.add('floor_num = ?');
      whereArgs.add(floor);
    }

    // Status filter
    if (status != null && status != 'All') {
      final s = status.toLowerCase().trim();
      if (s == 'active') {
        whereClauses.add('(room_num IS NOT NULL AND room_num != "" AND LOWER(room_num) != "alumni" AND LOWER(room_num) != "n/a" AND (status IS NULL OR (LOWER(status) NOT LIKE "%left%" AND LOWER(status) NOT LIKE "%cancel%")))');
      } else if (s == 'alumni') {
        whereClauses.add('(room_num IS NULL OR room_num = "" OR LOWER(room_num) = "alumni" OR LOWER(room_num) = "n/a" OR LOWER(status) LIKE "%left%" OR LOWER(status) LIKE "%cancel%")');
      }
    }

    // Has DOB
    if (hasDob == true) {
      whereClauses.add('(dob IS NOT NULL AND dob != "" AND dob != "null")');
    }

    // Has Parent Contact
    if (hasParent == true) {
      whereClauses.add('((father_phone IS NOT NULL AND father_phone != "") OR (mother_phone IS NOT NULL AND mother_phone != ""))');
    }

    // Has WhatsApp
    if (hasWhatsApp == true) {
      whereClauses.add('(whatsapp_number IS NOT NULL AND whatsapp_number != "")');
    }

    // Has Permanent Address
    if (hasAddress == true) {
      whereClauses.add('(address IS NOT NULL AND address != "" AND address != "null" AND address NOT LIKE "%Hari Saurabh Hostel%")');
    }

    // Has Aadhar Card
    if (hasAadhar == true) {
      whereClauses.add('(aadhar IS NOT NULL AND aadhar != "" AND aadhar != "null")');
    }

    // Tag filter
    if (tag != null && tag.isNotEmpty && tag.toLowerCase() != 'all') {
      whereClauses.add('(LOWER(tags) LIKE ?)');
      whereArgs.add('%${tag.trim().toLowerCase()}%');
    }

    // Location filters (State, District, City)
    if (state != null && state.isNotEmpty && state.toLowerCase() != 'all') {
      whereClauses.add('LOWER(TRIM(state)) = ?');
      whereArgs.add(state.trim().toLowerCase());
    }
    if (district != null &&
        district.isNotEmpty &&
        district.toLowerCase() != 'all') {
      whereClauses.add('LOWER(TRIM(district)) = ?');
      whereArgs.add(district.trim().toLowerCase());
    }
    if (city != null && city.isNotEmpty && city.toLowerCase() != 'all') {
      whereClauses.add('LOWER(TRIM(city)) = ?');
      whereArgs.add(city.trim().toLowerCase());
    }

    final whereString =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    String orderByClause = 'name COLLATE NOCASE ASC';
    switch (sortBy) {
      case 'name_desc':
        orderByClause = 'name COLLATE NOCASE DESC';
        break;
      case 'room_asc':
        orderByClause = 'CASE WHEN room_num IS NULL OR room_num = "" OR LOWER(room_num) = "alumni" OR LOWER(room_num) = "n/a" THEN 1 ELSE 0 END ASC, CAST(room_num AS INTEGER) ASC, room_num ASC, name COLLATE NOCASE ASC';
        break;
      case 'room_desc':
        orderByClause = 'CASE WHEN room_num IS NULL OR room_num = "" OR LOWER(room_num) = "alumni" OR LOWER(room_num) = "n/a" THEN 1 ELSE 0 END ASC, CAST(room_num AS INTEGER) DESC, room_num DESC, name COLLATE NOCASE ASC';
        break;
      case 'floor_asc':
        orderByClause = 'CASE WHEN floor_num IS NULL THEN 1 ELSE 0 END, floor_num ASC, room_num ASC, name COLLATE NOCASE ASC';
        break;
      case 'floor_desc':
        orderByClause = 'CASE WHEN floor_num IS NULL THEN 1 ELSE 0 END, floor_num DESC, room_num ASC, name COLLATE NOCASE ASC';
        break;
      case 'name_asc':
      default:
        orderByClause = 'name COLLATE NOCASE ASC';
        break;
    }

    final rows = await db.query(
      'student_cache',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderByClause,
      limit: limit,
    );

    // Group rows by student_id or name so all numbers belong to one Student model
    final studentMap = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final sId = (row['student_id']?.toString().isNotEmpty ?? false)
          ? row['student_id'].toString()
          : row['name'].toString();

      if (!studentMap.containsKey(sId)) {
        studentMap[sId] = {
          'id': sId,
          'student_id': row['student_id'],
          'name': row['name'],
          'enrollment_number': row['enrollment_number'],
          'department': row['department'],
          'batch': row['batch'],
          'email': row['email'],
          'dob': row['dob'],
          'aadhar': row['aadhar'],
          'address': row['address'],
          'pin_code': row['pin_code'],
          'father_name': row['father_name'],
          'mother_name': row['mother_name'],
          'father_phone': row['father_phone'],
          'mother_phone': row['mother_phone'],
          'father_dob': row['father_dob'],
          'father_business': row['father_business'],
          'mother_dob': row['mother_dob'],
          'mother_business': row['mother_business'],
          'anniversary': row['anniversary'],
          'course': row['course'],
          'semester': row['semester'],
          'study_institute': row['study_institute'],
          'city': row['city'],
          'district': row['district'],
          'state': row['state'],
          'whatsapp_number': row['whatsapp_number'],
          'status': row['status'],
          'bank_code': row['bank_code'],
          'room_num': row['room_num'],
          'group_name': row['group_name'],
          'floor_num': row['floor_num'],
          'tags': _parseTagsJson(row['tags']),
          'phones': <Map<String, dynamic>>[],
          'updated_at': row['updated_at'],
        };
      }

      final phonesList =
          studentMap[sId]!['phones'] as List<Map<String, dynamic>>;
      final phone = row['phone']?.toString() ?? '';
      if (phone.isNotEmpty && !phonesList.any((p) => p['phone'] == phone)) {
        phonesList.add({
          'id': row['id'],
          'phone': phone,
          'phone_normalized': row['phone_normalized'],
          'label': row['phone_label'] ?? 'Mobile',
          'is_primary': row['is_primary'] == 1,
        });
      }
    }

    final studentList = studentMap.values
        .map((data) => PhonebookStudent.fromJson(data))
        .toList();

    // Apple Contacts relevance ranking for default sorting
    if (tokens.isNotEmpty && (sortBy == 'name_asc' || sortBy.isEmpty)) {
      studentList.sort((a, b) {
        final scoreA = AppleSearchUtils.computeScore(
          tokens: tokens,
          name: a.name,
          fatherName: a.fatherName,
          motherName: a.motherName,
          room: a.room,
          code: a.bankCode,
          isAlumni: a.isAlumni,
        );
        final scoreB = AppleSearchUtils.computeScore(
          tokens: tokens,
          name: b.name,
          fatherName: b.fatherName,
          motherName: b.motherName,
          room: b.room,
          code: b.bankCode,
          isAlumni: b.isAlumni,
        );
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA); // Higher relevance score first
        }
        final aAlumni = a.isAlumni;
        final bAlumni = b.isAlumni;
        if (aAlumni != bAlumni) {
          return aAlumni ? 1 : -1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    return studentList;
  }

  static List<dynamic>? _parseTagsJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) return raw;
    if (raw is String && raw.isNotEmpty && raw != 'null') {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return null;
  }

  /// Updates tags in the local cache for a specific student.
  Future<void> updateStudentTags(String studentId, List<StudentTag> tags) async {
    // A blank key would match every row without a bank code.
    if (studentId.trim().isEmpty) return;
    try {
      final db = await database;
      final tagsJson = jsonEncode(tags.map((t) => t.toJson()).toList());
      final stripped = studentId.replaceFirst('HSH-', '').replaceFirst(RegExp(r'^0+'), '');
      await db.update(
        'student_cache',
        {'tags': tagsJson},
        where: 'student_id = ? OR id = ? OR bank_code = ? OR bank_code = ? OR student_id = ?',
        whereArgs: [studentId, studentId, studentId, stripped, 'HSH-$stripped'],
      );
    } catch (_) {}
  }

  /// Syncs tags for multiple students into local SQLite cache.
  Future<void> syncStudentTags(List<Map<String, dynamic>> studentsWithTags) async {
    if (studentsWithTags.isEmpty) return;
    try {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final s in studentsWithTags) {
          final tagsRaw = s['tags'];
          if (tagsRaw == null) continue;

          List<dynamic> list;
          if (tagsRaw is List) {
            list = tagsRaw;
          } else if (tagsRaw is String && tagsRaw.isNotEmpty && tagsRaw != 'null') {
            try {
              final dec = jsonDecode(tagsRaw);
              list = dec is List ? dec : [];
            } catch (_) {
              list = [];
            }
          } else {
            list = [];
          }

          final tagsJson = jsonEncode(list);

          final rawCode = (s['student_code'] ?? s['bank_code'] ?? '').toString().trim();
          final rawId = s['id'] ?? s['student_id'];
          final numId = rawId?.toString().trim() ?? '';

          final conditions = <String>[];
          final args = <dynamic>[];

          if (rawCode.isNotEmpty) {
            conditions.add('bank_code = ?');
            args.add(rawCode);

            conditions.add('student_id = ?');
            args.add('HSH-$rawCode');

            final stripped = rawCode.replaceFirst(RegExp(r'^0+'), '');
            if (stripped.isNotEmpty && stripped != rawCode) {
              conditions.add('bank_code = ?');
              args.add(stripped);

              conditions.add('student_id = ?');
              args.add('HSH-$stripped');
            }
          }

          if (numId.isNotEmpty && numId != '0') {
            conditions.add('student_id = ?');
            args.add(numId);
          }

          if (conditions.isNotEmpty) {
            batch.update(
              'student_cache',
              {'tags': tagsJson},
              where: conditions.join(' OR '),
              whereArgs: args,
            );
          }
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      debugPrint('[PhonebookDatabase] syncStudentTags error: $e');
    }
  }

  /// Group and status per bank code, for showing them elsewhere (birthday cards).
  /// Display only: never use this to identify a student for an action.
  Future<Map<String, PhonebookGroupInfo>> groupInfoByBankCode() async {
    final db = await database;
    final rows = await db.query(
      'student_cache',
      columns: ['bank_code', 'group_name', 'status'],
      where: "bank_code IS NOT NULL AND bank_code != ''",
    );
    return buildGroupIndex(rows);
  }

  /// 12-digit Aadhar per bank code, to find a student's photo elsewhere.
  /// Display only: never use this to identify a student for an action.
  Future<Map<String, String>> aadharByBankCode() async {
    final db = await database;
    final rows = await db.query(
      'student_cache',
      columns: ['bank_code', 'aadhar'],
      where: "bank_code IS NOT NULL AND bank_code != '' AND aadhar IS NOT NULL AND aadhar != ''",
    );
    return buildAadharIndex(rows);
  }

  /// Indexes Aadhar numbers by normalized bank code. A code whose rows give
  /// different Aadhar numbers is left out rather than guessed.
  static Map<String, String> buildAadharIndex(List<Map<String, Object?>> rows) {
    final index = <String, String>{};
    final ambiguous = <String>{};
    for (final row in rows) {
      final key = normalizeBankCode('${row['bank_code'] ?? ''}');
      final digits = '${row['aadhar'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
      if (key.isEmpty || digits.length != 12 || ambiguous.contains(key)) continue;
      final existing = index[key];
      if (existing != null && existing != digits) {
        index.remove(key);
        ambiguous.add(key);
        continue;
      }
      index[key] = digits;
    }
    return index;
  }

  /// Bank code without leading zeros ("0873" and "873" are the same student).
  static String normalizeBankCode(String code) => code.trim().replaceFirst(RegExp(r'^0+(?=.)'), '');

  /// Indexes rows by normalized bank code. A code shared by rows that disagree
  /// is left out rather than guessed.
  static Map<String, PhonebookGroupInfo> buildGroupIndex(List<Map<String, Object?>> rows) {
    final index = <String, PhonebookGroupInfo>{};
    final ambiguous = <String>{};
    for (final row in rows) {
      final key = normalizeBankCode('${row['bank_code'] ?? ''}');
      if (key.isEmpty || ambiguous.contains(key)) continue;
      final info = (group: row['group_name'] as String?, status: row['status'] as String?);
      final existing = index[key];
      if (existing != null && existing != info) {
        index.remove(key);
        ambiguous.add(key);
        continue;
      }
      index[key] = info;
    }
    return index;
  }

  /// Parses aggregated `(val, cnt)` rows into deduplicated, sorted location options.
  static List<PhonebookLocationOption> parseLocationRows(
    List<Map<String, Object?>> rows,
  ) {
    final counts = <String, ({String display, int count})>{};
    for (final row in rows) {
      final raw = row['val']?.toString().trim() ?? '';
      if (raw.isEmpty || raw.toLowerCase() == 'null') continue;
      final formatted = formatPersonName(raw);
      if (formatted.isEmpty) continue;
      final key = formatted.toLowerCase();
      final cnt = int.tryParse(row['cnt']?.toString() ?? '0') ?? 0;
      final existing = counts[key];
      if (existing != null) {
        counts[key] = (display: existing.display, count: existing.count + cnt);
      } else {
        counts[key] = (display: formatted, count: cnt);
      }
    }
    final list = counts.values
        .map((e) => (name: e.display, count: e.count))
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Distinct states with unique student counts.
  Future<List<PhonebookLocationOption>> getDistinctStates() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT TRIM(state) AS val, COUNT(DISTINCT student_id) AS cnt
      FROM student_cache
      WHERE state IS NOT NULL AND TRIM(state) != '' AND LOWER(TRIM(state)) != 'null'
      GROUP BY LOWER(TRIM(state))
      ORDER BY val COLLATE NOCASE ASC
    ''');
    return parseLocationRows(rows);
  }

  /// Distinct districts with unique student counts, optionally scoped to [state].
  Future<List<PhonebookLocationOption>> getDistinctDistricts({
    String? state,
  }) async {
    final db = await database;
    final where = <String>[
      'district IS NOT NULL',
      "TRIM(district) != ''",
      "LOWER(TRIM(district)) != 'null'",
    ];
    final args = <dynamic>[];
    if (state != null && state.isNotEmpty && state.toLowerCase() != 'all') {
      where.add('LOWER(TRIM(state)) = ?');
      args.add(state.trim().toLowerCase());
    }
    final rows = await db.rawQuery('''
      SELECT TRIM(district) AS val, COUNT(DISTINCT student_id) AS cnt
      FROM student_cache
      WHERE ${where.join(' AND ')}
      GROUP BY LOWER(TRIM(district))
      ORDER BY val COLLATE NOCASE ASC
    ''', args);
    return parseLocationRows(rows);
  }

  /// Distinct cities with unique student counts, optionally scoped to [state] and [district].
  Future<List<PhonebookLocationOption>> getDistinctCities({
    String? state,
    String? district,
  }) async {
    final db = await database;
    final where = <String>[
      'city IS NOT NULL',
      "TRIM(city) != ''",
      "LOWER(TRIM(city)) != 'null'",
    ];
    final args = <dynamic>[];
    if (state != null && state.isNotEmpty && state.toLowerCase() != 'all') {
      where.add('LOWER(TRIM(state)) = ?');
      args.add(state.trim().toLowerCase());
    }
    if (district != null &&
        district.isNotEmpty &&
        district.toLowerCase() != 'all') {
      where.add('LOWER(TRIM(district)) = ?');
      args.add(district.trim().toLowerCase());
    }
    final rows = await db.rawQuery('''
      SELECT TRIM(city) AS val, COUNT(DISTINCT student_id) AS cnt
      FROM student_cache
      WHERE ${where.join(' AND ')}
      GROUP BY LOWER(TRIM(city))
      ORDER BY val COLLATE NOCASE ASC
    ''', args);
    return parseLocationRows(rows);
  }

  Future<int> getStudentCount() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(DISTINCT student_id) as count FROM student_cache',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> getTotalPhoneCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM student_cache');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> updateStudentAddress(
    String studentId,
    String address, {
    String? pinCode,
  }) async {
    final db = await database;
    await db.update(
      'student_cache',
      {
        'address': address,
        'pin_code': ?pinCode,
      },
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete('student_cache');
  }

  /// Inserts or replaces an additional contact phone record in local cache
  Future<void> insertAdditionalPhone({
    required String studentId,
    String? studentCode,
    required String phone,
    required String label,
    bool isPrimary = false,
  }) async {
    final db = await database;
    final cleanCode = (studentCode ?? '').trim();
    final normCode = cleanCode.isNotEmpty ? normalizeBankCode(cleanCode) : '';
    final hshCode = cleanCode.isNotEmpty ? 'HSH-$cleanCode' : '';

    final whereParts = <String>[
      'student_id = ?',
      'id = ?',
      'bank_code = ?',
    ];
    final whereArgs = <dynamic>[studentId, studentId, studentId];

    if (cleanCode.isNotEmpty) {
      whereParts.add('bank_code = ?');
      whereArgs.add(cleanCode);
      whereParts.add('student_id = ?');
      whereArgs.add(hshCode);
      if (normCode.isNotEmpty) {
        whereParts.add("LTRIM(bank_code, '0') = ?");
        whereArgs.add(normCode);
      }
    }

    final rows = await db.query(
      'student_cache',
      where: whereParts.join(' OR '),
      whereArgs: whereArgs,
      limit: 1,
    );
    if (rows.isEmpty) return;
    final existing = Map<String, dynamic>.from(rows.first);
    final normPhone = PhoneNumberNormalizer.normalize(phone) ?? phone;
    final cacheId = '${existing['student_id']}_${phone}_$label';

    await db.insert(
      'student_cache',
      {
        ...existing,
        'id': cacheId,
        'phone': phone,
        'phone_normalized': normPhone,
        'phone_label': label,
        'is_primary': isPrimary ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a specific additional phone number record from local cache
  Future<void> deleteAdditionalPhone({
    required String studentId,
    required String phone,
  }) async {
    final db = await database;
    final normPhone = PhoneNumberNormalizer.normalize(phone) ?? phone;
    await db.delete(
      'student_cache',
      where: '(student_id = ? OR bank_code = ?) AND (phone = ? OR phone_normalized = ?)',
      whereArgs: [studentId, studentId, phone, normPhone],
    );
  }

  /// Updates base student contact information across all rows of this student
  Future<void> updateBaseContacts({
    required String studentId,
    String? primaryPhone,
    String? whatsappNumber,
    String? fatherPhone,
    String? motherPhone,
    bool clearPrimary = false,
    bool clearWhatsApp = false,
    bool clearFather = false,
    bool clearMother = false,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (clearWhatsApp || (whatsappNumber != null && whatsappNumber.isEmpty)) {
      updates['whatsapp_number'] = null;
    } else if (whatsappNumber != null) {
      updates['whatsapp_number'] = whatsappNumber;
    }

    if (clearFather || (fatherPhone != null && fatherPhone.isEmpty)) {
      updates['father_phone'] = null;
    } else if (fatherPhone != null) {
      updates['father_phone'] = fatherPhone;
    }

    if (clearMother || (motherPhone != null && motherPhone.isEmpty)) {
      updates['mother_phone'] = null;
    } else if (motherPhone != null) {
      updates['mother_phone'] = motherPhone;
    }

    if (clearPrimary || (primaryPhone != null && primaryPhone.isEmpty)) {
      await db.update(
        'student_cache',
        {
          ...updates,
          'phone': 'No Phone',
          'phone_normalized': '',
        },
        where: '(student_id = ? OR bank_code = ?) AND is_primary = 1',
        whereArgs: [studentId, studentId],
      );
    } else if (primaryPhone != null && primaryPhone.isNotEmpty) {
      final norm = PhoneNumberNormalizer.normalize(primaryPhone) ?? primaryPhone;
      await db.update(
        'student_cache',
        {
          ...updates,
          'phone': primaryPhone,
          'phone_normalized': norm,
        },
        where: '(student_id = ? OR bank_code = ?) AND is_primary = 1',
        whereArgs: [studentId, studentId],
      );
    }

    await db.update(
      'student_cache',
      updates,
      where: 'student_id = ? OR bank_code = ?',
      whereArgs: [studentId, studentId],
    );
  }
}
