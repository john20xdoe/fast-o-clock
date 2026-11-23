import 'package:fast_oclock/models/fast_record.dart';
import 'package:fast_oclock/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;
  const int baseNowMs = 1795200000000;

  setUp(() async {
    dbService = DatabaseService(overridePath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await dbService.close();
  });

  group('DatabaseService', () {
    test('inserts and retrieves active fast and blocks a second active fast',
        () async {
      final active1 = FastRecord(
        id: 'active_1',
        protocolId: '16_8',
        startTimeMs: baseNowMs - 3600000,
        endTimeMs: null,
        targetDurationMin: 960,
        createdAtMs: baseNowMs,
        updatedAtMs: baseNowMs,
      );

      await dbService.insertRecord(active1, nowUtcMs: baseNowMs);
      final fetched = await dbService.getActiveFast();
      expect(fetched?.id, 'active_1');

      final active2 = FastRecord(
        id: 'active_2',
        protocolId: '16_8',
        startTimeMs: baseNowMs - 1800000,
        endTimeMs: null,
        targetDurationMin: 960,
        createdAtMs: baseNowMs,
        updatedAtMs: baseNowMs,
      );

      expect(
        () => dbService.insertRecord(active2, nowUtcMs: baseNowMs),
        throwsA(isA<FastValidationException>()),
      );
    });

    test('rejects overlapping completed fasts and active fasts', () async {
      final completed = FastRecord(
        id: 'comp_1',
        protocolId: '16_8',
        startTimeMs: baseNowMs - 20 * 3600000,
        endTimeMs: baseNowMs - 4 * 3600000,
        targetDurationMin: 960,
        createdAtMs: baseNowMs,
        updatedAtMs: baseNowMs,
      );
      await dbService.insertRecord(completed, nowUtcMs: baseNowMs);

      // Overlapping past fast
      final overlappingPast = FastRecord(
        id: 'comp_2',
        protocolId: '16_8',
        startTimeMs: baseNowMs - 6 * 3600000,
        endTimeMs: baseNowMs - 1 * 3600000,
        targetDurationMin: 960,
        createdAtMs: baseNowMs,
        updatedAtMs: baseNowMs,
      );
      expect(
        () => dbService.insertRecord(overlappingPast, nowUtcMs: baseNowMs),
        throwsA(isA<FastValidationException>()),
      );

      // Active fast whose start overlaps completed fast
      final overlappingActive = FastRecord(
        id: 'act_overlap',
        protocolId: '16_8',
        startTimeMs: baseNowMs - 5 * 3600000,
        endTimeMs: null,
        targetDurationMin: 960,
        createdAtMs: baseNowMs,
        updatedAtMs: baseNowMs,
      );
      expect(
        () => dbService.insertRecord(overlappingActive, nowUtcMs: baseNowMs),
        throwsA(isA<FastValidationException>()),
      );
    });

    test('enforces 4-hour minimum duration for completed fasts', () async {
      final tooShort = FastRecord(
        id: 'short_1',
        protocolId: '16_8',
        startTimeMs: baseNowMs - 4 * 3600000 + 60000,
        endTimeMs: baseNowMs,
        targetDurationMin: 960,
        createdAtMs: baseNowMs,
        updatedAtMs: baseNowMs,
      );

      expect(
        () => dbService.insertRecord(tooShort, nowUtcMs: baseNowMs),
        throwsA(
          isA<FastValidationException>().having(
            (e) => e.message,
            'message',
            DatabaseService.minCompletedFastDurationError,
          ),
        ),
      );

      final exactFourHours = FastRecord(
        id: 'valid_4h',
        protocolId: '16_8',
        startTimeMs: baseNowMs - 4 * 3600000,
        endTimeMs: baseNowMs,
        targetDurationMin: 960,
        createdAtMs: baseNowMs,
        updatedAtMs: baseNowMs,
      );
      await dbService.insertRecord(exactFourHours, nowUtcMs: baseNowMs);
      final fetched = await dbService.getRecordById('valid_4h');
      expect(fetched?.id, 'valid_4h');
    });
  });
}
