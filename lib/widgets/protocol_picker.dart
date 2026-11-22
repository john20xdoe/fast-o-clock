import 'package:flutter/material.dart';

import '../models/fast_protocol.dart';

class ProtocolPickerResult {
  final String protocolId;
  final int targetDurationMin;

  const ProtocolPickerResult({
    required this.protocolId,
    required this.targetDurationMin,
  });
}

class ProtocolPicker extends StatefulWidget {
  final String selectedProtocolId;
  final int currentCustomDurationMin;

  const ProtocolPicker({
    super.key,
    required this.selectedProtocolId,
    required this.currentCustomDurationMin,
  });

  static Future<ProtocolPickerResult?> show(
    BuildContext context, {
    required String selectedProtocolId,
    required int currentCustomDurationMin,
  }) {
    return showModalBottomSheet<ProtocolPickerResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ProtocolPicker(
        selectedProtocolId: selectedProtocolId,
        currentCustomDurationMin: currentCustomDurationMin,
      ),
    );
  }

  @override
  State<ProtocolPicker> createState() => _ProtocolPickerState();
}

class _ProtocolPickerState extends State<ProtocolPicker> {
  late String _selectedId;
  late int _customHours;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedProtocolId;
    _customHours = (widget.currentCustomDurationMin ~/ 60).clamp(1, 168);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Fasting Protocol',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...FastProtocol.presets.map((preset) {
                final isSelected = _selectedId == preset.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.4)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          )
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).pop(
                        ProtocolPickerResult(
                          protocolId: preset.id,
                          targetDurationMin: preset.targetDurationMin,
                        ),
                      );
                    },
                    title: Text(
                      preset.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(preset.description),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                );
              }),
              const Divider(height: 24),
              Text(
                'Custom Duration ($_customHours hours)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Slider(
                value: _customHours.toDouble(),
                min: 1,
                max: 72,
                divisions: 71,
                label: '${_customHours}h',
                onChanged: (value) {
                  setState(() {
                    _selectedId = 'custom';
                    _customHours = value.round();
                  });
                },
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).pop(
                      ProtocolPickerResult(
                        protocolId: 'custom',
                        targetDurationMin: _customHours * 60,
                      ),
                    );
                  },
                  child: Text('Use Custom (${_customHours}h)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
