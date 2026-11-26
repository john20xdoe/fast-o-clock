import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/fasting_controller.dart';
import 'fast_protocol.dart';
import 'fast_record.dart';

const Color goalMetColor = Color(0xFF00C853);
const Color endedEarlyColor = Color(0xFFFF8A00);

enum CalendarDayStatus { none, goalMet, endedEarly }

class CalendarDaySummary {
  final DateTime date;
  final int dayNumber;
  final CalendarDayStatus status;
  final String? durationLabel;
  final bool isToday;
  final bool hasActiveFast;
  final String tooltipLabel;

  const CalendarDaySummary({
    required this.date,
    required this.dayNumber,
    required this.status,
    required this.durationLabel,
    required this.isToday,
    required this.hasActiveFast,
    required this.tooltipLabel,
  });
}

sealed class TimelineListItem {
  const TimelineListItem();
}

class TimelineMonthHeader extends TimelineListItem {
  final String keyId;
  final String title;
  final int fastCount;
  final int goalMetPercent;
  final String avgDurationLabel;

  const TimelineMonthHeader({
    required this.keyId,
    required this.title,
    required this.fastCount,
    required this.goalMetPercent,
    required this.avgDurationLabel,
  });
}

class TimelineRecordItem extends TimelineListItem {
  final FastRecord record;
  final FastProtocol protocol;
  final String startDateLabel;
  final String weekdayLabel;
  final String patternTag;
  final String baseDurationLabel;
  final String? excessLabel;
  final String? shortfallLabel;
  final String timeWindowLabel;
  final bool isGoalMet;
  final bool isClean;
  final bool isLateNightStart;
  final String? endReasonLabel;
  final bool hasNote;
  final String semanticLabel;

  const TimelineRecordItem({
    required this.record,
    required this.protocol,
    required this.startDateLabel,
    required this.weekdayLabel,
    required this.patternTag,
    required this.baseDurationLabel,
    required this.excessLabel,
    required this.shortfallLabel,
    required this.timeWindowLabel,
    required this.isGoalMet,
    required this.isClean,
    required this.isLateNightStart,
    required this.endReasonLabel,
    required this.hasNote,
    required this.semanticLabel,
  });
}

class TimelineSnapshot {
  static final DateFormat _shortDateFmt = DateFormat('MMM d');
  static final DateFormat _shortDateWithYearFmt = DateFormat('MMM d yyyy');
  static final DateFormat _weekdayFmt = DateFormat('EEE');
  static final DateFormat _shortTimeFmt = DateFormat('h:mm a');
  static final DateFormat _monthHeaderFmt = DateFormat('MMMM yyyy');
  static final DateFormat _calendarMonthFmt = DateFormat('MMMM yyyy');

  final int currentStreak;
  final int bestStreak;
  final int totalCompletedFasts;
  final int goalMetCount;
  final int goalMetPercent;
  final Duration allTimeAverageDuration;

  final DateTime visibleMonth;
  final String monthTitle;
  final List<CalendarDaySummary> calendarDays;
  final List<TimelineListItem> items;

