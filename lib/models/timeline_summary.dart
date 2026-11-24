import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../state/fasting_controller.dart';
import 'fast_protocol.dart';
import 'fast_record.dart';
import 'metabolic_stage.dart';

enum TimelineRange { d7, d30, all }

enum TimelineFilter { all, goalMet, endedEarly, withNotes }

class ChartBarBucket {
  final DateTime startDateLocal;
  final DateTime endDateLocal;
  final String axisLabel;
  final String readoutLabel;
  final Duration duration;
  final DayFastStatus status;
  final FastRecord? primaryRecord;
  final int recordCount;
  final int goalMetCount;
  final bool isToday;
  final bool isWeekly;

  const ChartBarBucket({
    required this.startDateLocal,
    required this.endDateLocal,
    required this.axisLabel,
    required this.readoutLabel,
    required this.duration,
    required this.status,
    required this.primaryRecord,
    required this.recordCount,
    required this.goalMetCount,
    required this.isToday,
    required this.isWeekly,
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
  final MetabolicStage metabolicStage;
  final String dateStampLabel;
  final String endTimeLabel;
  final String startTimeLabel;
  final String durationLabel;
  final String deltaLabel;
  final double progressRatio;
  final bool isGoalMet;
  final bool hasNote;
  final String semanticLabel;

  const TimelineRecordItem({
    required this.record,
    required this.protocol,
    required this.metabolicStage,
    required this.dateStampLabel,
    required this.endTimeLabel,
    required this.startTimeLabel,
    required this.durationLabel,
    required this.deltaLabel,
    required this.progressRatio,
    required this.isGoalMet,
    required this.hasNote,
    required this.semanticLabel,
  });
}

class TimelineSnapshot {
  static final DateFormat _dayHeaderThisYearFmt = DateFormat('EEE, MMM d');
  static final DateFormat _panelDateThisYearFmt = DateFormat('MMM d • EEE');
  static final DateFormat _panelDateOtherYearFmt =
      DateFormat('MMM d yyyy • EEE');
  static final DateFormat _shortTimeFmt = DateFormat('h:mm a');
  static final DateFormat _monthHeaderFmt = DateFormat('MMMM yyyy');
  static final DateFormat _monthDayShortFmt = DateFormat('MMM d');
  static final DateFormat _weekdayLetterFmt = DateFormat('E');

  final int currentStreak;
  final int bestStreak;

  final TimelineRange range;
  final int totalFastsInRange;
  final int goalMetCountInRange;
  final int completionPercentInRange;
  final Duration averageDurationInRange;
  final Duration longestDurationInRange;
  final Duration allTimeAverageDuration;

  final int allCount;
  final int goalMetCount;
  final int endedEarlyCount;
  final int withNotesCount;

  final List<ChartBarBucket> chartBuckets;
  final int defaultTargetMin;
  final double maxChartHours;

  final List<TimelineListItem> items;

  const TimelineSnapshot({
    required this.currentStreak,
    required this.bestStreak,
    required this.range,
    required this.totalFastsInRange,
    required this.goalMetCountInRange,
    required this.completionPercentInRange,
    required this.averageDurationInRange,
    required this.longestDurationInRange,
    required this.allTimeAverageDuration,
    required this.allCount,
    required this.goalMetCount,
    required this.endedEarlyCount,
    required this.withNotesCount,
    required this.chartBuckets,
    required this.defaultTargetMin,
    required this.maxChartHours,
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

  static String shortStageLabel(MetabolicStage stage) {
    if (stage.id == 'autophagy') return 'Autophagy';
    return stage.title;
  }

  factory TimelineSnapshot.build({
    required List<FastRecord> history,
    required FastRecord? activeFast,
    required DateTime nowUtc,
    required int defaultTargetMin,
    required TimelineRange range,
    required TimelineFilter filter,
  }) {
    final nowLocal = nowUtc.toLocal();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final rangeStartDay = switch (range) {
      TimelineRange.d7 => DateTime(today.year, today.month, today.day - 6),
      TimelineRange.d30 => DateTime(today.year, today.month, today.day - 29),
      TimelineRange.all => null,
    };

    // Sort descending by endTimeMs (falls back to startTimeMs) so month grouping
    // stays contiguous even if callers supply unsorted test records.
    final sorted = history.where((r) => r.endTimeMs != null).toList()
      ..sort((a, b) => b.endTimeMs!.compareTo(a.endTimeMs!));

    final qualifyingDays = <DateTime>{};
    final dayBestMap =
        <DateTime, ({FastRecord best, int count, int goalMetCount})>{};

    int allTimeCount = 0;
    int allTimeTotalMs = 0;

    int allCount = 0;
    int goalMetCount = 0;
    int endedEarlyCount = 0;
    int withNotesCount = 0;

    int rangeTotalCount = 0;
    int rangeGoalMetCount = 0;
    int rangeTotalMs = 0;
    int rangeLongestMs = 0;

    const maxWeeks = 12;
    final weekTotalMs = List<int>.filled(maxWeeks, 0);
    final weekCounts = List<int>.filled(maxWeeks, 0);
    final weekGoalMet = List<int>.filled(maxWeeks, 0);
    final todayUtcDay = DateTime.utc(today.year, today.month, today.day);

    // Month buckets preserve insertion order (descending by endTimeMs).
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

      // Global all-time accumulators (unclipped by range selector).
      allTimeCount++;
      allTimeTotalMs += elapsedMs;
      if (isGoalMet) {
        qualifyingDays.add(endDay);
      }

      final endUtcDay = DateTime.utc(endDay.year, endDay.month, endDay.day);
      final daysAgo = todayUtcDay.difference(endUtcDay).inDays;
      if (daysAgo >= 0 && daysAgo < maxWeeks * 7) {
        final weekIdx = daysAgo ~/ 7;
        weekTotalMs[weekIdx] += elapsedMs;
        weekCounts[weekIdx]++;
        if (isGoalMet) weekGoalMet[weekIdx]++;
      }

      // Single-best-fast selection per calendar day for daily chart buckets.
      final existingDay = dayBestMap[endDay];
      if (existingDay == null) {
        dayBestMap[endDay] = (
          best: record,
          count: 1,
          goalMetCount: isGoalMet ? 1 : 0,
        );
      } else {
        final bestIsGoal = existingDay.best.isGoalMet;
        final bestElapsedMs =
            existingDay.best.endTimeMs! - existingDay.best.startTimeMs;
        final candidateWins = (isGoalMet && !bestIsGoal) ||
            (isGoalMet == bestIsGoal && elapsedMs > bestElapsedMs);
        dayBestMap[endDay] = (
          best: candidateWins ? record : existingDay.best,
          count: existingDay.count + 1,
          goalMetCount: existingDay.goalMetCount + (isGoalMet ? 1 : 0),
        );
      }

      // Scope filter counts, KPIs, and history list to the selected range.
      final inRange = rangeStartDay == null || !endDay.isBefore(rangeStartDay);
      if (!inRange) continue;

      allCount++;
      rangeTotalCount++;
      if (isGoalMet) {
        goalMetCount++;
        rangeGoalMetCount++;
      } else {
        endedEarlyCount++;
      }
      if (hasNote) {
        withNotesCount++;
      }
      rangeTotalMs += elapsedMs;
      if (elapsedMs > rangeLongestMs) rangeLongestMs = elapsedMs;

      final matchesFilter = switch (filter) {
        TimelineFilter.all => true,
        TimelineFilter.goalMet => isGoalMet,
        TimelineFilter.endedEarly => !isGoalMet,
        TimelineFilter.withNotes => hasNote,
      };
      if (!matchesFilter) continue;

      final protocol = FastProtocol.resolve(
        record.protocolId,
        customDurationMin: record.targetDurationMin,
      );
      final stage = MetabolicStage.forElapsedDuration(elapsed);
      final dateStampLabel = (endLocal.year == nowLocal.year
              ? _panelDateThisYearFmt.format(endLocal)
              : _panelDateOtherYearFmt.format(endLocal))
          .toUpperCase();
      final endTimeLabel = _shortTimeFmt.format(endLocal);
      final startTimeLabel = _shortTimeFmt.format(startLocal);
      final durationLabel = formatDuration(elapsed);
      final deltaLabel = formatDelta(elapsed, record.targetDurationMin);
      final targetMs = record.targetDurationMin * 60000.0;
      final progressRatio =
          targetMs > 0 ? (elapsedMs / targetMs).clamp(0.0, 1.0) : 1.0;

      final moodLabel = record.mood != null ? ', mood ${record.mood}' : '';
      final noteLabel = hasNote ? ', note: ${record.note!.trim()}' : '';
      final semanticLabel =
          '$dateStampLabel, $endTimeLabel, ${protocol.label}, ${isGoalMet ? 'Goal Met' : 'Ended Early'}, '
          '$durationLabel ($deltaLabel), ${shortStageLabel(stage)}, started $startTimeLabel$moodLabel$noteLabel';

      final rowItem = TimelineRecordItem(
        record: record,
        protocol: protocol,
        metabolicStage: stage,
        dateStampLabel: dateStampLabel,
        endTimeLabel: endTimeLabel,
        startTimeLabel: startTimeLabel,
        durationLabel: durationLabel,
        deltaLabel: deltaLabel,
        progressRatio: progressRatio,
        isGoalMet: isGoalMet,
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

    // Build chart buckets.
    final chartBuckets = switch (range) {
      TimelineRange.d7 => _buildDailyBuckets(
          dayCount: 7,
          today: today,
          dayBestMap: dayBestMap,
          activeFast: activeFast,
          nowUtc: nowUtc,
          includeWeekdayLetters: true,
        ),
      TimelineRange.d30 => _buildDailyBuckets(
          dayCount: 30,
          today: today,
          dayBestMap: dayBestMap,
          activeFast: activeFast,
          nowUtc: nowUtc,
          includeWeekdayLetters: false,
        ),
      TimelineRange.all => _buildWeeklyBuckets(
          today: today,
          weekTotalMs: weekTotalMs,
          weekCounts: weekCounts,
          weekGoalMet: weekGoalMet,
          defaultTargetMin: defaultTargetMin,
        ),
    };

    double maxH = defaultTargetMin / 60.0 + 2.0;
    for (final bucket in chartBuckets) {
      final h = bucket.duration.inMinutes / 60.0;
      if (h > maxH) maxH = h;
    }
    if (maxH < 12.0) maxH = 12.0;
    final maxChartHours = (maxH / 2.0).ceil() * 2.0;

    final completionPercentInRange = rangeTotalCount == 0
        ? 0
        : ((rangeGoalMetCount * 100) / rangeTotalCount).round();
    final averageDurationInRange = rangeTotalCount == 0
        ? Duration.zero
        : Duration(milliseconds: rangeTotalMs ~/ rangeTotalCount);
    final longestDurationInRange = Duration(milliseconds: rangeLongestMs);
    final allTimeAverageDuration = allTimeCount == 0
        ? Duration.zero
        : Duration(milliseconds: allTimeTotalMs ~/ allTimeCount);

    return TimelineSnapshot(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      range: range,
      totalFastsInRange: rangeTotalCount,
      goalMetCountInRange: rangeGoalMetCount,
      completionPercentInRange: completionPercentInRange,
      averageDurationInRange: averageDurationInRange,
      longestDurationInRange: longestDurationInRange,
      allTimeAverageDuration: allTimeAverageDuration,
      allCount: allCount,
      goalMetCount: goalMetCount,
      endedEarlyCount: endedEarlyCount,
      withNotesCount: withNotesCount,
      chartBuckets: List.unmodifiable(chartBuckets),
      defaultTargetMin: defaultTargetMin,
      maxChartHours: maxChartHours,
      items: List.unmodifiable(items),
    );
  }

  static List<ChartBarBucket> _buildDailyBuckets({
    required int dayCount,
    required DateTime today,
    required Map<DateTime, ({FastRecord best, int count, int goalMetCount})>
        dayBestMap,
    required FastRecord? activeFast,
    required DateTime nowUtc,
    required bool includeWeekdayLetters,
  }) {
    final buckets = <ChartBarBucket>[];
    for (int i = dayCount - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day - i);
      final isToday = i == 0;
      final entry = dayBestMap[date];
      final axisLabel = includeWeekdayLetters
          ? '${_weekdayLetterFmt.format(date).substring(0, 1)}\n${date.day}'
          : (isToday ? 'Today' : _monthDayShortFmt.format(date));
      final readoutLabel = _dayHeaderThisYearFmt.format(date);

      if (entry != null) {
        final best = entry.best;
        buckets.add(
          ChartBarBucket(
            startDateLocal: date,
            endDateLocal: date,
            axisLabel: axisLabel,
            readoutLabel: readoutLabel,
            duration: best.elapsedDuration(),
            status: best.isGoalMet
                ? DayFastStatus.goalMet
                : DayFastStatus.completedBelowGoal,
            primaryRecord: best,
            recordCount: entry.count,
            goalMetCount: entry.goalMetCount,
            isToday: isToday,
            isWeekly: false,
          ),
        );
      } else if (isToday && activeFast != null) {
        buckets.add(
          ChartBarBucket(
            startDateLocal: date,
            endDateLocal: date,
            axisLabel: axisLabel,
            readoutLabel: 'Today',
            duration: activeFast.elapsedDuration(nowUtc),
            status: DayFastStatus.active,
            primaryRecord: null,
            recordCount: 0,
            goalMetCount: 0,
            isToday: true,
            isWeekly: false,
          ),
        );
      } else {
        buckets.add(
          ChartBarBucket(
            startDateLocal: date,
            endDateLocal: date,
            axisLabel: axisLabel,
            readoutLabel: readoutLabel,
            duration: Duration.zero,
            status: DayFastStatus.none,
            primaryRecord: null,
            recordCount: 0,
            goalMetCount: 0,
            isToday: isToday,
            isWeekly: false,
          ),
        );
      }
    }
    return buckets;
  }

  static List<ChartBarBucket> _buildWeeklyBuckets({
    required DateTime today,
    required List<int> weekTotalMs,
    required List<int> weekCounts,
    required List<int> weekGoalMet,
    required int defaultTargetMin,
  }) {
    const maxWeeks = 12;
    final weekBuckets = <ChartBarBucket>[];

    for (int w = maxWeeks - 1; w >= 0; w--) {
      final weekEnd = DateTime(today.year, today.month, today.day - w * 7);
      final weekStart =
          DateTime(weekEnd.year, weekEnd.month, weekEnd.day - 6);

      final count = weekCounts[w];
      final totalMs = weekTotalMs[w];
      final goalMet = weekGoalMet[w];

      final avgDuration = count == 0
          ? Duration.zero
          : Duration(milliseconds: totalMs ~/ count);
      final DayFastStatus status;
      if (count == 0) {
        status = DayFastStatus.none;
      } else if (avgDuration.inMinutes >= defaultTargetMin ||
          goalMet * 2 >= count) {
        status = DayFastStatus.goalMet;
      } else {
        status = DayFastStatus.completedBelowGoal;
      }

      final startStr = _monthDayShortFmt.format(weekStart);
      final endStr = weekStart.month == weekEnd.month
          ? '${weekEnd.day}'
          : _monthDayShortFmt.format(weekEnd);

      weekBuckets.add(
        ChartBarBucket(
          startDateLocal: weekStart,
          endDateLocal: weekEnd,
          axisLabel: startStr,
          readoutLabel: '$startStr–$endStr',
          duration: avgDuration,
          status: status,
          primaryRecord: null,
          recordCount: count,
          goalMetCount: goalMet,
          isToday: w == 0,
          isWeekly: true,
        ),
      );
    }

    // Trim leading empty weeks when user has fewer than 12 weeks of history,
    // keeping at least the most recent 4 weeks for visual stability.
    int firstNonEmpty = weekBuckets.indexWhere((b) => b.recordCount > 0);
    if (firstNonEmpty == -1) {
      return weekBuckets.sublist(maxWeeks - 4);
    }
    final keepFrom = math.min(firstNonEmpty, maxWeeks - 4);
    return weekBuckets.sublist(keepFrom);
  }
}
