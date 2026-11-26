import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fast_protocol.dart';
import '../services/database_service.dart';
import 'protocol_picker.dart';
import 'tumbler_date_time_picker.dart';

enum FastEditorMode {
  editActiveStart,
  completeActive,
  editPast,
  addPast,
}

class FastEditorResult {
  final String protocolId;
  final int targetDurationMin;
  final int startTimeUtcMs;
  final int? endTimeUtcMs;
  final String? mood;
  final String? note;
  final bool isClean;
  final String? endReason;
  final bool deleteRequested;

  const FastEditorResult({
    required this.protocolId,
    required this.targetDurationMin,
    required this.startTimeUtcMs,
    this.endTimeUtcMs,
    this.mood,
    this.note,
    this.isClean = true,
    this.endReason,
    this.deleteRequested = false,
  });
}

class FastEditorSheet extends StatefulWidget {
  final FastEditorMode mode;
  final DatabaseService databaseService;
  final String? recordId;
  final String initialProtocolId;
  final int initialTargetDurationMin;
  final int? initialStartTimeUtcMs;
  final int? initialEndTimeUtcMs;
  final String? initialMood;
  final String? initialNote;
  final bool initialIsClean;
  final String? initialEndReason;
  final DateTime Function()? clockUtc;

  const FastEditorSheet({
    super.key,
    required this.mode,
    required this.databaseService,
    this.recordId,
    required this.initialProtocolId,
    required this.initialTargetDurationMin,
    this.initialStartTimeUtcMs,
    this.initialEndTimeUtcMs,
    this.initialMood,
    this.initialNote,
    this.initialIsClean = true,
    this.initialEndReason,
    this.clockUtc,
  });

  static Future<FastEditorResult?> show(
    BuildContext context, {
    required FastEditorMode mode,
    required DatabaseService databaseService,
    String? recordId,
    required String initialProtocolId,
    required int initialTargetDurationMin,
    int? initialStartTimeUtcMs,
    int? initialEndTimeUtcMs,
    String? initialMood,
    String? initialNote,
    bool initialIsClean = true,
    String? initialEndReason,
    DateTime Function()? clockUtc,
  }) {
    return showModalBottomSheet<FastEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FastEditorSheet(
        mode: mode,
        databaseService: databaseService,
        recordId: recordId,
        initialProtocolId: initialProtocolId,
        initialTargetDurationMin: initialTargetDurationMin,
        initialStartTimeUtcMs: initialStartTimeUtcMs,
        initialEndTimeUtcMs: initialEndTimeUtcMs,
        initialMood: initialMood,
        initialNote: initialNote,
        initialIsClean: initialIsClean,
        initialEndReason: initialEndReason,
        clockUtc: clockUtc,
      ),
    );
  }

  @override
  State<FastEditorSheet> createState() => _FastEditorSheetState();
}

class _FastEditorSheetState extends State<FastEditorSheet> {
  static final DateFormat _dateTimeFmt = DateFormat('EEE, MMM d • h:mm a');
  static final DateFormat _panelTimeFmt = DateFormat('h:mm a');
  static final DateFormat _panelDateFmt = DateFormat('MMM d • EEE');

  late String _protocolId;
  late int _targetDurationMin;
  late int? _startTimeUtcMs;
  late int? _endTimeUtcMs;
  String? _mood;
  late bool _isClean;
  String? _endReason;
  late bool _showNoteField;
  late TextEditingController _noteController;

  String? _validationError;
  bool _isValidating = false;

  bool get _showsEndTime => widget.mode != FastEditorMode.editActiveStart;
  bool get _showsMoodAndNote => widget.mode != FastEditorMode.editActiveStart;

