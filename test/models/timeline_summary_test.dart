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
  bool isClean = true,
  String? endReason,
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
    isClean: isClean,
    endReason: endReason,
    createdAtMs: startUtcMs,
    updatedAtMs: endUtcMs,
  );
}

void main() {
  final nowLocal = DateTime(2026, 11, 24, 12, 0);
  final nowUtc = nowLocal.toUtc();

  group('TimelineSnapshot', () {
    test('computes global streaks, KPIs, and month headers', () {
      final history = <FastRecord>[
        for (int i = 1; i <= 10; i++)
          _makeRecord(
            id: 'r_$i',
            endLocal: DateTime(2026, 11, 24 - i, 10, 0),
            durationMin: 16 * 60 + 15,
          ),
      ];

      final snap = TimelineSnapshot.build(
        history: history,
        activeFast: null,
        nowUtc: nowUtc,
      );

      expect(snap.currentStreak, 10);
      expect(snap.bestStreak, 10);
      expect(snap.totalCompletedFasts, 10);
      expect(snap.goalMetCount, 10);
      expect(snap.goalMetPercent, 100);
      expect(
        snap.allTimeAverageDuration,
        const Duration(hours: 16, minutes: 15),
      );
      expect(snap.monthTitle, 'November 2026');
      expect(snap.calendarDays.length, 30);
      expect(snap.items.length, 11); // 1 month header + 10 records
    });

    test('computes bestStreak separately when currentStreak is broken', () {
      final history = <FastRecord>[
        _makeRecord(
          id: 'c1',
          endLocal: DateTime(2026, 11, 24, 9, 0),
          durationMin: 960,
        ),
        _makeRecord(
          id: 'c2',
          endLocal: DateTime(2026, 11, 23, 9, 0),
          durationMin: 960,
        ),
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
      );

      expect(snap.currentStreak, 2);
      expect(snap.bestStreak, 4);
    });

    test('calendar uses daily-best-fast precedence and active-only today', () {
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
      final activeToday = FastRecord(
        id: 'active',
        protocolId: '16_8',
        startTimeMs: DateTime(2026, 11, 24, 8, 0).toUtc().millisecondsSinceEpoch,
        endTimeMs: null,
        targetDurationMin: 960,
        createdAtMs: 0,
        updatedAtMs: 0,
      );

      final snap = TimelineSnapshot.build(
        history: [goalFast, earlyFast],
        activeFast: activeToday,
        nowUtc: nowUtc,
      );

      final nov23 = snap.calendarDays[22];
      expect(nov23.dayNumber, 23);
      expect(nov23.status, CalendarDayStatus.goalMet);
      expect(nov23.durationLabel, '14h 20m');
      expect(nov23.tooltipLabel, '14h 20m · Goal Met');

      final nov24 = snap.calendarDays[23];
      expect(nov24.dayNumber, 24);
      expect(nov24.isToday, isTrue);
      expect(nov24.hasActiveFast, isTrue);
      expect(nov24.status, CalendarDayStatus.none);
      expect(nov24.tooltipLabel, 'Active');
    });

    test('formats 3-line record items, excess, shortfall, and late-night start',
        () {
      // Started Nov 22 at 11:30 PM -> ended Nov 23 at 3:56 PM (16h 26m)
      final m1 = _makeRecord(
        id: 'm1',
        endLocal: DateTime(2026, 11, 23, 15, 56),
        durationMin: 16 * 60 + 26,
        isClean: false,
        note: 'Black coffee',
      );
      // Started Nov 21 at 7:13 PM -> ended Nov 22 at 5:56 AM (10h 43m of 14h)
      final m2 = _makeRecord(
        id: 'm2',
        endLocal: DateTime(2026, 11, 22, 5, 56),
        durationMin: 10 * 60 + 43,
        protocolId: '14_10',
        targetDurationMin: 840,
        endReason: 'hungry',
      );

      // Bedtime at 12:30 AM (30 min past midnight): 11:30 PM is 60m before bedtime (late-night)
      final snap = TimelineSnapshot.build(
        history: [m1, m2],
        activeFast: null,
        nowUtc: nowUtc,
        bedtimeMinutesOfDay: 30,
      );

      expect(snap.items.length, 3);
      final novHeader = snap.items[0] as TimelineMonthHeader;
      expect(novHeader.title, 'NOVEMBER 2026');
      expect(novHeader.fastCount, 2);
      expect(novHeader.goalMetPercent, 50);

      final row1 = snap.items[1] as TimelineRecordItem;
      expect(row1.startDateLabel, 'NOV 22');
      expect(row1.weekdayLabel, 'SUN');
      expect(row1.patternTag, '16:8');
      expect(row1.baseDurationLabel, '16h 00m');
      expect(row1.excessLabel, '+26m');
      expect(row1.shortfallLabel, isNull);
      expect(row1.isClean, isFalse);
      expect(row1.isLateNightStart, isTrue);
      expect(row1.endReasonLabel, isNull);

      final row2 = snap.items[2] as TimelineRecordItem;
      expect(row2.startDateLabel, 'NOV 21');
      expect(row2.weekdayLabel, 'SAT');
      expect(row2.patternTag, '14:10');
      expect(row2.baseDurationLabel, '10h 43m');
      expect(row2.excessLabel, isNull);
      expect(row2.shortfallLabel, '-3h 17m');
      expect(row2.isClean, isTrue);
      expect(row2.isLateNightStart, isFalse);
      expect(row2.endReasonLabel, 'Hungry');
    });

    test('buildLastSevenDays returns 7 days with active today fallback', () {
      final history = [
        _makeRecord(
          id: 'd3',
          endLocal: DateTime(2026, 11, 21, 10, 0),
          durationMin: 960,
        ),
        _makeRecord(
          id: 'd1',
          endLocal: DateTime(2026, 11, 23, 10, 0),
          durationMin: 600,
        ),
      ];
      final active = FastRecord(
        id: 'act',
        protocolId: '16_8',
        startTimeMs: nowUtc.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
        endTimeMs: null,
        targetDurationMin: 960,
        createdAtMs: 0,
        updatedAtMs: 0,
      );

      final days = TimelineSnapshot.buildLastSevenDays(
        history: history,
        activeFast: active,
        nowUtc: nowUtc,
      );
      expect(days.length, 7);
      expect(days[6].status, DayFastStatus.active);
      expect(days[5].status, DayFastStatus.completedBelowGoal);
      expect(days[4].status, DayFastStatus.none);
      expect(days[3].status, DayFastStatus.goalMet);
    });
  });
}
