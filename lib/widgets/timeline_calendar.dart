import 'package:flutter/material.dart';

import '../models/timeline_summary.dart';

class TimelineCalendar extends StatefulWidget {
  final String monthTitle;
  final List<CalendarDaySummary> days;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoNext;

  const TimelineCalendar({
    super.key,
    required this.monthTitle,
    required this.days,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.canGoNext = true,
  });

  @override
  State<TimelineCalendar> createState() => _TimelineCalendarState();
}

class _TimelineCalendarState extends State<TimelineCalendar> {
  static const List<String> _weekdays = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  DateTime? _selectedDate;

  @override
  void didUpdateWidget(covariant TimelineCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthTitle != widget.monthTitle) {
      _selectedDate = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.days.isEmpty) return const SizedBox.shrink();

    final leadingEmpty = widget.days.first.date.weekday - 1;
    final totalCells = leadingEmpty + widget.days.length;
    final rowCount = (totalCells / 7).ceil();

    CalendarDaySummary? selectedDay;
    if (_selectedDate != null) {
      for (final d in widget.days) {
        if (d.date == _selectedDate) {
          selectedDay = d;
          break;
        }
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onPreviousMonth,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    widget.monthTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.canGoNext ? widget.onNextMonth : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: _weekdays
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            for (int row = 0; row < rowCount; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: List.generate(7, (col) {
                    final cellIndex = row * 7 + col;
                    final dayIdx = cellIndex - leadingEmpty;
                    if (dayIdx < 0 || dayIdx >= widget.days.length) {
                      return const Expanded(child: SizedBox(height: 36));
                    }
                    final day = widget.days[dayIdx];
                    final isSelected = _selectedDate == day.date;
                    return Expanded(
                      child: _buildDayCell(theme, day, isSelected),
                    );
                  }),
                ),
              ),
            if (selectedDay != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${selectedDay.dayNumber} · ${selectedDay.tooltipLabel}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(
    ThemeData theme,
    CalendarDaySummary day,
    bool isSelected,
  ) {
    final Color? fillColor;
    final Color textColor;
    switch (day.status) {
      case CalendarDayStatus.goalMet:
        fillColor = goalMetColor;
        textColor = Colors.black;
      case CalendarDayStatus.endedEarly:
        fillColor = endedEarlyColor;
        textColor = Colors.black;
      case CalendarDayStatus.none:
        fillColor = null;
        textColor = theme.colorScheme.onSurface;
    }

    final Border? border;
    if (isSelected) {
      border = Border.all(color: theme.colorScheme.primary, width: 2);
    } else if (day.isToday || day.hasActiveFast) {
      border = Border.all(
        color: day.hasActiveFast
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
        width: 1.5,
      );
    } else {
      border = null;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Day ${day.dayNumber}: ${day.tooltipLabel}',
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDate = isSelected ? null : day.date;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 36,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
                border: border,
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.dayNumber}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: (day.status != CalendarDayStatus.none ||
                          day.isToday ||
                          isSelected)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