  DateTime get _nowUtc =>
      widget.clockUtc != null ? widget.clockUtc!() : DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _protocolId = widget.initialProtocolId;
    _targetDurationMin = widget.initialTargetDurationMin;
    _startTimeUtcMs = widget.initialStartTimeUtcMs;
    _endTimeUtcMs = _showsEndTime
        ? (widget.initialEndTimeUtcMs ??
            (widget.mode == FastEditorMode.addPast
                ? null
                : _nowUtc.millisecondsSinceEpoch))
        : null;
    _mood = widget.initialMood;
    _isClean = widget.initialIsClean;
    _endReason = widget.initialEndReason;
    final initialNote = widget.initialNote ?? '';
    _showNoteField = initialNote.trim().isNotEmpty;
    _noteController = TextEditingController(text: initialNote);
    _runLiveValidation();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _runLiveValidation() async {
    final startMs = _startTimeUtcMs;
    final endMs = _endTimeUtcMs;
    if (startMs == null || (_showsEndTime && endMs == null)) {
      if (!mounted) return;
      setState(() {
        _validationError = null;
        _isValidating = false;
      });
      return;
    }

    setState(() {
      _isValidating = true;
    });

    final nowMs = _nowUtc.millisecondsSinceEpoch;
    String? error;

    if (startMs > nowMs) {
      error = 'Start time cannot be in the future.';
    } else if (_showsEndTime && endMs != null) {
      if (endMs > nowMs) {
        error = 'End time cannot be in the future.';
      } else if (endMs < startMs + DatabaseService.minCompletedFastDurationMs) {
        error = DatabaseService.minCompletedFastDurationError;
      }
    }

    if (error == null) {
      final conflict = await widget.databaseService.findOverlappingRecord(
        candidateStartMs: startMs,
        candidateEndMs: _showsEndTime ? endMs : null,
        nowUtcMs: nowMs,
        excludeId: widget.recordId,
      );
      if (conflict != null) {
        final p = FastProtocol.resolve(
          conflict.protocolId,
          customDurationMin: conflict.targetDurationMin,
        );
        final sStr = _dateTimeFmt.format(conflict.startTimeLocal);
        final eStr = conflict.endTimeLocal != null
            ? _dateTimeFmt.format(conflict.endTimeLocal!)
            : 'Active';
        error = 'Overlaps with ${p.label} fast ($sStr – $eStr)';
      }
    }

    if (!mounted) return;
    setState(() {
      _validationError = error;
      _isValidating = false;
    });
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final nowMs = _nowUtc.millisecondsSinceEpoch;
    final int currentMs;
    if (isStart) {
      currentMs = _startTimeUtcMs ??
          ((_endTimeUtcMs ?? nowMs) - _targetDurationMin * 60000);
    } else {
      currentMs = _endTimeUtcMs ?? nowMs;
    }
    final currentLocal =
        DateTime.fromMillisecondsSinceEpoch(currentMs, isUtc: true).toLocal();

    final pickedLocal = await TumblerDateTimePicker.showModal(
      context,
      title: isStart ? 'Start Time' : 'End Time',
      initialDateTimeLocal: currentLocal,
    );
    if (pickedLocal == null || !mounted) return;

    final newUtcMs = pickedLocal.toUtc().millisecondsSinceEpoch;
    setState(() {
      if (isStart) {
        _startTimeUtcMs = newUtcMs;
      } else {
        _endTimeUtcMs = newUtcMs;
      }
    });
    await _runLiveValidation();
  }

  String get _title {
    switch (widget.mode) {
      case FastEditorMode.editActiveStart:
        return 'Edit Ongoing Fast';
      case FastEditorMode.completeActive:
        return 'Break your fast:';
      case FastEditorMode.editPast:
        return 'Edit Fast Record';
      case FastEditorMode.addPast:
        return 'Add Past Fast';
    }
  }

  void _requestDelete() {
    Navigator.of(context).pop(
      FastEditorResult(
        protocolId: _protocolId,
        targetDurationMin: _targetDurationMin,
        startTimeUtcMs: _startTimeUtcMs ?? 0,
        endTimeUtcMs: _endTimeUtcMs,
        deleteRequested: true,
      ),
    );
  }

