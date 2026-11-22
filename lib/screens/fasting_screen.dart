import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fast_record.dart';
import '../services/database_service.dart';
import '../state/fasting_controller.dart';
import '../widgets/fast_editor_sheet.dart';
import '../widgets/metabolic_badge.dart';
import '../widgets/protocol_picker.dart';
import '../widgets/timer_ring.dart';

class FastingScreen extends StatelessWidget {
  static final DateFormat _timeFmt = DateFormat('EEE, MMM d • h:mm a');

  const FastingScreen({super.key});

  String _formatHms(Duration d) {
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$hStr:$mStr:$sStr';
  }

  String _formatHoursMinutes(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FastingController>();
    final theme = Theme.of(context);
    final active = controller.activeFast;
    final protocol = controller.selectedProtocol;
    final nowUtc = controller.nowUtc;

    final isActive = active != null;
    final elapsed = active?.elapsedDuration(nowUtc) ?? Duration.zero;
    final remaining = active?.remainingDuration(nowUtc) ?? Duration.zero;
    final overGoal = active?.overGoalDuration(nowUtc) ?? Duration.zero;
    final progress = active?.progress(nowUtc) ?? 0.0;
    final isGoalMet = active?.isGoalMetAt(nowUtc) ?? false;
    final showRemaining = controller.settings.showRemainingTime;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Header: Title + Protocol selector chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Fast O'Clock",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'time to fast',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.tune_rounded, size: 18),
                      label: Text('${protocol.label} Preset'),
                      onPressed: () async {
                        final picked = await ProtocolPicker.show(
                          context,
                          selectedProtocolId: protocol.id,
                          currentCustomDurationMin: protocol.targetDurationMin,
                        );
                        if (picked != null) {
                          await controller.updateDefaultProtocol(
                            picked.protocolId,
                            customDurationMin: picked.targetDurationMin,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Main Circular Timer Ring
                TimerRing(
                  progress: progress,
                  isActive: isActive,
                  isGoalMet: isGoalMet,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        MetabolicBadge(
                          currentStage: controller.currentMetabolicStage,
                          elapsed: elapsed,
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => controller.toggleShowRemainingTime(),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  showRemaining && !isGoalMet
                                      ? 'Remaining (tap)'
                                      : 'Elapsed (${(progress * 100).round()}%)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatHms(
                                    showRemaining && !isGoalMet
                                        ? remaining
                                        : elapsed,
                                  ),
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isGoalMet)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${_formatHoursMinutes(overGoal)} past goal',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF00C853),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Goal: ${_formatHoursMinutes(Duration(minutes: active.targetDurationMin))}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ] else ...[
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ready to Fast',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Target: ${_formatHoursMinutes(Duration(minutes: protocol.targetDurationMin))}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (controller.lastCompletedFast?.endTimeLocal !=
                            null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last ended ${_formatHoursMinutes(nowUtc.difference(DateTime.fromMillisecondsSinceEpoch(controller.lastCompletedFast!.endTimeMs!, isUtc: true)))} ago',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Start & Target Summary Card when active
                if (isActive) ...[
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Started',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _timeFmt.format(active.startTimeLocal),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _editActiveStart(context, controller, active),
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Edit'),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Target End',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _timeFmt.format(active.targetEndTimeLocal),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                isGoalMet
                                    ? Icons.check_circle_rounded
                                    : Icons.flag_outlined,
                                color: isGoalMet
                                    ? const Color(0xFF00C853)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Primary CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: isActive && isGoalMet
                        ? FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.black,
                          )
                        : null,
                    onPressed: () {
                      if (!isActive) {
                        _startNewFast(context, controller);
                      } else {
                        _completeActiveFast(context, controller, active);
                      }
                    },
                    icon: Icon(
                      !isActive
                          ? Icons.play_arrow_rounded
                          : (isGoalMet
                              ? Icons.check_circle_outline_rounded
                              : Icons.stop_rounded),
                    ),
                    label: Text(
                      !isActive
                          ? 'Start Fast'
                          : (isGoalMet ? 'Complete Fast' : 'End Fast'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startNewFast(
    BuildContext context,
    FastingController controller,
  ) async {
    try {
      await controller.startFast();
    } on FastValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _editActiveStart(
    BuildContext context,
    FastingController controller,
    FastRecord active,
  ) async {
    final result = await FastEditorSheet.show(
      context,
      mode: FastEditorMode.editActiveStart,
      databaseService: controller.databaseService,
      recordId: active.id,
      initialProtocolId: active.protocolId,
      initialTargetDurationMin: active.targetDurationMin,
      initialStartTimeUtcMs: active.startTimeMs,
    );
    if (result == null) return;
    try {
      await controller.updateActiveFast(
        startTimeUtcMs: result.startTimeUtcMs,
        protocolId: result.protocolId,
        targetDurationMin: result.targetDurationMin,
      );
    } on FastValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _completeActiveFast(
    BuildContext context,
    FastingController controller,
    FastRecord active,
  ) async {
    final nowMs = controller.nowUtc.millisecondsSinceEpoch;
    final defaultEndMs =
        nowMs >= active.startTimeMs + 60000 ? nowMs : active.startTimeMs + 60000;
    final result = await FastEditorSheet.show(
      context,
      mode: FastEditorMode.completeActive,
      databaseService: controller.databaseService,
      recordId: active.id,
      initialProtocolId: active.protocolId,
      initialTargetDurationMin: active.targetDurationMin,
      initialStartTimeUtcMs: active.startTimeMs,
      initialEndTimeUtcMs: defaultEndMs,
      initialMood: active.mood,
      initialNote: active.note,
    );
    if (result == null) return;
    try {
      await controller.endActiveFast(
        startTimeUtcMs: result.startTimeUtcMs,
        endTimeUtcMs: result.endTimeUtcMs,
        protocolId: result.protocolId,
        targetDurationMin: result.targetDurationMin,
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
