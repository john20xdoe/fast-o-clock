import 'dart:convert';
import 'dart:math';

import 'package:fast_oclock/models/fast_record.dart';
import 'package:fast_oclock/services/backup_service.dart';
import 'package:fast_oclock/services/database_service.dart';
import 'package:fast_oclock/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;
  late PreferencesService prefsService;
  late BackupService backupService;
  const int nowMs = 1795200000000;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dbService = DatabaseService(overridePath: inMemoryDatabasePath);
    prefsService = PreferencesService();
    backupService = BackupService(
      databaseService: dbService,
      preferencesService: prefsService,
    );
  });

  tearDown(() async {
    await dbService.close();
  });

  group('BackupService', () {
    test('exports and merges non-conflicting records while skipping overlaps',
        () async {
      final localRecord = FastRecord(
        id: 'rec_1',
        protocolId: '16_8',
        startTimeMs: nowMs - 48 * 3600000,
        endTimeMs: nowMs - 32 * 3600000,
        targetDurationMin: 960,
        createdAtMs: nowMs - 48 * 3600000,
        updatedAtMs: 1000,
      );
      await dbService.insertRecord(localRecord, nowUtcMs: nowMs);

      final incomingPayload = {
        'schemaVersion': 1,
        'appId': 'com.neurral.fast_oclock',
        'exportedAtMs': nowMs,
        'settings': {
          'defaultProtocolId': '18_6',
          'customDurationMin': 1080,
          'themeMode': 'dark',
          'notifyGoalReached': true,
          'notifyEatingWindow': false,
          'showRemainingTime': true,
        },
        'records': [
          // Newer version of rec_1 with updated note
          {
            'id': 'rec_1',
            'protocolId': '16_8',
            'startTimeMs': nowMs - 48 * 3600000,
            'endTimeMs': nowMs - 32 * 3600000,
            'targetDurationMin': 960,
            'note': 'Updated note',
            'mood': 'great',
            'createdAtMs': nowMs - 48 * 3600000,
            'updatedAtMs': 2000,
          },
          // Conflicting record that overlaps rec_1
          {
            'id': 'rec_conflict',
            'protocolId': '16_8',
            'startTimeMs': nowMs - 40 * 3600000,
            'endTimeMs': nowMs - 24 * 3600000,
            'targetDurationMin': 960,
            'createdAtMs': nowMs - 40 * 3600000,
            'updatedAtMs': 2000,
          },
          // Clean new record
          {
            'id': 'rec_2',
            'protocolId': '16_8',
            'startTimeMs': nowMs - 20 * 3600000,
            'endTimeMs': nowMs - 4 * 3600000,
            'targetDurationMin': 960,
            'createdAtMs': nowMs - 20 * 3600000,
            'updatedAtMs': 2000,
          },
        ],
      };

      final result = await backupService.importBackupJson(
        jsonEncode(incomingPayload),
        mode: BackupImportMode.mergeById,
        nowUtcMs: nowMs,
      );

      expect(result.importedCount, 1);
      expect(result.updatedCount, 1);
      expect(result.skippedCount, 1);

      final rec1 = await dbService.getRecordById('rec_1');
      expect(rec1?.note, 'Updated note');
    });

    test('replaceAll replaces records and settings, and rolls back on error',
        () async {
      final existing = FastRecord(
        id: 'old_1',
        protocolId: '16_8',
        startTimeMs: nowMs - 48 * 3600000,
        endTimeMs: nowMs - 32 * 3600000,
        targetDurationMin: 960,
        createdAtMs: nowMs - 48 * 3600000,
        updatedAtMs: 1000,
      );
      await dbService.insertRecord(existing, nowUtcMs: nowMs);

      final badSettingsPayload = {
        'schemaVersion': 1,
        'appId': 'com.neurral.fast_oclock',
        'exportedAtMs': nowMs,
        'settings': {
          'themeMode': 123, // invalid type
        },
        'records': [
          {
            'id': 'new_1',
            'protocolId': '18_6',
            'startTimeMs': nowMs - 20 * 3600000,
            'endTimeMs': nowMs - 2 * 3600000,
            'targetDurationMin': 1080,
            'createdAtMs': nowMs - 20 * 3600000,
            'updatedAtMs': 2000,
          },
        ],
      };

      await expectLater(
        () => backupService.importBackupJson(
          jsonEncode(badSettingsPayload),
          mode: BackupImportMode.replaceAll,
          nowUtcMs: nowMs,
        ),
        throwsA(isA<TypeError>()),
      );
      // Existing record preserved because settings failed before DB wipe
      expect(await dbService.getRecordById('old_1'), isNotNull);

      final validPayload = {
        'schemaVersion': 1,
        'appId': 'com.neurral.fast_oclock',
        'exportedAtMs': nowMs,
        'settings': {
          'defaultProtocolId': '18_6',
          'customDurationMin': 1080,
          'themeMode': 'light',
          'notifyGoalReached': false,
          'notifyEatingWindow': true,
          'showRemainingTime': true,
        },
        'records': [
          {
            'id': 'new_1',
            'protocolId': '18_6',
            'startTimeMs': nowMs - 20 * 3600000,
            'endTimeMs': nowMs - 2 * 3600000,
            'targetDurationMin': 1080,
            'createdAtMs': nowMs - 20 * 3600000,
            'updatedAtMs': 2000,
          },
        ],
      };

      final result = await backupService.importBackupJson(
        jsonEncode(validPayload),
        mode: BackupImportMode.replaceAll,
        nowUtcMs: nowMs,
      );
      expect(result.importedCount, 1);
      expect(await dbService.getRecordById('old_1'), isNull);
      expect(await dbService.getRecordById('new_1'), isNotNull);
      final restoredSettings = await prefsService.loadSettings();
      expect(restoredSettings.themeMode, 'light');
      expect(restoredSettings.defaultProtocolId, '18_6');
    });

    test('rejects unsupported schemaVersion', () async {
      final badVersion = jsonEncode({
        'schemaVersion': 99,
        'records': [],
      });
      await expectLater(
        () => backupService.importBackupJson(badVersion, nowUtcMs: nowMs),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'exportSampleMonthBackupJson generates 30 valid non-overlapping mixed fasts and round-trips cleanly',
        () async {
      final sampleJson = await backupService.exportSampleMonthBackupJson(
        exportedAtMs: nowMs,
        random: Random(42),
      );

      final decoded = jsonDecode(sampleJson) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], BackupService.currentSchemaVersion);
      expect(decoded['appId'], BackupService.appId);
      expect(decoded['exportedAtMs'], nowMs);

      final rawRecords = decoded['records'] as List<dynamic>;
      expect(rawRecords.length, 30);

      final records = rawRecords
          .map((item) => FastRecord.fromBackupJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();

      bool has1410GoalMet = false;
      bool has168GoalMet = false;
      bool hasEarlyEnded = false;

      for (var i = 0; i < records.length; i++) {
        final r = records[i];
        expect(r.protocolId, anyOf('14_10', '16_8'));
        expect(r.targetDurationMin, r.protocolId == '14_10' ? 840 : 960);
        expect(r.endTimeMs, isNotNull);
        expect(r.endTimeMs!, lessThanOrEqualTo(nowMs));
        expect(
          r.endTimeMs! - r.startTimeMs,
          greaterThanOrEqualTo(DatabaseService.minCompletedFastDurationMs),
        );

        if (r.protocolId == '14_10' && r.isGoalMet) has1410GoalMet = true;
        if (r.protocolId == '16_8' && r.isGoalMet) has168GoalMet = true;
        if (!r.isGoalMet) hasEarlyEnded = true;

        if (i + 1 < records.length) {
          expect(r.startTimeMs, greaterThan(records[i + 1].endTimeMs!));
        }
      }

      expect(has1410GoalMet, isTrue);
      expect(has168GoalMet, isTrue);
      expect(hasEarlyEnded, isTrue);

      final importResult = await backupService.importBackupJson(
        sampleJson,
        mode: BackupImportMode.replaceAll,
        nowUtcMs: nowMs,
      );
      expect(importResult.importedCount, 30);
      expect(importResult.updatedCount, 0);
      expect(importResult.skippedCount, 0);
      expect((await dbService.getAllRecords()).length, 30);
    });
  });
}
