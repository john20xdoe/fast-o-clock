import 'dart:convert';
import 'dart:math';

import '../models/app_settings.dart';
import '../models/fast_record.dart';
import 'database_service.dart';
import 'preferences_service.dart';

enum BackupImportMode { mergeById, replaceAll }

class BackupImportResult {
  final int importedCount;
  final int updatedCount;
  final int skippedCount;

  const BackupImportResult({
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
  });

  String get summary =>
      'Imported $importedCount, Updated $updatedCount, Skipped $skippedCount conflicting';
}

class BackupService {
  static const int currentSchemaVersion = 2;
  static const String appId = 'com.neurral.fast_oclock';

  final DatabaseService _databaseService;
  final PreferencesService _preferencesService;

  BackupService({
    required DatabaseService databaseService,
    required PreferencesService preferencesService,
  })  : _databaseService = databaseService,
        _preferencesService = preferencesService;

  Future<String> exportBackupJson({int? exportedAtMs}) async {
    final settings = await _preferencesService.loadSettings();
    final records = await _databaseService.getAllRecords();
    return _encodeBackupPayload(
      settings: settings,
      records: records,
      exportedAtMs:
          exportedAtMs ?? DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  /// Generates a synthetic [days]-day backup JSON mixing 14:10, 16:8, and
  /// early-ended fasts (>= 5h) without modifying local persistence.
  Future<String> exportSampleMonthBackupJson({
    int? exportedAtMs,
    int days = 30,
    Random? random,
  }) async {
    final settings = await _preferencesService.loadSettings();
    final nowMs =
        exportedAtMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final rng = random ?? Random();
    final records = _generateSampleRecords(
      nowUtcMs: nowMs,
      days: days,
      rng: rng,
      deterministicIds: random != null,
    );
    return _encodeBackupPayload(
      settings: settings,
      records: records,
      exportedAtMs: nowMs,
    );
  }

  String _encodeBackupPayload({
    required AppSettings settings,
    required List<FastRecord> records,
    required int exportedAtMs,
  }) {
    final payload = {
      'schemaVersion': currentSchemaVersion,
      'appId': appId,
      'exportedAtMs': exportedAtMs,
      'settings': settings.toBackupJson(),
      'records': records.map((r) => r.toBackupJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  List<FastRecord> _generateSampleRecords({
    required int nowUtcMs,
    required int days,
    required Random rng,
    required bool deterministicIds,
  }) {
    if (days <= 0) return const [];

    const earlyMoods = ['challenging', 'okay', 'bad', null];
    const goalMetMoods = ['great', 'okay', 'challenging', null];
    const earlyNotes = [
      'Ended early for breakfast with family',
      'Felt hungry early today',
      'Stopped early after morning workout',
    ];
    const goalMetNotes = [
      'Felt energized and clear-headed',
      'Smooth fast with black coffee and water',
      'Easy morning, hit target comfortably',
      'Good steady energy all morning',
    ];

    final templates = <({String protocolId, bool earlyEnded})>[
      if (days >= 3) ...[
        (protocolId: '14_10', earlyEnded: false),
        (protocolId: '16_8', earlyEnded: false),
        (
          protocolId: rng.nextBool() ? '14_10' : '16_8',
          earlyEnded: true,
        ),
      ],
    ];
    while (templates.length < days) {
      templates.add((
        protocolId: rng.nextBool() ? '14_10' : '16_8',
        earlyEnded: rng.nextDouble() < 0.25,
      ));
    }
    templates.shuffle(rng);

    final nowLocal =
        DateTime.fromMillisecondsSinceEpoch(nowUtcMs, isUtc: true).toLocal();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    final records = <FastRecord>[];
    int? previousEndMs;

    for (var i = 0; i < days; i++) {
      final template = templates[i];
      final dayOffset = days - i;
      final endDay = DateTime(
        todayLocal.year,
        todayLocal.month,
        todayLocal.day - dayOffset,
      );
      final startDay = DateTime(endDay.year, endDay.month, endDay.day - 1);
      final startOffsetMin = rng.nextInt(121);
      final startLocal = DateTime(
        startDay.year,
        startDay.month,
        startDay.day,
        18,
        30 + startOffsetMin,
      );
      var startMs = startLocal.toUtc().millisecondsSinceEpoch;
      if (previousEndMs != null && startMs <= previousEndMs) {
        startMs = previousEndMs + 3600000;
      }

      final targetDurationMin =
          template.protocolId == '14_10' ? 14 * 60 : 16 * 60;
      final int durationMin;
      if (template.earlyEnded) {
        const minEarlyMin = 5 * 60;
        final maxEarlyMin = targetDurationMin - 60;
        durationMin =
            minEarlyMin + rng.nextInt(maxEarlyMin - minEarlyMin + 1);
      } else {
        durationMin = targetDurationMin + rng.nextInt(46);
      }

      final endMs = startMs + durationMin * 60000;
      if (endMs > nowUtcMs) continue;

      final id = deterministicIds
          ? _deterministicHexId(rng)
          : FastRecord.generateId();
      final moodPool = template.earlyEnded ? earlyMoods : goalMetMoods;
      final mood = moodPool[rng.nextInt(moodPool.length)];
      String? note;
      if (rng.nextDouble() < 0.35) {
        final notePool = template.earlyEnded ? earlyNotes : goalMetNotes;
        note = notePool[rng.nextInt(notePool.length)];
      }

      records.add(
        FastRecord(
          id: id,
          protocolId: template.protocolId,
          startTimeMs: startMs,
          endTimeMs: endMs,
          targetDurationMin: targetDurationMin,
          note: note,
          mood: mood,
          createdAtMs: startMs,
          updatedAtMs: endMs,
        ),
      );
      previousEndMs = endMs;
    }

    return records.reversed.toList();
  }

  static String _deterministicHexId(Random rng) {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<BackupImportResult> importBackupJson(
    String jsonString, {
    BackupImportMode mode = BackupImportMode.mergeById,
    int? nowUtcMs,
  }) async {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup JSON root object.');
    }
    final version = decoded['schemaVersion'];
    if (version is! int || version < 1 || version > currentSchemaVersion) {
      throw FormatException('Unsupported backup schemaVersion: $version');
    }

    final rawRecords = decoded['records'];
    if (rawRecords is! List) {
      throw const FormatException('Missing or invalid records array.');
    }

    final incomingRecords = rawRecords
        .map((item) => FastRecord.fromBackupJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();

    final nowMs = nowUtcMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final db = await _databaseService.database;

    int imported = 0;
    int updated = 0;
    int skipped = 0;

    if (mode == BackupImportMode.replaceAll) {
      AppSettings? restoredSettings;
      final rawSettings = decoded['settings'];
      if (rawSettings is Map) {
        final currentSettings = await _preferencesService.loadSettings();
        restoredSettings = AppSettings.fromBackupJson(
          Map<String, dynamic>.from(rawSettings),
          isOnboarded: currentSettings.isOnboarded,
        );
      }

      await db.transaction((txn) async {
        await txn.delete('fast_records');
        for (final record in incomingRecords) {
          await _databaseService.validateRecord(
            record,
            nowUtcMs: nowMs,
            executor: txn,
          );
          await txn.insert('fast_records', record.toSqlMap());
          imported++;
        }
      });

      if (restoredSettings != null) {
        await _preferencesService.saveSettings(restoredSettings);
      }
    } else {
      await db.transaction((txn) async {
        for (final record in incomingRecords) {
          final existing = await _databaseService.getRecordById(
            record.id,
            executor: txn,
          );
          if (existing == null) {
            try {
              await _databaseService.validateRecord(
                record,
                nowUtcMs: nowMs,
                executor: txn,
              );
              await txn.insert('fast_records', record.toSqlMap());
              imported++;
            } on FastValidationException {
              skipped++;
            }
          } else if (record.updatedAtMs > existing.updatedAtMs) {
            try {
              await _databaseService.validateRecord(
                record,
                nowUtcMs: nowMs,
                executor: txn,
              );
              await txn.update(
                'fast_records',
                record.toSqlMap(),
                where: 'id = ?',
                whereArgs: [record.id],
              );
              updated++;
            } on FastValidationException {
              skipped++;
            }
          }
        }
      });
    }

    return BackupImportResult(
      importedCount: imported,
      updatedCount: updated,
      skippedCount: skipped,
    );
  }
}
