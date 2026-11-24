import 'package:fast_oclock/models/fast_record.dart';
import 'package:fast_oclock/models/timeline_summary.dart';
import 'package:fast_oclock/state/fasting_controller.dart';
import 'package:flutter_test/flutter_test.dart';

FastRecord _makeRecord({
  required String id,
  required DateTime endLocal,
  required int durationMin,
  String protocolId = '16_8',
  int targetDurationMin = 960,
  String? mood,
  String? note,
}) {
  final endUtcMs = endLocal.toUtc().millisecondsSinceEpoch;
  final startUtcMs = endUtcMs - durationMin * 60000;
  return FastRecord(
    id: id,
    protocolId: protocolId,
    startTimeMs: startUtcMs,
    endTimeMs: endUtcMs,
    targetDurationMin: targetDurationMin,
    mood: mood,
    note: note,
    createdAtMs: startUtcMs,
    updatedAtMs: endUtcMs,
  );
}

void main() {
  final nowLocal = DateTime(2026, 11, 24, 12, 0);
  final nowUtc = nowLocal.toUtc();

  group('TimelineSnapshot', () {
    test('keeps currentStreak and bestStreak global while scoping range KPIs',
        () {
      // 10 consecutive goal-met days ending yesterday (Nov 23)
      final history = <FastRecord>[
        for (int i = 1; i <= 10; i++)
          _makeRecord(
            id: 'r_$i',
            endLocal: DateTime(2026, 11, 24 - i, 10, 0),
            durationMin: 16 * 60 + 15,
          ),
      ];

      final snap7d = TimelineSnapshot.build(
        history: history,
        activeFast: null,
        nowUtc: nowUtc,
        defaultTargetMin: 960,
        range: TimelineRange.d7,
        filter: TimelineFilter.all,
      );

      expect(snap7d.currentStreak, 10);
      expect(snap7d.bestStreak, 10);
      // Today (Nov 24) has no fast, Nov 18..23 = 6 days inside last 7 days
      expect(snap7d.totalFastsInRange, 6);
      expect(snap7d.goalMetCountInRange, 6);
      expect(snap7d.completionPercentInRange, 100);
      expect(snap7d.chartBuckets.length, 7);
      // Filter counts & items are also scoped to 7D (1 month header + 6 records)
      expect(snap7d.allCount, 6);
      expect(snap7d.goalMetCount, 6);
      expect(snap7d.items.length, 7);
      expect(
        snap7d.allTimeAverageDuration,
        const Duration(hours: 16, minutes: 15),
      );
    });

    test('computes bestStreak separately when currentStreak is broken', () {
      // Old 4-day streak in Oct, broken, plus 2-day streak ending today
      final history = <FastRecord>[
        _makeRecord(id: 'c1', endLocal: DateTime(2026, 11, 24, 9, 0), durationMin: 960),
        _makeRecord(id: 'c2', endLocal: DateTime(2026, 11, 23, 9, 0), durationMin: 960),
        for (int i = 1; i <= 4; i++)
          _makeRecord(
            id: 'old_$i',
            endLocal: DateTime(2026, 10, 10 + i, 9, 0),
            durationMin: 960,
          ),
      ];

      final snap = TimelineSnapshot.build(
        history: history,
        activeFast: null,
        nowUtc: nowUtc,
        defaultTargetMin: 960,
        range: TimelineRange.d7,
        filter: TimelineFilter.all,
      );

      expect(snap.currentStreak, 2);
      expect(snap.bestStreak, 4);
    });

    test('selects best single fast on multi-fast day without summing durations',
        () {
      // Same calendar day (Nov 23): 5h early fast at 1 AM + 14h goal-met 14:10 fast at 11 PM
      final earlyFast = _makeRecord(
        id: 'early',
        endLocal: DateTime(2026, 11, 23, 1, 0),
        durationMin: 5 * 60,
        protocolId: '16_8',
        targetDurationMin: 960,
      );
      final goalFast = _makeRecord(
        id: 'goal',
        endLocal: DateTime(2026, 11, 23, 23, 0),
        durationMin: 14 * 60 + 20,
        protocolId: '14_10',
        targetDurationMin: 840,
      );

      final snap = TimelineSnapshot.build(
        history: [goalFast, earlyFast],
        activeFast: null,
        nowUtc: nowUtc,
        defaultTargetMin: 960,
        range: TimelineRange.d7,
        filter: TimelineFilter.all,
      );

      final nov23Bucket = snap.chartBuckets[5]; // index 6 is today (Nov 24)
      expect(nov23Bucket.status, DayFastStatus.goalMet);
      expect(nov23Bucket.primaryRecord?.id, 'goal');
      expect(nov23Bucket.recordCount, 2);
      expect(nov23Bucket.duration, const Duration(hours: 14, minutes: 20));
    });

    test('builds weekly-average buckets in All mode with primaryRecord == null',
        () {
      final history = <FastRecord>[
        _makeRecord(
          id: 'w1',
          endLocal: DateTime(2026, 11, 23, 10, 0),
          durationMin: 17 * 60,
        ),
        _makeRecord(
          id: 'w2',
          endLocal: DateTime(2026, 11, 22, 10, 0),
          durationMin: 10 * 60,
        ),
      ];

      final snap = TimelineSnapshot.build(
        history: history,
        activeFast: null,
        nowUtc: nowUtc,
        defaultTargetMin: 960,
        range: TimelineRange.all,
        filter: TimelineFilter.all,
      );

      expect(snap.chartBuckets.length, 4);
      final currentWeek = snap.chartBuckets.last;
      expect(currentWeek.isWeekly, isTrue);
      expect(currentWeek.primaryRecord, isNull);
      expect(currentWeek.recordCount, 2);
      expect(currentWeek.goalMetCount, 1);
      // 1/2 met => 50% met, colors goalMet even though avg 13.5h < 16h
      expect(currentWeek.status, DayFastStatus.goalMet);
      expect(currentWeek.duration, const Duration(hours: 13, minutes: 30));
    });

    test('builds month headers, filter counts, deltas, and metabolic stages',
        () {
      final history = <FastRecord>[
        _makeRecord(
          id: 'm1',
          endLocal: DateTime(2026, 11, 23, 11, 7),
          durationMin: 16 * 60 + 26,
          mood: 'great',
          note: 'Felt great',
        ),
        _makeRecord(
          id: 'm2',
          endLocal: DateTime(2026, 11, 22, 5, 56),
          durationMin: 10 * 60 + 43,
          protocolId: '14_10',
          targetDurationMin: 840,
          mood: 'bad',
        ),
        _makeRecord(
          id: 'm3',
          endLocal: DateTime(2026, 10, 30, 12, 0),
          durationMin: 19 * 60,
        ),
      ];

      final snapAll = TimelineSnapshot.build(
        history: history,
        activeFast: null,
        nowUtc: nowUtc,
        defaultTargetMin: 960,
        range: TimelineRange.d30,
        filter: TimelineFilter.all,
      );

      expect(snapAll.allCount, 3);
      expect(snapAll.goalMetCount, 2);
      expect(snapAll.endedEarlyCount, 1);
      expect(snapAll.withNotesCount, 1);

      // Nov header + 2 rows + Oct header + 1 row = 5 items
      expect(snapAll.items.length, 5);
      final novHeader = snapAll.items[0] as TimelineMonthHeader;
      expect(novHeader.title, 'NOVEMBER 2026');
      expect(novHeader.fastCount, 2);
      expect(novHeader.goalMetPercent, 50);

      final firstRow = snapAll.items[1] as TimelineRecordItem;
      expect(firstRow.dateStampLabel, 'NOV 23 • MON');
      expect(firstRow.endTimeLabel, '11:07 AM');
      expect(firstRow.startTimeLabel, '6:41 PM');
      expect(firstRow.deltaLabel, '+26m');
      expect(firstRow.metabolicStage.id, 'ketosis');

      final secondRow = snapAll.items[2] as TimelineRecordItem;
      expect(secondRow.deltaLabel, '-3h 17m');
      expect(secondRow.metabolicStage.id, 'fat_burning');

      final octRow = snapAll.items[4] as TimelineRecordItem;
      expect(
        TimelineSnapshot.shortStageLabel(octRow.metabolicStage),
        'Autophagy',
      );

      final snapNotes = TimelineSnapshot.build(
        history: history,
        activeFast: null,
        nowUtc: nowUtc,
        defaultTargetMin: 960,
        range: TimelineRange.d30,
        filter: TimelineFilter.withNotes,
      );
      expect(snapNotes.allCount, 3);
      expect(snapNotes.items.length, 2); // Nov header + m1
    });
  });
}
