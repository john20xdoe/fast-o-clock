import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/fast_record.dart';
import '../models/timeline_summary.dart';
import '../state/fasting_controller.dart';

class DurationBarChart extends StatelessWidget {
  static const Color goalMetColor = Color(0xFF00C853);
  static const Color endedEarlyColor = Color(0xFFFF8A00);

  static const double _chartHeight = 148;
  static const double _leftGutter = 32;
  static const double _rightPadding = 8;
  static const double _topPadding = 14;
  static const double _bottomGutter = 32;

  final List<ChartBarBucket> buckets;
  final int defaultTargetMin;
  final double maxChartHours;
  final TimelineRange range;
  final int? selectedIndex;
  final ValueChanged<int?> onSelectIndex;
  final ValueChanged<FastRecord>? onEditRecord;

  const DurationBarChart({
    super.key,
    required this.buckets,
    required this.defaultTargetMin,
    required this.maxChartHours,
    required this.range,
    required this.selectedIndex,
    required this.onSelectIndex,
    this.onEditRecord,
  });

  String _semanticsSummary() {
    int met = 0;
    int early = 0;
    int active = 0;
    for (final b in buckets) {
      switch (b.status) {
        case DayFastStatus.goalMet:
          met++;
          break;
        case DayFastStatus.completedBelowGoal:
          early++;
          break;
        case DayFastStatus.active:
          active++;
          break;
        case DayFastStatus.none:
          break;
      }
    }
    final rangeLabel = switch (range) {
      TimelineRange.d7 => 'Last 7 days',
      TimelineRange.d30 => 'Last 30 days',
      TimelineRange.all => 'Weekly averages',
    };
    final activePart = active > 0 ? ', $active active' : '';
    return '$rangeLabel chart: $met goal met, $early below goal$activePart. Tap to inspect.';
  }

