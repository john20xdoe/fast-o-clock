import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/fast_record.dart';

class FastValidationException implements Exception {
  final String message;
  final FastRecord? conflictingRecord;

  const FastValidationException(this.message, {this.conflictingRecord});

  @override
  String toString() => message;
}

class DatabaseService {
  static const String _dbName = 'fast_oclock.db';
  static const int _dbVersion = 1;

  Database? _db;
  final String? _overridePath;

  DatabaseService({String? overridePath}) : _overridePath = overridePath;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = _overridePath ?? p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fast_records (
        id TEXT PRIMARY KEY,
        protocol_id TEXT NOT NULL,
        start_time_ms INTEGER NOT NULL,
        end_time_ms INTEGER,
        target_duration_min INTEGER NOT NULL,
        note TEXT,
        mood TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TRIGGER trg_single_active_fast_insert
      BEFORE INSERT ON fast_records
      WHEN NEW.end_time_ms IS NULL
      BEGIN
        SELECT RAISE(ABORT, 'Active fast already exists')
        WHERE EXISTS (SELECT 1 FROM fast_records WHERE end_time_ms IS NULL);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER trg_single_active_fast_update
      BEFORE UPDATE OF end_time_ms ON fast_records
      WHEN NEW.end_time_ms IS NULL
      BEGIN
        SELECT RAISE(ABORT, 'Active fast already exists')
        WHERE EXISTS (SELECT 1 FROM fast_records WHERE end_time_ms IS NULL AND id != NEW.id);
      END
    ''');

    await db.execute(
      'CREATE INDEX idx_fast_records_start ON fast_records (start_time_ms DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_fast_records_end ON fast_records (end_time_ms DESC)',
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }

  /// Validates boundary sanity and returns the first overlapping record if any.
  Future<FastRecord?> findOverlappingRecord({
    required int candidateStartMs,
    required int? candidateEndMs,
    required int nowUtcMs,
    String? excludeId,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final effectiveEndMs = candidateEndMs ?? nowUtcMs;
    final rows = await db.rawQuery(
      '''
      SELECT * FROM fast_records
      WHERE (? IS NULL OR id != ?)
        AND start_time_ms < ?
        AND COALESCE(end_time_ms, ?) > ?
      ORDER BY start_time_ms DESC
      LIMIT 1
      ''',
      [
        excludeId,
        excludeId,
        effectiveEndMs,
        nowUtcMs,
        candidateStartMs,
      ],
    );
    if (rows.isEmpty) return null;
    return FastRecord.fromSqlMap(rows.first);
  }

  Future<void> validateRecord(
    FastRecord record, {
    required int nowUtcMs,
    DatabaseExecutor? executor,
  }) async {
    if (record.targetDurationMin <= 0) {
      throw const FastValidationException(
        'Target duration must be greater than 0 minutes.',
      );
    }
    if (record.startTimeMs > nowUtcMs) {
      throw const FastValidationException(
        'Start time cannot be in the future.',
      );
    }
    if (record.endTimeMs != null) {
      if (record.endTimeMs! > nowUtcMs) {
        throw const FastValidationException(
          'End time cannot be in the future.',
        );
      }
      if (record.endTimeMs! < record.startTimeMs + 60000) {
        throw const FastValidationException(
          'End time must be at least 1 minute after start time.',
        );
      }
    }

    final db = executor ?? await database;
    if (record.endTimeMs == null) {
      final activeRows = await db.query(
        'fast_records',
        where: 'end_time_ms IS NULL AND id != ?',
        whereArgs: [record.id],
        limit: 1,
      );
      if (activeRows.isNotEmpty) {
        throw FastValidationException(
          'An active fast already exists.',
          conflictingRecord: FastRecord.fromSqlMap(activeRows.first),
        );
      }
    }

    final conflict = await findOverlappingRecord(
      candidateStartMs: record.startTimeMs,
      candidateEndMs: record.endTimeMs,
      nowUtcMs: nowUtcMs,
      excludeId: record.id,
      executor: db,
    );
    if (conflict != null) {
      throw FastValidationException(
        'Time range overlaps with an existing fast.',
        conflictingRecord: conflict,
      );
    }
  }

  Future<FastRecord?> getActiveFast() async {
    final db = await database;
    final rows = await db.query(
      'fast_records',
      where: 'end_time_ms IS NULL',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FastRecord.fromSqlMap(rows.first);
  }

  Future<List<FastRecord>> getCompletedFasts() async {
    final db = await database;
    final rows = await db.query(
      'fast_records',
      where: 'end_time_ms IS NOT NULL',
      orderBy: 'start_time_ms DESC',
    );
    return rows.map(FastRecord.fromSqlMap).toList();
  }

  Future<List<FastRecord>> getAllRecords() async {
    final db = await database;
    final rows = await db.query(
      'fast_records',
      orderBy: 'start_time_ms DESC',
    );
    return rows.map(FastRecord.fromSqlMap).toList();
  }

  Future<FastRecord?> getRecordById(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final rows = await db.query(
      'fast_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FastRecord.fromSqlMap(rows.first);
  }

  Future<void> insertRecord(FastRecord record, {int? nowUtcMs}) async {
    final db = await database;
    final nowMs = nowUtcMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await validateRecord(record, nowUtcMs: nowMs, executor: txn);
      await txn.insert('fast_records', record.toSqlMap());
    });
  }

  Future<void> updateRecord(FastRecord record, {int? nowUtcMs}) async {
    final db = await database;
    final nowMs = nowUtcMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await validateRecord(record, nowUtcMs: nowMs, executor: txn);
      await txn.update(
        'fast_records',
        record.toSqlMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
    });
  }

  Future<void> deleteRecord(String id) async {
    final db = await database;
    await db.delete(
      'fast_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