  const TimelineSnapshot({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletedFasts,
    required this.goalMetCount,
    required this.goalMetPercent,
    required this.allTimeAverageDuration,
    required this.visibleMonth,
    required this.monthTitle,
    required this.calendarDays,
    required this.items,
  });

  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  static String formatHoursShort(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String formatDelta(Duration elapsed, int targetDurationMin) {
    final diffMin = elapsed.inMinutes - targetDurationMin;
    if (diffMin == 0) return 'Goal';
    final sign = diffMin > 0 ? '+' : '-';
    final absMin = diffMin.abs();
    final h = absMin ~/ 60;
    final m = absMin % 60;
    if (h == 0) return '$sign${m}m';
    if (m == 0) return '$sign${h}h';
    return '$sign${h}h ${m}m';
  }

  static String formatPatternTag(FastProtocol protocol) {
    switch (protocol.id) {
      case '14_10':
        return '14:10';
      case '16_8':
        return '16:8';
      case '18_6':
        return '18:6';
      case '20_4':
        return '20:4';
      case '23_1':
        return '23:1';
      case '36_0':
        return '36h';
      default:
        return formatHoursShort(protocol.targetDurationMin);
    }
  }

  static String? formatEndReasonLabel(String? endReason) {
    switch (endReason) {
      case 'hungry':
        return 'Hungry';
      case 'social':
        return 'Social';
      case 'unwell':
        return 'Dizzy / Unwell';
      case 'other':
        return 'Other';
      default:
        return null;
    }
  }

  static bool isLateNightStartMinute({
    required int startMinuteOfDay,
    required int? bedtimeMinutesOfDay,
  }) {
    if (bedtimeMinutesOfDay == null) return false;
    final delta = (startMinuteOfDay - bedtimeMinutesOfDay + 1440) % 1440;
    return delta >= 1320 || delta <= 240;
  }

  factory TimelineSnapshot.build({
    required List<FastRecord> history,
    required FastRecord? activeFast,
    required DateTime nowUtc,
    DateTime? visibleMonth,
    int? bedtimeMinutesOfDay,
  }) {
    final nowLocal = nowUtc.toLocal();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final targetMonth = visibleMonth != null
        ? DateTime(visibleMonth.year, visibleMonth.month, 1)
        : DateTime(today.year, today.month, 1);

    final sorted = history.where((r) => r.endTimeMs != null).toList()
      ..sort((a, b) => b.endTimeMs!.compareTo(a.endTimeMs!));

    final qualifyingDays = <DateTime>{};
    final dayBestMap = <DateTime, FastRecord>{};

    int allTimeCount = 0;
    int allTimeGoalMet = 0;
    int allTimeTotalMs = 0;

    final monthOrder = <(int, int)>[];
    final monthRecords = <(int, int), List<TimelineRecordItem>>{};
    final monthStats = <(int, int), ({int goalMet, int totalMs})>{};

    for (final record in sorted) {
      final startLocal = record.startTimeLocal;
      final endLocal = record.endTimeLocal!;
      final endDay = DateTime(endLocal.year, endLocal.month, endLocal.day);
      final elapsedMs = math.max(0, record.endTimeMs! - record.startTimeMs);
      final elapsed = Duration(milliseconds: elapsedMs);
      final isGoalMet = record.isGoalMet;
      final hasNote = record.note != null && record.note!.trim().isNotEmpty;

      allTimeCount++;
      allTimeTotalMs += elapsedMs;
      if (isGoalMet) {
        allTimeGoalMet++;
        qualifyingDays.add(endDay);
      }

      // Daily-best-fast precedence: goalMet > endedEarly, then longest duration.
      final existingBest = dayBestMap[endDay];
      if (existingBest == null) {
        dayBestMap[endDay] = record;
      } else {
        final bestIsGoal = existingBest.isGoalMet;
        final bestElapsedMs =
            existingBest.endTimeMs! - existingBest.startTimeMs;
        final candidateWins = (isGoalMet && !bestIsGoal) ||
            (isGoalMet == bestIsGoal && elapsedMs > bestElapsedMs);
        if (candidateWins) {
          dayBestMap[endDay] = record;
        }
      }

      final protocol = FastProtocol.resolve(
        record.protocolId,
        customDurationMin: record.targetDurationMin,
      );
      final startDateLabel = (startLocal.year == nowLocal.year
              ? _shortDateFmt.format(startLocal)
              : _shortDateWithYearFmt.format(startLocal))
          .toUpperCase();
      final weekdayLabel = _weekdayFmt.format(startLocal).toUpperCase();
      final patternTag = formatPatternTag(protocol);

      final diffMin = elapsed.inMinutes - record.targetDurationMin;
      final String baseDurationLabel;
      final String? excessLabel;
      final String? shortfallLabel;
      final String durationSemantics;

      if (diffMin > 0) {
        baseDurationLabel =
            formatDuration(Duration(minutes: record.targetDurationMin));
        excessLabel = formatDelta(elapsed, record.targetDurationMin);
        shortfallLabel = null;
        durationSemantics = '$baseDurationLabel, $excessLabel past goal';
      } else if (diffMin < 0) {
        baseDurationLabel = formatDuration(elapsed);
        excessLabel = null;
        shortfallLabel = formatDelta(elapsed, record.targetDurationMin);
        durationSemantics = '$baseDurationLabel, $shortfallLabel short of goal';
      } else {
        baseDurationLabel = formatDuration(elapsed);
        excessLabel = null;
        shortfallLabel = null;
        durationSemantics = '$baseDurationLabel, goal met';
      }

      final startTimeStr = _shortTimeFmt.format(startLocal);
      final endTimeStr = _shortTimeFmt.format(endLocal);
      final timeWindowLabel = '$startTimeStr – $endTimeStr';

      final isLateNight = isLateNightStartMinute(
        startMinuteOfDay: startLocal.hour * 60 + startLocal.minute,
        bedtimeMinutesOfDay: bedtimeMinutesOfDay,
      );
      final endReasonLabel =
          isGoalMet ? null : formatEndReasonLabel(record.endReason);

      final cleanLabel = record.isClean ? 'Clean' : 'Modified';
      final lateLabel = isLateNight ? ', late-night start' : '';
      final reasonSemantics =
          endReasonLabel != null ? ', reason: $endReasonLabel' : '';
      final noteSemantics = hasNote ? ', note: ${record.note!.trim()}' : '';
      final semanticLabel =
          '$startDateLabel $weekdayLabel, $patternTag, ${isGoalMet ? 'Goal Met' : 'Ended Early'}, '
          '$durationSemantics, $timeWindowLabel, $cleanLabel$lateLabel$reasonSemantics$noteSemantics';

      final rowItem = TimelineRecordItem(
        record: record,
        protocol: protocol,
        startDateLabel: startDateLabel,
        weekdayLabel: weekdayLabel,
        patternTag: patternTag,
        baseDurationLabel: baseDurationLabel,
        excessLabel: excessLabel,
        shortfallLabel: shortfallLabel,
        timeWindowLabel: timeWindowLabel,
        isGoalMet: isGoalMet,
        isClean: record.isClean,
        isLateNightStart: isLateNight,
        endReasonLabel: endReasonLabel,
        hasNote: hasNote,
        semanticLabel: semanticLabel,
      );

      final monthKey = (endLocal.year, endLocal.month);
      final bucketList = monthRecords[monthKey];
      if (bucketList == null) {
        monthOrder.add(monthKey);
        monthRecords[monthKey] = [rowItem];
        monthStats[monthKey] = (
          goalMet: isGoalMet ? 1 : 0,
          totalMs: elapsedMs,
        );
      } else {
        bucketList.add(rowItem);
        final prev = monthStats[monthKey]!;
        monthStats[monthKey] = (
          goalMet: prev.goalMet + (isGoalMet ? 1 : 0),
          totalMs: prev.totalMs + elapsedMs,
        );
      }
    }

    // Global current & best streak (DST-safe calendar day stepping).
    int currentStreak = 0;
    int bestStreak = 0;
    if (qualifyingDays.isNotEmpty) {
      DateTime? cursor;
      if (qualifyingDays.contains(today)) {
        cursor = today;
      } else if (qualifyingDays.contains(yesterday)) {
        cursor = yesterday;
      }
      while (cursor != null && qualifyingDays.contains(cursor)) {
        currentStreak++;
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      }

      final sortedDays = qualifyingDays.toList()..sort();
      int run = 0;
      DateTime? prevDay;
      for (final day in sortedDays) {
        if (prevDay != null &&
            DateTime(prevDay.year, prevDay.month, prevDay.day + 1) == day) {
          run++;
        } else {
          run = 1;
        }
        if (run > bestStreak) bestStreak = run;
        prevDay = day;
      }
    }

    // Build flattened list items with month headers.
    final items = <TimelineListItem>[];
    for (final key in monthOrder) {
      final rows = monthRecords[key]!;
      final stats = monthStats[key]!;
      final headerDate = DateTime(key.$1, key.$2, 1);
      final title = _monthHeaderFmt.format(headerDate).toUpperCase();
      final pct = ((stats.goalMet * 100) / rows.length).round();
      final avgDur = Duration(milliseconds: stats.totalMs ~/ rows.length);
      items.add(
        TimelineMonthHeader(
          keyId: 'month_${key.$1}_${key.$2}',
          title: title,
          fastCount: rows.length,
          goalMetPercent: pct,
          avgDurationLabel: formatDuration(avgDur),
        ),
      );
      items.addAll(rows);
    }

    // Build visible month calendar days.
    final daysInMonth =
        DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final calendarDays = <CalendarDaySummary>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(targetMonth.year, targetMonth.month, d);
      final isToday = date == today;
      final best = dayBestMap[date];
      final hasActive = isToday && activeFast != null;

      if (best != null) {
        final durLabel = formatDuration(best.elapsedDuration());
        final status = best.isGoalMet
            ? CalendarDayStatus.goalMet
            : CalendarDayStatus.endedEarly;
        final statusText = best.isGoalMet ? 'Goal Met' : 'Ended Early';
        calendarDays.add(
          CalendarDaySummary(
            date: date,
            dayNumber: d,
            status: status,
            durationLabel: durLabel,
            isToday: isToday,
            hasActiveFast: hasActive,
            tooltipLabel: '$durLabel · $statusText',
          ),
        );
      } else {
        calendarDays.add(
          CalendarDaySummary(
            date: date,
            dayNumber: d,
            status: CalendarDayStatus.none,
            durationLabel: null,
            isToday: isToday,
            hasActiveFast: hasActive,
            tooltipLabel: hasActive ? 'Active' : 'No fast',
          ),
        );
      }
    }

    final goalMetPercent = allTimeCount == 0
        ? 0
        : ((allTimeGoalMet * 100) / allTimeCount).round();
    final allTimeAverageDuration = allTimeCount == 0
        ? Duration.zero
        : Duration(milliseconds: allTimeTotalMs ~/ allTimeCount);

    return TimelineSnapshot(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalCompletedFasts: allTimeCount,
      goalMetCount: allTimeGoalMet,
      goalMetPercent: goalMetPercent,
      allTimeAverageDuration: allTimeAverageDuration,
      visibleMonth: targetMonth,
      monthTitle: _calendarMonthFmt.format(targetMonth),
      calendarDays: List.unmodifiable(calendarDays),
      items: List.unmodifiable(items),
    );
  }