  void _handleTap(Offset localPosition, double totalWidth) {
    if (buckets.isEmpty) return;
    final plotWidth = totalWidth - _leftGutter - _rightPadding;
    if (plotWidth <= 0) return;

    final dx = localPosition.dx - _leftGutter;
    if (dx < 0 || dx > plotWidth) {
      onSelectIndex(null);
      return;
    }

    final slotWidth = plotWidth / buckets.length;
    final index = (dx / slotWidth).floor().clamp(0, buckets.length - 1);
    onSelectIndex(selectedIndex == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validSelected = (selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < buckets.length)
        ? selectedIndex
        : null;
    final selectedBucket =
        validSelected != null ? buckets[validSelected] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: _semanticsSummary(),
          container: true,
          child: SizedBox(
            height: _chartHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      _handleTap(details.localPosition, constraints.maxWidth),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, _chartHeight),
                      painter: _DurationBarPainter(
                        buckets: buckets,
                        defaultTargetMin: defaultTargetMin,
                        maxChartHours: maxChartHours,
                        range: range,
                        selectedIndex: validSelected,
                        primaryColor: theme.colorScheme.primary,
                        gridColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.45),
                        emptyDotColor:
                            theme.colorScheme.surfaceContainerHighest,
                        labelColor: theme.colorScheme.onSurfaceVariant,
                        surfaceColor: theme.colorScheme.surface,
                        textStyle: theme.textTheme.labelSmall ??
                            const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildReadout(context, selectedBucket),
      ],
    );
  }

  Widget _buildReadout(BuildContext context, ChartBarBucket? bucket) {
    final theme = Theme.of(context);

    if (bucket == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Tap a bar to inspect',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _legendItem(context, goalMetColor, 'Goal Met'),
            const SizedBox(width: 12),
            _legendItem(context, endedEarlyColor, 'Ended Early'),
          ],
        ),
      );
    }

    if (!bucket.isWeekly && bucket.primaryRecord != null) {
      final record = bucket.primaryRecord!;
      final durStr = TimelineSnapshot.formatDuration(bucket.duration);
      final targetStr =
          TimelineSnapshot.formatHoursShort(record.targetDurationMin);
      final statusStr = record.isGoalMet ? 'Goal Met' : 'Ended Early';
      final statusColor = record.isGoalMet ? goalMetColor : endedEarlyColor;
      final extraStr =
          bucket.recordCount > 1 ? ' · +${bucket.recordCount - 1} more' : '';

      return Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onEditRecord != null ? () => onEditRecord!(record) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${bucket.readoutLabel} · $durStr / $targetStr · $statusStr$extraStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onEditRecord != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Edit',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final String message;
    final Color dotColor;
    if (bucket.isWeekly) {
      dotColor = switch (bucket.status) {
        DayFastStatus.goalMet => goalMetColor,
        DayFastStatus.completedBelowGoal => endedEarlyColor,
        DayFastStatus.active => theme.colorScheme.primary,
        DayFastStatus.none => theme.colorScheme.onSurfaceVariant,
      };
      message = bucket.recordCount == 0
          ? '${bucket.readoutLabel} · No fasts logged'
          : '${bucket.readoutLabel} · Avg ${TimelineSnapshot.formatDuration(bucket.duration)} · ${bucket.goalMetCount}/${bucket.recordCount} met';
    } else if (bucket.status == DayFastStatus.active) {
      dotColor = theme.colorScheme.primary;
      message =
          '${bucket.readoutLabel} · Active fast (${TimelineSnapshot.formatDuration(bucket.duration)})';
    } else {
      dotColor = theme.colorScheme.onSurfaceVariant;
      message = '${bucket.readoutLabel} · No fast logged';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DurationBarPainter extends CustomPainter {
  final List<ChartBarBucket> buckets;
  final int defaultTargetMin;
  final double maxChartHours;
  final TimelineRange range;
  final int? selectedIndex;
  final Color primaryColor;
  final Color gridColor;
  final Color emptyDotColor;
  final Color labelColor;
  final Color surfaceColor;
  final TextStyle textStyle;

  const _DurationBarPainter({
    required this.buckets,
    required this.defaultTargetMin,
    required this.maxChartHours,
    required this.range,
    required this.selectedIndex,
    required this.primaryColor,
    required this.gridColor,
    required this.emptyDotColor,
    required this.labelColor,
    required this.surfaceColor,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = DurationBarChart._leftGutter;
    final plotTop = DurationBarChart._topPadding;
    final plotRight = size.width - DurationBarChart._rightPadding;
    final plotBottom = size.height - DurationBarChart._bottomGutter;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Horizontal Y-axis gridlines & labels (0h, mid, max)
    final yTicks = [0.0, maxChartHours / 2.0, maxChartHours];
    for (final h in yTicks) {
      final y = plotBottom - (h / maxChartHours) * plotHeight;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      _paintText(
        canvas,
        '${h.round()}h',
        textStyle.copyWith(color: labelColor, fontSize: 10),
        Offset(0, y - 6),
        maxWidth: plotLeft - 4,
        align: TextAlign.right,
      );
    }

    // Dashed reference line for Default protocol target
    final targetHours = (defaultTargetMin / 60.0).clamp(0.0, maxChartHours);
    final targetY = plotBottom - (targetHours / maxChartHours) * plotHeight;
    final dashPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.65)
      ..strokeWidth = 1.25;
    const dashW = 5.0;
    const dashGap = 4.0;
    double x = plotLeft;
    while (x < plotRight) {
      final endX = math.min(x + dashW, plotRight);
      canvas.drawLine(Offset(x, targetY), Offset(endX, targetY), dashPaint);
      x += dashW + dashGap;
    }

    final refText =
        'Default ${TimelineSnapshot.formatHoursShort(defaultTargetMin)}';
    final refTp = TextPainter(
      text: TextSpan(
        text: refText,
        style: textStyle.copyWith(
          color: primaryColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final refBgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        plotRight - refTp.width - 8,
        math.max(0, targetY - refTp.height - 4),
        refTp.width + 8,
        refTp.height + 2,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      refBgRect,
      Paint()..color = surfaceColor.withValues(alpha: 0.85),
    );
    refTp.paint(canvas, Offset(refBgRect.left + 4, refBgRect.top + 1));

    if (buckets.isEmpty) return;

    final slotWidth = plotWidth / buckets.length;
    final barWidth = (slotWidth * 0.58).clamp(4.0, 22.0);
    final radius = Radius.circular(math.min(6.0, barWidth / 2.0));

    for (int i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final cx = plotLeft + slotWidth * (i + 0.5);
      final isSelected = selectedIndex == i;

      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              plotLeft + slotWidth * i + 1,
              plotTop,
              math.max(2, slotWidth - 2),
              plotHeight,
            ),
            const Radius.circular(6),
          ),
          Paint()..color = primaryColor.withValues(alpha: 0.10),
        );
      }

      if (bucket.status == DayFastStatus.none) {
        final dotRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, plotBottom - 2),
            width: math.min(barWidth, 6),
            height: 4,
          ),
          const Radius.circular(2),
        );
        canvas.drawRRect(dotRect, Paint()..color = emptyDotColor);
        if (isSelected) {
          canvas.drawRRect(
            dotRect,
            Paint()
              ..color = primaryColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      } else {
        final hours =
            (bucket.duration.inMinutes / 60.0).clamp(0.4, maxChartHours);
        final barHeight =
            math.max(6.0, (hours / maxChartHours) * plotHeight);
        final barRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            cx - barWidth / 2,
            plotBottom - barHeight,
            barWidth,
            barHeight,
          ),
          topLeft: radius,
          topRight: radius,
        );

        if (bucket.status == DayFastStatus.active) {
          canvas.drawRRect(
            barRect,
            Paint()..color = primaryColor.withValues(alpha: 0.18),
          );
          canvas.drawRRect(
            barRect,
            Paint()
              ..color = primaryColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSelected ? 2.2 : 1.5,
          );
        } else {
          final color = bucket.status == DayFastStatus.goalMet
              ? DurationBarChart.goalMetColor
              : DurationBarChart.endedEarlyColor;
          canvas.drawRRect(barRect, Paint()..color = color);
          if (isSelected) {
            canvas.drawRRect(
              barRect,
              Paint()
                ..color = primaryColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          }
        }
      }

      // X-axis tick labels
      if (_shouldPaintXLabel(i, buckets.length)) {
        final labelStyle = textStyle.copyWith(
          color: (bucket.isToday || isSelected) ? primaryColor : labelColor,
          fontSize: range == TimelineRange.d7 ? 10 : 9.5,
          fontWeight:
              (bucket.isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
          height: 1.15,
        );
        final labelWidth =
            range == TimelineRange.d7 ? slotWidth : math.max(slotWidth, 42.0);
        final left = (cx - labelWidth / 2).clamp(
          plotLeft - 4,
          size.width - labelWidth,
        );
        _paintText(
          canvas,
          bucket.axisLabel,
          labelStyle,
          Offset(left, plotBottom + 5),
          maxWidth: labelWidth,
          align: TextAlign.center,
        );
      }
    }
  }

  bool _shouldPaintXLabel(int index, int total) {
    if (range == TimelineRange.d7) return true;
    if (range == TimelineRange.d30) {
      return index == 0 ||
          index == 7 ||
          index == 14 ||
          index == 21 ||
          index == total - 1;
    }
    // TimelineRange.all (4..12 weekly bars)
    if (total <= 5) return true;
    return index == 0 || index == total ~/ 2 || index == total - 1;
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset offset, {
    required double maxWidth,
    required TextAlign align,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(minWidth: maxWidth, maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DurationBarPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.defaultTargetMin != defaultTargetMin ||
        oldDelegate.maxChartHours != maxChartHours ||
        oldDelegate.range != range ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.emptyDotColor != emptyDotColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}
