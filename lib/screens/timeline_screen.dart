import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fast_record.dart';
import '../models/timeline_summary.dart';
import '../services/database_service.dart';
import '../state/fasting_controller.dart';
import '../widgets/fast_editor_sheet.dart';
import '../widgets/timeline_chart.dart';

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
  static const double _estimatedHeaderFallback = 380.0;
  static const double _estimatedMonthHeaderHeight = 36.0;
  static const double _estimatedPlainRowHeight = 104.0;
  static const double _estimatedNoteRowHeight = 132.0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _focusedRowKey = GlobalKey();

  TimelineRange? _userSelectedRange;
  TimelineFilter _selectedFilter = TimelineFilter.all;
  int? _selectedBarIndex;

  String? _pendingFocusedId;
  String? _highlightedRecordId;
  bool _focusCallbackScheduled = false;
  Timer? _highlightTimer;

  TimelineSnapshot? _cachedSnapshot;
  int? _cachedVersion;
  String? _cachedActiveId;
  int? _cachedDayKey;
  int? _cachedTargetMin;
  TimelineRange? _cachedRange;
  TimelineFilter? _cachedFilter;

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

  TimelineSnapshot _resolveSnapshot(
    FastingController controller, {
    required int version,
    required String? activeId,
    required int dayKey,
    required int targetMin,
    required TimelineRange range,
  }) {
    if (_cachedSnapshot != null &&
        _cachedVersion == version &&
        _cachedActiveId == activeId &&
        _cachedDayKey == dayKey &&
        _cachedTargetMin == targetMin &&
        _cachedRange == range &&
        _cachedFilter == _selectedFilter) {
      return _cachedSnapshot!;
    }

    final snapshot = TimelineSnapshot.build(
      history: controller.history,
      activeFast: controller.activeFast,
      nowUtc: controller.nowUtc,
      defaultTargetMin: targetMin,
      range: range,
      filter: _selectedFilter,
    );
    _cachedSnapshot = snapshot;
    _cachedVersion = version;
    _cachedActiveId = activeId;
    _cachedDayKey = dayKey;
    _cachedTargetMin = targetMin;
    _cachedRange = range;
    _cachedFilter = _selectedFilter;
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
      if (_selectedFilter != TimelineFilter.all ||
          snapshot.range != TimelineRange.all) {
        setState(() {
          _selectedFilter = TimelineFilter.all;
          _userSelectedRange = TimelineRange.all;
          _selectedBarIndex = null;
        });
        return;
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
      double topHeight = 0;
      for (final key in [_headerKey, _chartKey, _filterKey]) {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          topHeight += box.size.height;
        }
      }
      if (topHeight <= 0) topHeight = _estimatedHeaderFallback;

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
          int targetDurationMin,
        })>(
      selector: (_, controller) => (
        historyVersion: controller.historyVersion,
        activeId: controller.activeFast?.id,
        localDayKey: controller.localDayKey,
        targetDurationMin: controller.selectedProtocol.targetDurationMin,
      ),
      builder: (context, slice, _) {
        final controller = context.read<FastingController>();
        final theme = Theme.of(context);
        final history = controller.history;
        final effectiveRange = _userSelectedRange ??
            (history.length > 7 ? TimelineRange.d30 : TimelineRange.d7);

        final snapshot = _resolveSnapshot(
          controller,
          version: slice.historyVersion,
          activeId: slice.activeId,
          dayKey: slice.localDayKey,
          targetMin: slice.targetDurationMin,
          range: effectiveRange,
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
                              if (history.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: SegmentedButton<TimelineRange>(
                                    showSelectedIcon: false,
                                    style: SegmentedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    segments: const [
                                      ButtonSegment(
                                        value: TimelineRange.d7,
                                        label: Text('7D'),
                                      ),
                                      ButtonSegment(
                                        value: TimelineRange.d30,
                                        label: Text('30D'),
                                      ),
                                      ButtonSegment(
                                        value: TimelineRange.all,
                                        label: Text('All'),
                                      ),
                                    ],
                                    selected: {effectiveRange},
                                    onSelectionChanged: (selection) {
                                      setState(() {
                                        _userSelectedRange = selection.first;
                                        _selectedBarIndex = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              _buildKpiSummaryCard(
                                context,
                                snapshot,
                                effectiveRange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: KeyedSubtree(
                        key: _chartKey,
                        child: Container(
                          color: theme.cardTheme.color ??
                              theme.colorScheme.surfaceContainerLow,
                          padding: const EdgeInsets.only(top: 10, bottom: 8),
                          child: DurationBarChart(
                            buckets: snapshot.chartBuckets,
                            defaultTargetMin: snapshot.defaultTargetMin,
                            maxChartHours: snapshot.maxChartHours,
                            range: effectiveRange,
                            selectedIndex: _selectedBarIndex,
                            onSelectIndex: (idx) {
                              setState(() {
                                _selectedBarIndex = idx;
                              });
                            },
                            onEditRecord: (record) =>
                                _editPastFast(context, controller, record),
                          ),
                        ),
                      ),
                    ),
                    if (history.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        sliver: SliverToBoxAdapter(
                          child: KeyedSubtree(
                            key: _filterKey,
                            child: _buildFilterRow(snapshot),
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
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.filter_list_off_rounded,
                                  size: 36,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  snapshot.allCount == 0
                                      ? 'No fasts in this period'
                                      : 'No fasts match this filter',
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = TimelineFilter.all;
                                      if (snapshot.allCount == 0) {
                                        _userSelectedRange = TimelineRange.all;
                                        _selectedBarIndex = null;
                                      }
                                    });
                                  },
                                  child: const Text('Show All'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverList.builder(
                          addAutomaticKeepAlives: false,
                          itemCount: snapshot.items.length,
                          itemBuilder: (ctx, index) {
                            final item = snapshot.items[index];
                            return switch (item) {
                              TimelineMonthHeader() =>
                                _buildMonthHeader(context, item),
                              TimelineRecordItem() =>
                                _buildHistoryCard(context, controller, item),
                            };
                          },
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

  Widget _buildKpiSummaryCard(
    BuildContext context,
    TimelineSnapshot snapshot,
    TimelineRange range,
  ) {
    final theme = Theme.of(context);
    final avgSubtitle = switch (range) {
      TimelineRange.d7 => 'Last 7d avg',
      TimelineRange.d30 => 'Last 30d avg',
      TimelineRange.all => 'All-time avg',
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildKpiTile(
                    context,
                    icon: Icons.local_fire_department_rounded,
                    iconColor: DurationBarChart.endedEarlyColor,
                    value: '${snapshot.currentStreak}d',
                    subtitle: 'Streak · Best ${snapshot.bestStreak}d',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildKpiTile(
                    context,
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: DurationBarChart.goalMetColor,
                    value: '${snapshot.completionPercentInRange}%',
                    subtitle:
                        'Goal Met · ${snapshot.goalMetCountInRange}/${snapshot.totalFastsInRange}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildKpiTile(
                    context,
                    icon: Icons.schedule_rounded,
                    iconColor: theme.colorScheme.primary,
                    value: TimelineSnapshot.formatDuration(
                      snapshot.averageDurationInRange,
                    ),
                    subtitle: avgSubtitle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildKpiTile(
                    context,
                    icon: Icons.emoji_events_outlined,
                    iconColor: theme.colorScheme.secondary,
                    value: TimelineSnapshot.formatDuration(
                      snapshot.longestDurationInRange,
                    ),
                    subtitle: 'Longest fast',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$subtitle: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(TimelineSnapshot snapshot) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            TimelineFilter.all,
            'All (${snapshot.allCount})',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            TimelineFilter.goalMet,
            'Goal Met (${snapshot.goalMetCount})',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            TimelineFilter.endedEarly,
            'Ended Early (${snapshot.endedEarlyCount})',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            TimelineFilter.withNotes,
            'Notes (${snapshot.withNotesCount})',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(TimelineFilter filter, String label) {
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        if (!selected) {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
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

  ({IconData icon, Color color, String label}) _moodStyle(
    ThemeData theme,
    String mood,
  ) {
    switch (mood.toLowerCase()) {
      case 'great':
        return (
          icon: Icons.sentiment_very_satisfied_rounded,
          color: DurationBarChart.goalMetColor,
          label: 'Great',
        );
      case 'okay':
        return (
          icon: Icons.sentiment_neutral_rounded,
          color: const Color(0xFF64B5F6),
          label: 'Okay',
        );
      case 'challenging':
        return (
          icon: Icons.sentiment_dissatisfied_rounded,
          color: DurationBarChart.endedEarlyColor,
          label: 'Challenging',
        );
      case 'bad':
        return (
          icon: Icons.sentiment_very_dissatisfied_rounded,
          color: theme.colorScheme.error,
          label: 'Bad',
        );
      default:
        return (
          icon: Icons.sentiment_satisfied_alt_rounded,
          color: theme.colorScheme.primary,
          label: mood,
        );
    }
  }

  Widget _buildHistoryCard(
    BuildContext context,
    FastingController controller,
    TimelineRecordItem item,
  ) {
    final theme = Theme.of(context);
    final record = item.record;
    final statusColor = item.isGoalMet
        ? DurationBarChart.goalMetColor
        : DurationBarChart.endedEarlyColor;
    final isHighlighted = record.id == _highlightedRecordId;
    final moodStyle =
        record.mood != null ? _moodStyle(theme, record.mood!) : null;

    return KeyedSubtree(
      key: ValueKey(record.id),
      child: KeyedSubtree(
        key: isHighlighted ? _focusedRowKey : null,
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
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
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: statusColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: item.dateStampLabel,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' • ',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        TextSpan(
                                          text: item.endTimeLabel,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _miniPill(
                                  context,
                                  label: item.protocol.label,
                                  bg: theme.colorScheme.surfaceContainerHighest,
                                  fg: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.deltaLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  item.durationLabel,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _miniPill(
                                  context,
                                  label: TimelineSnapshot.shortStageLabel(
                                    item.metabolicStage,
                                  ),
                                  bg: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.45),
                                  fg: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'from ${item.startTimeLabel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                                if (moodStyle != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    moodStyle.icon,
                                    size: 16,
                                    color: moodStyle.color,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    moodStyle.label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: moodStyle.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (item.hasNote) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.notes_rounded,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      record.note!.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: item.progressRatio,
                                minHeight: 3,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(statusColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniPill(
    BuildContext context, {
    required String label,
    required Color bg,
    required Color fg,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
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
    final nowMs = controller.nowUtc.millisecondsSinceEpoch;
    final defaultEndMs = nowMs - 3600 * 1000;
    final defaultStartMs =
        defaultEndMs - protocol.targetDurationMin * 60 * 1000;

    final result = await FastEditorSheet.show(
      context,
      mode: FastEditorMode.addPast,
      databaseService: controller.databaseService,
      initialProtocolId: protocol.id,
      initialTargetDurationMin: protocol.targetDurationMin,
      initialStartTimeUtcMs: defaultStartMs,
      initialEndTimeUtcMs: defaultEndMs,
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
      );
    } on FastValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}