  Widget _buildTimePanel(
    ThemeData theme, {
    required String label,
    required DateTime? localTime,
    String placeholder = 'Not set',
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (localTime != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _panelTimeFmt.format(localTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _panelDateFmt.format(localTime).toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    placeholder,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: onTap != null
                ? Center(
                    child: Icon(
                      Icons.edit_calendar_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  Widget _buildValidationSlot(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: SizedBox(
        width: double.infinity,
        child: _validationError != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditOngoing = widget.mode == FastEditorMode.editActiveStart;
    final isCompleteActive = widget.mode == FastEditorMode.completeActive;
    final hasBottomDelete = isEditOngoing || isCompleteActive;
    final protocol = FastProtocol.resolve(
      _protocolId,
      customDurationMin: _targetDurationMin,
    );
    final startLocal = _startTimeUtcMs != null
        ? DateTime.fromMillisecondsSinceEpoch(_startTimeUtcMs!, isUtc: true)
            .toLocal()
        : null;
    final endLocal = _endTimeUtcMs != null
        ? DateTime.fromMillisecondsSinceEpoch(_endTimeUtcMs!, isUtc: true)
            .toLocal()
        : null;
    final hasRequiredTimes =
        _startTimeUtcMs != null && (!_showsEndTime || _endTimeUtcMs != null);
    final canSave =
        hasRequiredTimes && _validationError == null && !_isValidating;
    final metGoal = !hasRequiredTimes ||
        ((_endTimeUtcMs ?? _nowUtc.millisecondsSinceEpoch) - _startTimeUtcMs!) >=
            _targetDurationMin * 60000;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!hasBottomDelete && widget.mode != FastEditorMode.addPast)
                    IconButton(
                      onPressed: _requestDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Delete Fast',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isEditOngoing) ...[
                TumblerDateTimePicker(
                  initialDateTimeLocal: startLocal ?? _nowUtc.toLocal(),
                  onChanged: (pickedLocal) {
                    setState(() {
                      _startTimeUtcMs = pickedLocal.toUtc().millisecondsSinceEpoch;
                    });
                    _runLiveValidation();
                  },
                ),
              ] else if (isCompleteActive) ...[
                Chip(
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  label: Text('${protocol.label} Preset'),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (startLocal != null)
                        _buildTimePanel(
                          theme,
                          label: 'Start Time',
                          localTime: startLocal,
                        ),
                      if (endLocal != null) ...[
                        const Divider(height: 1),
                        _buildTimePanel(
                          theme,
                          label: 'End Time',
                          localTime: endLocal,
                          onTap: () => _pickDateTime(isStart: false),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildValidationSlot(theme),
              ] else ...[
                Text(
                  'Target Hours',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final preset in FastProtocol.presets) ...[
                        ChoiceChip(
                          label: Text('${preset.targetDurationMin ~/ 60}h'),
                          selected: _protocolId == preset.id,
                          onSelected: (_) {
                            setState(() {
                              _protocolId = preset.id;
                              _targetDurationMin = preset.targetDurationMin;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      ChoiceChip(
                        label: Text(
                          _protocolId == 'custom'
                              ? protocol.label
                              : 'Custom',
                        ),
                        selected: _protocolId == 'custom',
                        onSelected: (_) async {
                          final picked = await ProtocolPicker.show(
                            context,
                            selectedProtocolId: _protocolId,
                            currentCustomDurationMin: _targetDurationMin,
                          );
                          if (picked != null) {
                            setState(() {
                              _protocolId = picked.protocolId;
                              _targetDurationMin = picked.targetDurationMin;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _buildTimePanel(
                        theme,
                        label: 'Start Time',
                        localTime: startLocal,
                        placeholder: 'Select start time',
                        onTap: () => _pickDateTime(isStart: true),
                      ),
                      if (_showsEndTime) ...[
                        const Divider(height: 1),
                        _buildTimePanel(
                          theme,
                          label: 'End Time',
                          localTime: endLocal,
                          placeholder: 'Select end time',
                          onTap: () => _pickDateTime(isStart: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_showsMoodAndNote &&
                  _validationError !=
                      DatabaseService.minCompletedFastDurationError) ...[
                SizedBox(height: isCompleteActive ? 16 : 14),
                if (isCompleteActive) ...[
                  Text(
                    metGoal
                        ? 'You met your goal!'
                        : "You're ending early, but you can still try next time!",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: metGoal
                          ? const Color(0xFF00C853)
                          : const Color(0xFFFF8A00),
                      fontWeight: metGoal ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'How did this fasting feel?',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildMoodChip('great', 'Great!'),
                    _buildMoodChip('okay', 'Okay'),
                    _buildMoodChip('challenging', 'Challenging'),
                    _buildMoodChip('bad', 'Bad'),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Fast Quality',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: true, label: Text('Clean')),
                      ButtonSegment(value: false, label: Text('Modified')),
                    ],
                    selected: {_isClean},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _isClean = selection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isClean
                      ? 'Zero calories — water, black coffee, or plain tea only.'
                      : 'A tiny amount of calories (like milk in coffee or broth) — breaks a strict fast, but keeps daily calories low for fat loss.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!metGoal) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Early-End Reason',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildEndReasonChip('hungry', 'Hungry'),
                      _buildEndReasonChip('social', 'Social'),
                      _buildEndReasonChip('unwell', 'Dizzy / Unwell'),
                      _buildEndReasonChip('other', 'Other'),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (!_showNoteField)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showNoteField = true;
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add note'),
                  )
                else
                  TextField(
                    controller: _noteController,
                    maxLength: 280,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: 'Optional Note',
                      hintText: 'Optional notes to yourself...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.55),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
              if (!isCompleteActive) ...[
                const SizedBox(height: 8),
                _buildValidationSlot(theme),
              ],
              const SizedBox(height: 10),
              if (hasBottomDelete)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _requestDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: !canSave
                              ? null
                              : () {
                                  Navigator.of(context).pop(
                                    FastEditorResult(
                                      protocolId: _protocolId,
                                      targetDurationMin: _targetDurationMin,
                                      startTimeUtcMs: _startTimeUtcMs!,
                                      endTimeUtcMs: _endTimeUtcMs,
                                      mood: _mood,
                                      note: _noteController.text.trim().isEmpty
                                          ? null
                                          : _noteController.text.trim(),
                                      isClean: _isClean,
                                      endReason: metGoal ? null : _endReason,
                                    ),
                                  );
                                },
                          child: Text(
                            isCompleteActive ? 'Save to Timeline' : 'Save',
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: !canSave
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              FastEditorResult(
                                protocolId: _protocolId,
                                targetDurationMin: _targetDurationMin,
                                startTimeUtcMs: _startTimeUtcMs!,
                                endTimeUtcMs: _endTimeUtcMs,
                                mood: _mood,
                                note: _noteController.text.trim().isEmpty
                                    ? null
                                    : _noteController.text.trim(),
                                isClean: _isClean,
                                endReason: metGoal ? null : _endReason,
                              ),
                            );
                          },
                    child: const Text('Save'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodChip(String key, String label) {
    final selected = _mood == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        setState(() {
          _mood = val ? key : null;
        });
      },
    );
  }

  Widget _buildEndReasonChip(String key, String label) {
    final selected = _endReason == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        setState(() {
          _endReason = val ? key : null;
        });
      },
    );
  }
}
