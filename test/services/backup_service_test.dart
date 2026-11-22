import 'dart:convert';

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
  });
}
