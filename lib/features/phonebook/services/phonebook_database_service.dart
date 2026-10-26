import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/phonebook_models.dart';
import 'phone_number_normalizer.dart';

typedef PhonebookGroupInfo = ({String? group, String? status});

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
      version: 5,
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
            whatsapp_number TEXT,
            status TEXT,
            bank_code TEXT,
            room_num TEXT,
            group_name TEXT,
            floor_num INTEGER
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
            'whatsapp_number': r['whatsapp_number'],
            'status': r['status'],
            'bank_code': r['bank_code'],
            'room_num': r['room_num'],
            'group_name': r['group_name'],
            'floor_num': r['floor_num'],
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

    final cleanQuery = query.trim();
    if (cleanQuery.isNotEmpty) {
      final cleanedNum = cleanQuery.replaceAll(RegExp(r'\D'), '');
      if (cleanedNum.isNotEmpty && cleanedNum.length >= 3) {
        whereClauses.add(
          '(phone LIKE ? OR phone_normalized LIKE ? OR name LIKE ? OR student_id LIKE ? OR enrollment_number LIKE ? OR department LIKE ? OR aadhar LIKE ? OR bank_code LIKE ? OR father_name LIKE ? OR mother_name LIKE ? OR room_num LIKE ?)',
        );
        whereArgs.addAll([
          '%$cleanQuery%',
          '%$cleanedNum%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
        ]);
      } else {
        whereClauses.add(
          '(name LIKE ? OR student_id LIKE ? OR enrollment_number LIKE ? OR department LIKE ? OR aadhar LIKE ? OR bank_code LIKE ? OR father_name LIKE ? OR mother_name LIKE ? OR room_num LIKE ?)',
        );
        whereArgs.addAll([
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
        ]);
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
      whereClauses.add('(address IS NOT NULL AND address != "" AND address != "null" AND address NOT LIKE "%Hari Smruti Hostel%" AND address NOT LIKE "%Hari Saurabh Hostel%")');
    }

    // Has Aadhar Card
    if (hasAadhar == true) {
      whereClauses.add('(aadhar IS NOT NULL AND aadhar != "" AND aadhar != "null")');
    }

    final whereString =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    String orderByClause = 'name COLLATE NOCASE ASC';
    switch (sortBy) {
      case 'name_desc':
        orderByClause = 'name COLLATE NOCASE DESC';
        break;
      case 'room_asc':
        orderByClause = 'CASE WHEN room_num IS NULL OR room_num = "" OR LOWER(room_num) = "alumni" THEN 1 ELSE 0 END, room_num ASC, name COLLATE NOCASE ASC';
        break;
      case 'room_desc':
        orderByClause = 'CASE WHEN room_num IS NULL OR room_num = "" OR LOWER(room_num) = "alumni" THEN 1 ELSE 0 END, room_num DESC, name COLLATE NOCASE ASC';
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
          'id': row['id'],
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
          'whatsapp_number': row['whatsapp_number'],
          'status': row['status'],
          'bank_code': row['bank_code'],
          'room_num': row['room_num'],
          'group_name': row['group_name'],
          'floor_num': row['floor_num'],
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

    return studentMap.values
        .map((data) => PhonebookStudent.fromJson(data))
        .toList();
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
}
