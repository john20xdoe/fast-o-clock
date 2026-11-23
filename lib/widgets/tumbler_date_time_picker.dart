import 'package:flutter/material.dart';

class TumblerDateTimePicker extends StatefulWidget {
  final DateTime initialDateTimeLocal;
  final ValueChanged<DateTime> onChanged;
  final int minYear;
  final int? maxYear;

  const TumblerDateTimePicker({
    super.key,
    required this.initialDateTimeLocal,
    required this.onChanged,
    this.minYear = 2020,
    this.maxYear,
  });

  static Future<DateTime?> showModal(
    BuildContext context, {
    required String title,
    required DateTime initialDateTimeLocal,
  }) {
    DateTime selected = initialDateTimeLocal;
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 340,
          child: TumblerDateTimePicker(
            initialDateTimeLocal: initialDateTimeLocal,
            onChanged: (dt) => selected = dt,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(selected),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  State<TumblerDateTimePicker> createState() => _TumblerDateTimePickerState();
}

class _TumblerDateTimePickerState extends State<TumblerDateTimePicker> {
  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  late final int _maxYear;
  late int _year;
  late int _month;
  late int _day;
  late bool _isPm;
  late int _hour12; // 1..12
  late int _minute; // 0..59

  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _amPmCtrl;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  bool _suppressAmPmSync = false;

  @override
  void initState() {
    super.initState();
    final dt = widget.initialDateTimeLocal;
    _maxYear = widget.maxYear ?? DateTime.now().year + 1;
    _year = dt.year.clamp(widget.minYear, _maxYear);
    _month = dt.month;
    _day = dt.day.clamp(1, DateUtils.getDaysInMonth(_year, _month));
    _isPm = dt.hour >= 12;
    _hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    _minute = dt.minute;

    _yearCtrl = FixedExtentScrollController(initialItem: _year - widget.minYear);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _amPmCtrl = FixedExtentScrollController(initialItem: _isPm ? 1 : 0);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _amPmCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  DateTime get _currentDateTime {
    final hour24 = _hour12 == 12 ? (_isPm ? 12 : 0) : (_isPm ? _hour12 + 12 : _hour12);
    return DateTime(_year, _month, _day, hour24, _minute);
  }

  void _emitChanged() {
    widget.onChanged(_currentDateTime);
  }

  void _clampDayIfNeeded() {
    final maxDays = DateUtils.getDaysInMonth(_year, _month);
    if (_day > maxDays) {
      _day = maxDays;
      _dayCtrl.jumpToItem(_day - 1);
    }
  }

  String get _weekdayLabel => _weekdays[_currentDateTime.weekday - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yearCount = _maxYear - widget.minYear + 1;
    final daysInMonth = DateUtils.getDaysInMonth(_year, _month);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 136,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildWheel(
                      controller: _yearCtrl,
                      itemCount: yearCount,
                      looping: false,
                      labelBuilder: (i) => '${widget.minYear + i}',
                      onChanged: (i) {
                        setState(() {
                          _year = widget.minYear + i;
                          _clampDayIfNeeded();
                        });
                        _emitChanged();
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildWheel(
                      controller: _monthCtrl,
                      itemCount: 12,
                      looping: true,
                      labelBuilder: (i) => (i + 1).toString().padLeft(2, '0'),
                      onChanged: (i) {
                        setState(() {
                          _month = (i % 12 + 12) % 12 + 1;
                          _clampDayIfNeeded();
                        });
                        _emitChanged();
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildWheel(
                      controller: _dayCtrl,
                      itemCount: daysInMonth,
                      looping: true,
                      labelBuilder: (i) => (i + 1).toString().padLeft(2, '0'),
                      onChanged: (i) {
                        setState(() {
                          _day = (i % daysInMonth + daysInMonth) % daysInMonth + 1;
                        });
                        _emitChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 48,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _weekdayLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'TIME',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 136,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildWheel(
                      controller: _amPmCtrl,
                      itemCount: 2,
                      looping: false,
                      labelBuilder: (i) => i == 0 ? 'AM' : 'PM',
                      onChanged: (i) {
                        if (_suppressAmPmSync) return;
                        setState(() {
                          _isPm = i == 1;
                        });
                        _emitChanged();
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildWheel(
                      controller: _hourCtrl,
                      itemCount: 12,
                      looping: true,
                      labelBuilder: (i) => (i + 1).toString().padLeft(2, '0'),
                      onChanged: (i) {
                        final nextHour = (i % 12 + 12) % 12 + 1;
                        final crossedBoundary =
                            (_hour12 == 11 && nextHour == 12) ||
                            (_hour12 == 12 && nextHour == 11);
                        setState(() {
                          _hour12 = nextHour;
                          if (crossedBoundary) {
                            _isPm = !_isPm;
                            _suppressAmPmSync = true;
                            _amPmCtrl.jumpToItem(_isPm ? 1 : 0);
                            _suppressAmPmSync = false;
                          }
                        });
                        _emitChanged();
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildWheel(
                      controller: _minuteCtrl,
                      itemCount: 60,
                      looping: true,
                      labelBuilder: (i) => i.toString().padLeft(2, '0'),
                      onChanged: (i) {
                        setState(() {
                          _minute = (i % 60 + 60) % 60;
                        });
                        _emitChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required bool looping,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    final childDelegate = looping
        ? ListWheelChildLoopingListDelegate(
            children: List.generate(
              itemCount,
              (i) => _wheelItem(theme, labelBuilder(i)),
            ),
          )
        : ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (_, i) => _wheelItem(theme, labelBuilder(i)),
          );

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 42,
      perspective: 0.003,
      diameterRatio: 1.5,
      useMagnifier: true,
      magnification: 1.16,
      overAndUnderCenterOpacity: 0.35,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: childDelegate,
    );
  }

  Widget _wheelItem(ThemeData theme, String text) {
    return Center(
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