  /// Lightweight 7-day status builder for [FastingController.lastSevenDaysSummary].
  static List<DayFastSummary> buildLastSevenDays({
    required List<FastRecord> history,
    required FastRecord? activeFast,
    required DateTime nowUtc,
  }) {
    final nowLocal = nowUtc.toLocal();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final windowStart = DateTime(today.year, today.month, today.day - 6);

    final dayStatus = <DateTime, DayFastStatus>{};
    for (final record in history) {
      final endLocal = record.endTimeLocal;
      if (endLocal == null) continue;
      final endDay = DateTime(endLocal.year, endLocal.month, endLocal.day);
      if (endDay.isBefore(windowStart) || endDay.isAfter(today)) continue;

      final candidate = record.isGoalMet
          ? DayFastStatus.goalMet
          : DayFastStatus.completedBelowGoal;
      final existing = dayStatus[endDay];
      if (existing == null ||
          (candidate == DayFastStatus.goalMet &&
              existing != DayFastStatus.goalMet)) {
        dayStatus[endDay] = candidate;
      }
    }

    return List<DayFastSummary>.generate(7, (i) {
      final date = DateTime(today.year, today.month, today.day - (6 - i));
      final isToday = date == today;
      var status = dayStatus[date] ?? DayFastStatus.none;
      if (status == DayFastStatus.none && isToday && activeFast != null) {
        status = DayFastStatus.active;
      }
      return DayFastSummary(localDate: date, status: status);
    });
  }
}
