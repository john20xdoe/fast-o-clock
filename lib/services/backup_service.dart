import 'dart:convert';

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
  static const int currentSchemaVersion = 1;
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
    final payload = {
      'schemaVersion': currentSchemaVersion,
      'appId': appId,
      'exportedAtMs':
          exportedAtMs ?? DateTime.now().toUtc().millisecondsSinceEpoch,
      'settings': settings.toBackupJson(),
      'records': records.map((r) => r.toBackupJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
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
    if (version != currentSchemaVersion) {
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
