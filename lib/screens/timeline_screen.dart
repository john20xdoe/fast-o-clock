import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fast_record.dart';
import '../models/timeline_summary.dart';
import '../services/database_service.dart';
import '../state/fasting_controller.dart';
import '../widgets/fast_editor_sheet.dart';
import '../widgets/timeline_calendar.dart';

class TimelineScreen extends StatefulWidget {
  final String? focusedRecordId;
  final VoidCallback? onFocusedRecordHandled;

  const TimelineScreen({
    super.key,
    this.focusedRecordId,
    this.onFocusedRecordHandled,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  static const double _estimatedHeaderFallback = 420.0;
  static const double _estimatedMonthHeaderHeight = 36.0;
  static const double _estimatedPlainRowHeight = 96.0;
  static const double _estimatedNoteRowHeight = 122.0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _focusedRowKey = GlobalKey();

  DateTime? _visibleMonth;
  String? _pendingFocusedId;
  String? _highlightedRecordId;
  bool _focusCallbackScheduled = false;
  Timer? _highlightTimer;

  TimelineSnapshot? _cachedSnapshot;
  int? _cachedVersion;
  String? _cachedActiveId;
  int? _cachedDayKey;
  DateTime? _cachedMonth;
  int? _cachedBedtime;

  @override
  void initState() {
    super.initState();
    _pendingFocusedId = widget.focusedRecordId;
  }

  @override
  void didUpdateWidget(covariant TimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedRecordId != null &&
        widget.focusedRecordId != oldWidget.focusedRecordId) {
      _pendingFocusedId = widget.focusedRecordId;
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _currentMonth(DateTime nowUtc) {
    final local = nowUtc.toLocal();
    return DateTime(local.year, local.month, 1);
  }

  TimelineSnapshot _resolveSnapshot(
    FastingController controller, {
    required int version,
    required String? activeId,
    required int dayKey,
    required DateTime visibleMonth,
    required int? bedtimeMinutesOfDay,
  }) {
    if (_cachedSnapshot != null &&
        _cachedVersion == version &&
        _cachedActiveId == activeId &&
        _cachedDayKey == dayKey &&
        _cachedMonth == visibleMonth &&
        _cachedBedtime == bedtimeMinutesOfDay) {
      return _cachedSnapshot!;
    }

    final snapshot = TimelineSnapshot.build(
      history: controller.history,
      activeFast: controller.activeFast,
      nowUtc: controller.nowUtc,
      visibleMonth: visibleMonth,
      bedtimeMinutesOfDay: bedtimeMinutesOfDay,
    );
    _cachedSnapshot = snapshot;
    _cachedVersion = version;
    _cachedActiveId = activeId;
    _cachedDayKey = dayKey;
    _cachedMonth = visibleMonth;
    _cachedBedtime = bedtimeMinutesOfDay;
    return snapshot;
  }

  void _scheduleFocusIfNeeded(TimelineSnapshot snapshot) {
    final targetId = _pendingFocusedId;
    if (targetId == null || _focusCallbackScheduled) return;
    _focusCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCallbackScheduled = false;
      if (!mounted) return;
      _handlePendingFocus(snapshot);
    });
  }

  Future<void> _handlePendingFocus(TimelineSnapshot snapshot) async {
    final targetId = _pendingFocusedId;
    if (targetId == null) return;

    final targetIndex = snapshot.items.indexWhere(
      (item) => item is TimelineRecordItem && item.record.id == targetId,
    );

    if (targetIndex == -1) {
      final controller = context.read<FastingController>();
      for (final r in controller.history) {
        if (r.id == targetId && r.endTimeLocal != null) {
          final targetMonth =
              DateTime(r.endTimeLocal!.year, r.endTimeLocal!.month, 1);
          if (targetMonth != snapshot.visibleMonth) {
            setState(() {
              _visibleMonth = targetMonth;
            });
            return;
          }
          break;
        }
      }
      _pendingFocusedId = null;
      widget.onFocusedRecordHandled?.call();
      return;
    }

    _pendingFocusedId = null;
    widget.onFocusedRecordHandled?.call();

    _highlightTimer?.cancel();
    setState(() {
      _highlightedRecordId = targetId;
    });
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _highlightedRecordId = null;
      });
    });

    if (_scrollController.hasClients) {
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      final topHeight =
          (box != null && box.size.height > 0) ? box.size.height : _estimatedHeaderFallback;

      double listOffset = 0;
      for (int i = 0; i < targetIndex; i++) {
        final item = snapshot.items[i];
        listOffset += switch (item) {
          TimelineMonthHeader() => _estimatedMonthHeaderHeight,
          TimelineRecordItem(:final hasNote) =>
            hasNote ? _estimatedNoteRowHeight : _estimatedPlainRowHeight,
        };
      }

      final maxExtent = _scrollController.position.maxScrollExtent;
      final clampedOffset = (topHeight + listOffset).clamp(0.0, maxExtent);
      await _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _focusedRowKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 220),
            alignment: 0.2,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<
        FastingController,
        ({
          int historyVersion,
          String? activeId,
          int localDayKey,
          int? bedtimeMinutesOfDay,
        })>(
      selector: (_, controller) => (
        historyVersion: controller.historyVersion,
        activeId: controller.activeFast?.id,
        localDayKey: controller.localDayKey,
        bedtimeMinutesOfDay: controller.settings.bedtimeMinutesOfDay,
      ),
      builder: (context, slice, _) {
        final controller = context.read<FastingController>();
        final theme = Theme.of(context);
        final history = controller.history;
        final currentMonth = _currentMonth(controller.nowUtc);
        final effectiveMonth = _visibleMonth ?? currentMonth;
        final canGoNext = effectiveMonth.isBefore(currentMonth);

        final snapshot = _resolveSnapshot(
          controller,
          version: slice.historyVersion,
          activeId: slice.activeId,
          dayKey: slice.localDayKey,
          visibleMonth: effectiveMonth,
          bedtimeMinutesOfDay: slice.bedtimeMinutesOfDay,
        );

        _scheduleFocusIfNeeded(snapshot);

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: CustomScrollView(
                  key: const PageStorageKey<String>('timeline_scroll'),
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _headerKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Timeline',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _addPastFast(context, controller),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Log Fast'),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildCompactKpiStrip(context, snapshot),
                              const SizedBox(height: 10),
                              TimelineCalendar(
                                monthTitle: snapshot.monthTitle,
                                days: snapshot.calendarDays,
                                canGoNext: canGoNext,
                                onPreviousMonth: () {
                                  setState(() {
                                    _visibleMonth = DateTime(
                                      effectiveMonth.year,
                                      effectiveMonth.month - 1,
                                      1,
                                    );
                                  });
                                },
                                onNextMonth: () {
                                  if (!canGoNext) return;
                                  setState(() {
                                    _visibleMonth = DateTime(
                                      effectiveMonth.year,
                                      effectiveMonth.month + 1,
                                      1,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (history.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No completed fasts yet',
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Complete your first fast or tap "+ Log Fast" to add a previous fast.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (snapshot.items.isEmpty)
                      DecoratedSliver(
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black
                              : null,
                        ),
                        sliver: SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_busy_rounded,
                                    size: 40,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No fasts in ${snapshot.monthTitle}',
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      DecoratedSliver(
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black
                              : null,
                        ),
                        sliver: SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          sliver: SliverList.builder(
                            addAutomaticKeepAlives: false,
                            itemCount: snapshot.items.length,
                            itemBuilder: (ctx, index) {
                              final item = snapshot.items[index];
                              final isLast = index == snapshot.items.length - 1;
                              final isFirstRecord = index == 0 ||
                                  snapshot.items[index - 1]
                                      is TimelineMonthHeader;
                              return switch (item) {
                                TimelineMonthHeader() =>
                                  _buildMonthHeader(context, item),
                                TimelineRecordItem() => _buildTimelineRow(
                                    context,
                                    controller,
                                    item,
                                    isFirstInGroup: isFirstRecord,
                                    isLastOverall: isLast,
                                  ),
                              };
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactKpiStrip(
    BuildContext context,
    TimelineSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          children: [
            Text(
              'ALL-TIME',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCell(
                    context,
                    label: 'Streak',
                    value: '${snapshot.currentStreak}d',
                    sublabel: 'Best ${snapshot.bestStreak}d',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _buildKpiCell(
                    context,
                    label: 'Avg Duration',
                    value: TimelineSnapshot.formatDuration(
                      snapshot.allTimeAverageDuration,
                    ),
                    sublabel: '${snapshot.totalCompletedFasts} fasts',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _buildKpiCell(
                    context,
                    label: 'Goal Met',
                    value: '${snapshot.goalMetPercent}%',
                    sublabel:
                        '${snapshot.goalMetCount}/${snapshot.totalCompletedFasts}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCell(
    BuildContext context, {
    required String label,
    required String value,
    required String sublabel,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value ($sublabel)',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            sublabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(
    BuildContext context,
    TimelineMonthHeader header,
  ) {
    final theme = Theme.of(context);
    final fastWord = header.fastCount == 1 ? 'fast' : 'fasts';
    return Padding(
      key: ValueKey(header.keyId),
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              header.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '${header.fastCount} $fastWord · ${header.goalMetPercent}% · avg ${header.avgDurationLabel}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
    BuildContext context,
    FastingController controller,
    TimelineRecordItem item, {
    required bool isFirstInGroup,
    required bool isLastOverall,
  }) {
    final theme = Theme.of(context);
    final record = item.record;
    final badgeColor = item.isGoalMet ? goalMetColor : endedEarlyColor;
    final isHighlighted = record.id == _highlightedRecordId;
    final spineColor = theme.colorScheme.outlineVariant;

    return KeyedSubtree(
      key: ValueKey(record.id),
      child: KeyedSubtree(
        key: isHighlighted ? _focusedRowKey : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left vertical timeline spine
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 16,
                      color: isFirstInGroup ? Colors.transparent : spineColor,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: spineColor,
                      ),
                    ),
                    if (isLastOverall)
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: spineColor,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Neutral 3-line card
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isHighlighted
                        ? BorderSide(color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _editPastFast(context, controller, record),
                    child: Semantics(
                      container: true,
                      label: item.semanticLabel,
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Line 1: NOV 25 • WED · Pattern · Status Badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.startDateLabel} • ${item.weekdayLabel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                _neutralChip(context, label: item.patternTag),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.isGoalMet ? 'Goal Met' : 'Ended Early',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: badgeColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            // Line 2: Base duration + excess or strikeout shortfall
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  item.baseDurationLabel,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (item.excessLabel != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    item.excessLabel!,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: goalMetColor,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                                if (item.shortfallLabel != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    item.shortfallLabel!,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: theme.colorScheme.error,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Line 3: Time window + optional subtle tags
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  item.timeWindowLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (!item.isClean)
                                  _neutralChip(context, label: 'Modified'),
                                if (item.isLateNightStart)
                                  _neutralChip(context, label: 'Late-night'),
                                if (item.endReasonLabel != null)
                                  _neutralChip(
                                    context,
                                    label: item.endReasonLabel!,
                                  ),
                              ],
                            ),
                            if (item.hasNote) ...[
                              const SizedBox(height: 6),
                              Text(
                                record.note!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _neutralChip(BuildContext context, {required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _addPastFast(
    BuildContext context,
    FastingController controller,
  ) async {
    final protocol = controller.selectedProtocol;

    final result = await FastEditorSheet.show(
      context,
      mode: FastEditorMode.addPast,
      databaseService: controller.databaseService,
      initialProtocolId: protocol.id,
      initialTargetDurationMin: protocol.targetDurationMin,
    );
    if (result == null || result.endTimeUtcMs == null) return;
    try {
      await controller.addPastFast(
        protocolId: result.protocolId,
        targetDurationMin: result.targetDurationMin,
        startTimeUtcMs: result.startTimeUtcMs,
        endTimeUtcMs: result.endTimeUtcMs!,
        mood: result.mood,
        note: result.note,
        isClean: result.isClean,
        endReason: result.endReason,
      );
    } on FastValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _editPastFast(
    BuildContext context,
    FastingController controller,
    FastRecord record,
  ) async {
    final result = await FastEditorSheet.show(
      context,
      mode: FastEditorMode.editPast,
      databaseService: controller.databaseService,
      recordId: record.id,
      initialProtocolId: record.protocolId,
      initialTargetDurationMin: record.targetDurationMin,
      initialStartTimeUtcMs: record.startTimeMs,
      initialEndTimeUtcMs: record.endTimeMs,
      initialMood: record.mood,
      initialNote: record.note,
      initialIsClean: record.isClean,
      initialEndReason: record.endReason,
    );
    if (result == null) return;

    if (result.deleteRequested) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Fast Record?'),
          content: const Text(
            'This completed fast will be permanently removed from your timeline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await controller.deleteFastRecord(record.id);
      }
      return;
    }

    if (result.endTimeUtcMs == null) return;
    try {
      await controller.updateCompletedFast(
        id: record.id,
        protocolId: result.protocolId,
        targetDurationMin: result.targetDurationMin,
        startTimeUtcMs: result.startTimeUtcMs,
        endTimeUtcMs: result.endTimeUtcMs!,
        mood: result.mood,
        note: result.note,
        isClean: result.isClean,
        endReason: result.endReason,
      );
    } on FastValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}
