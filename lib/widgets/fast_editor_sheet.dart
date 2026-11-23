import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fast_protocol.dart';
import '../services/database_service.dart';
import 'protocol_picker.dart';

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
  final bool deleteRequested;

  const FastEditorResult({
    required this.protocolId,
    required this.targetDurationMin,
    required this.startTimeUtcMs,
    this.endTimeUtcMs,
    this.mood,
    this.note,
    this.deleteRequested = false,
  });
}

class FastEditorSheet extends StatefulWidget {
  final FastEditorMode mode;
  final DatabaseService databaseService;
  final String? recordId;
  final String initialProtocolId;
  final int initialTargetDurationMin;
  final int initialStartTimeUtcMs;
  final int? initialEndTimeUtcMs;
  final String? initialMood;
  final String? initialNote;
  final DateTime Function()? clockUtc;

  const FastEditorSheet({
    super.key,
    required this.mode,
    required this.databaseService,
    this.recordId,
    required this.initialProtocolId,
    required this.initialTargetDurationMin,
    required this.initialStartTimeUtcMs,
    this.initialEndTimeUtcMs,
    this.initialMood,
    this.initialNote,
    this.clockUtc,
  });

  static Future<FastEditorResult?> show(
    BuildContext context, {
    required FastEditorMode mode,
    required DatabaseService databaseService,
    String? recordId,
    required String initialProtocolId,
    required int initialTargetDurationMin,
    required int initialStartTimeUtcMs,
    int? initialEndTimeUtcMs,
    String? initialMood,
    String? initialNote,
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
        clockUtc: clockUtc,
      ),
    );
  }

  @override
  State<FastEditorSheet> createState() => _FastEditorSheetState();
}

class _FastEditorSheetState extends State<FastEditorSheet> {
  static final DateFormat _dateTimeFmt = DateFormat('EEE, MMM d • h:mm a');

  late String _protocolId;
  late int _targetDurationMin;
  late int _startTimeUtcMs;
  late int? _endTimeUtcMs;
  String? _mood;
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
        ? (widget.initialEndTimeUtcMs ?? _nowUtc.millisecondsSinceEpoch)
        : null;
    _mood = widget.initialMood;
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _runLiveValidation();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _runLiveValidation() async {
    setState(() {
      _isValidating = true;
    });

    final nowMs = _nowUtc.millisecondsSinceEpoch;
    String? error;

    if (_startTimeUtcMs > nowMs) {
      error = 'Start time cannot be in the future.';
    } else if (_showsEndTime && _endTimeUtcMs != null) {
      if (_endTimeUtcMs! > nowMs) {
        error = 'End time cannot be in the future.';
      } else if (_endTimeUtcMs! < _startTimeUtcMs + 60000) {
        error = 'End time must be at least 1 minute after start time.';
      }
    }

    if (error == null) {
      final conflict = await widget.databaseService.findOverlappingRecord(
        candidateStartMs: _startTimeUtcMs,
        candidateEndMs: _showsEndTime ? _endTimeUtcMs : null,
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
    final currentMs =
        isStart ? _startTimeUtcMs : (_endTimeUtcMs ?? _nowUtc.millisecondsSinceEpoch);
    final currentLocal =
        DateTime.fromMillisecondsSinceEpoch(currentMs, isUtc: true).toLocal();
    final nowLocal = _nowUtc.toLocal();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentLocal.isAfter(nowLocal) ? nowLocal : currentLocal,
      firstDate: DateTime(2020),
      lastDate: nowLocal.add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentLocal),
    );
    if (pickedTime == null || !mounted) return;

    final combinedLocal = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final newUtcMs = combinedLocal.toUtc().millisecondsSinceEpoch;

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
        return 'Edit Active Fast';
      case FastEditorMode.completeActive:
        return 'Complete Fast';
      case FastEditorMode.editPast:
        return 'Edit Fast Record';
      case FastEditorMode.addPast:
        return 'Add Past Fast';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protocol = FastProtocol.resolve(
      _protocolId,
      customDurationMin: _targetDurationMin,
    );
    final startLocal =
        DateTime.fromMillisecondsSinceEpoch(_startTimeUtcMs, isUtc: true)
            .toLocal();
    final endLocal = _endTimeUtcMs != null
        ? DateTime.fromMillisecondsSinceEpoch(_endTimeUtcMs!, isUtc: true)
            .toLocal()
        : null;

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
                  if (widget.mode != FastEditorMode.addPast)
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          FastEditorResult(
                            protocolId: _protocolId,
                            targetDurationMin: _targetDurationMin,
                            startTimeUtcMs: _startTimeUtcMs,
                            endTimeUtcMs: _endTimeUtcMs,
                            deleteRequested: true,
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: widget.mode == FastEditorMode.editPast
                          ? 'Delete Fast'
                          : 'Discard Fast',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Protocol'),
                subtitle: Text(protocol.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
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
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: const Text('Start Time'),
                subtitle: Text(_dateTimeFmt.format(startLocal)),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () => _pickDateTime(isStart: true),
              ),
              if (_showsEndTime && endLocal != null) ...[
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  leading: const Icon(Icons.stop_circle_outlined),
                  title: const Text('End Time'),
                  subtitle: Text(_dateTimeFmt.format(endLocal)),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: () => _pickDateTime(isStart: false),
                ),
              ],
              if (_showsMoodAndNote) ...[
                const SizedBox(height: 16),
                Text(
                  'How did you feel?',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildMoodChip('great', 'Great'),
                    _buildMoodChip('good', 'Good'),
                    _buildMoodChip('okay', 'Okay'),
                    _buildMoodChip('hard', 'Hard'),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  maxLength: 280,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Optional Note',
                    hintText: 'Add a quick note about this fast...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_validationError != null || _isValidating)
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            FastEditorResult(
                              protocolId: _protocolId,
                              targetDurationMin: _targetDurationMin,
                              startTimeUtcMs: _startTimeUtcMs,
                              endTimeUtcMs: _endTimeUtcMs,
                              mood: _mood,
                              note: _noteController.text.trim().isEmpty
                                  ? null
                                  : _noteController.text.trim(),
                            ),
                          );
                        },
                  child: Text(
                    widget.mode == FastEditorMode.completeActive
                        ? 'Save Completed Fast'
                        : 'Save',
                  ),
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
}
