import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/phonebook_models.dart';
import 'phone_number_normalizer.dart';

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
      version: 2,
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
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_phone ON student_cache (phone)',
        );
        await db.execute(
          'CREATE INDEX idx_phone_norm ON student_cache (phone_normalized)',
        );
        await db.execute(
          'CREATE INDEX idx_student_name ON student_cache (name)',
        );
        await db.execute(
          'CREATE INDEX idx_student_id ON student_cache (student_id)',
        );
      },
    );
  }

  /// v1 wrote the raw string into `phone_normalized`, so caller-ID lookups
  /// (`+917984907753` vs `079849 07753`) never matched. Re-key existing rows.
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
    int limit = 500,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    final cleanQuery = query.trim();
    if (cleanQuery.isNotEmpty) {
      final cleanedNum = cleanQuery.replaceAll(RegExp(r'\D'), '');
      if (cleanedNum.isNotEmpty && cleanedNum.length >= 3) {
        whereClauses.add(
          '(phone LIKE ? OR phone_normalized LIKE ? OR name LIKE ? OR student_id LIKE ? OR enrollment_number LIKE ? OR department LIKE ?)',
        );
        whereArgs.addAll([
          '%$cleanQuery%',
          '%$cleanedNum%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
        ]);
      } else {
        whereClauses.add(
          '(name LIKE ? OR student_id LIKE ? OR enrollment_number LIKE ? OR department LIKE ?)',
        );
        whereArgs.addAll([
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
          '%$cleanQuery%',
        ]);
      }
    }

    if (group != null && group != 'All') {
      final g = group.trim().toLowerCase();
      if (g == 'param') {
        whereClauses.add(
          '(LOWER(department) LIKE ? AND LOWER(department) NOT LIKE ?)',
        );
        whereArgs.addAll(['%param%', '%paramanand%']);
      } else {
        whereClauses.add('LOWER(department) LIKE ?');
        whereArgs.add('%$g%');
      }
    }

    final whereString =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final rows = await db.query(
      'student_cache',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
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

  Future<void> clearCache() async {
    final db = await database;
    await db.delete('student_cache');
  }
}
