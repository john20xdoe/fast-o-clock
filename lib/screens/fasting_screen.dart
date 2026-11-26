import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fast_protocol.dart';
import '../models/fast_record.dart';
import '../services/database_service.dart';
import '../state/fasting_controller.dart';
import '../widgets/app_brand_title.dart';
import '../widgets/fast_editor_sheet.dart';
import '../widgets/metabolic_badge.dart';
import '../widgets/protocol_picker.dart';
import '../widgets/timer_ring.dart';

class FastingScreen extends StatelessWidget {
  static final DateFormat _panelTimeFmt = DateFormat('h:mm a');
  static final DateFormat _panelDateFmt = DateFormat('MMM d • EEE');

  final void Function([String? recordId])? onOpenTimeline;

  const FastingScreen({super.key, this.onOpenTimeline});

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

  String _formatGoalDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    final hUnit = hours == 1 ? 'hour' : 'hours';
    final mUnit = mins == 1 ? 'min' : 'mins';
    if (hours == 0) return '$mins $mUnit';
    if (mins == 0) return '$hours $hUnit';
    return '$hours $hUnit $mins $mUnit';
  }

  ({Duration remaining, DateTime endLocal})? _eatingWindowState(
    FastingController controller,
    FastProtocol protocol,
    DateTime nowUtc,
  ) {
    final lastEndMs = controller.lastCompletedFast?.endTimeMs;
    if (lastEndMs == null || protocol.targetDurationMin >= 1440) {
      return null;
    }
    final eatingWindow = Duration(minutes: 1440 - protocol.targetDurationMin);
    final lastEndUtc =
        DateTime.fromMillisecondsSinceEpoch(lastEndMs, isUtc: true);
    final elapsed = nowUtc.difference(lastEndUtc);
    final remaining = eatingWindow - elapsed;
    if (remaining <= Duration.zero) {
      return null;
    }
    return (
      remaining: remaining,
      endLocal: lastEndUtc.add(eatingWindow).toLocal(),
    );
  }

  String _formatRelativePhrase(DateTime targetLocal, DateTime nowLocal) {
    final diff = targetLocal.difference(nowLocal);
    final isPast = diff.isNegative;
    final abs = diff.abs();

    if (abs.inSeconds < 60) {
      return isPast ? 'just now' : 'in < 1 min';
    }
    if (abs.inMinutes < 60) {
      final m = abs.inMinutes;
      return isPast ? '$m min ago' : 'in $m min';
    }

    final targetDay =
        DateTime(targetLocal.year, targetLocal.month, targetLocal.day);
    final nowDay = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final dayDiff = targetDay.difference(nowDay).inDays;
    final h = abs.inHours;

    if (dayDiff == -1 && h >= 6) return 'yesterday';
    if (dayDiff == 1 && h >= 6) return 'tomorrow';

    final unit = h == 1 ? 'hr' : 'hrs';
    return isPast ? '$h $unit ago' : 'in $h $unit';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FastingController>();
    final theme = Theme.of(context);
    final active = controller.activeFast;
    final protocol = controller.selectedProtocol;
    final showRemaining = controller.settings.showRemainingTime;
    final lastFast = controller.lastCompletedFast;

    return SafeArea(
      child: ValueListenableBuilder<DateTime>(
        valueListenable: controller.clockTick,
        builder: (context, _, _) {
          final nowUtc = controller.nowUtc;
          final isActive = active != null;
          final elapsed = active?.elapsedDuration(nowUtc) ?? Duration.zero;
          final remaining = active?.remainingDuration(nowUtc) ?? Duration.zero;
          final overGoal = active?.overGoalDuration(nowUtc) ?? Duration.zero;
          final progress = active?.progress(nowUtc) ?? 0.0;
          final isGoalMet = active?.isGoalMetAt(nowUtc) ?? false;

          return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = math.min(constraints.maxWidth, 560.0);
          final ringSize = (availableWidth * 0.75).clamp(220.0, 360.0);

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top: Brand Title
                          const AppBrandTitle(),

                          // Middle: Circular Timer Ring (75% width, offset ~25% above center when idle)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: isActive ? 0 : constraints.maxHeight * 0.08,
                            ),
                            child: TimerRing(
                              size: ringSize,
                              progress: progress,
                              isActive: isActive,
                              isGoalMet: isGoalMet,
                              isCountdown: showRemaining,
                              child: isActive
                                  ? SizedBox.expand(
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isGoalMet)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF00C853)
                                                          .withValues(
                                                              alpha: 0.18),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      '+${_formatHoursMinutes(overGoal)} past goal',
                                                      style: theme
                                                          .textTheme.labelSmall
                                                          ?.copyWith(
                                                        color: const Color(
                                                            0xFF00C853),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Text(
                                                    'Goal: ${_formatGoalDuration(Duration(minutes: active.targetDurationMin))}',
                                                    style: theme
                                                        .textTheme.labelMedium
                                                        ?.copyWith(
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                const SizedBox(height: 6),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    _formatHms(showRemaining
                                                        ? remaining
                                                        : elapsed),
                                                    style: theme.textTheme
                                                        .headlineMedium
                                                        ?.copyWith(
                                                      fontSize: 42,
                                                      height: 1.1,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontVariations: const [
                                                        FontVariation.weight(
                                                            700),
                                                      ],
                                                      fontFeatures: const [
                                                        FontFeature
                                                            .tabularFigures(),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                InkWell(
                                                  onTap: () => controller
                                                      .toggleShowRemainingTime(),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'Elapsed',
                                                          style: theme.textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                            fontWeight:
                                                                !showRemaining
                                                                    ? FontWeight
                                                                        .w700
                                                                    : FontWeight
                                                                        .w400,
                                                            color: !showRemaining
                                                                ? const Color(
                                                                    0xFFFF8A00)
                                                                : theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant
                                                                    .withValues(
                                                                        alpha:
                                                                            0.5),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 6,
                                                          ),
                                                          child: Icon(
                                                            Icons
                                                                .swap_horiz_rounded,
                                                            size: 14,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant
                                                                .withValues(
                                                                    alpha:
                                                                        0.65),
                                                          ),
                                                        ),
                                                        Text(
                                                          'Remaining',
                                                          style: theme.textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                            fontWeight:
                                                                showRemaining
                                                                    ? FontWeight
                                                                        .w700
                                                                    : FontWeight
                                                                        .w400,
                                                            color: showRemaining
                                                                ? const Color(
                                                                    0xFFFF5252)
                                                                : theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant
                                                                    .withValues(
                                                                        alpha:
                                                                            0.5),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 12,
                                            left: 28,
                                            right: 28,
                                            child: Center(
                                              child: MetabolicBadge(
                                                currentStage: controller
                                                    .currentMetabolicStage,
                                                elapsed: elapsed,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Builder(
                                      builder: (context) {
                                        final eatingState = _eatingWindowState(
                                          controller,
                                          protocol,
                                          nowUtc,
                                        );
                                        if (eatingState != null) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.restaurant_rounded,
                                                size: 56,
                                                color: theme.colorScheme.primary,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Your time to eat',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatHoursMinutes(
                                                  eatingState.remaining,
                                                ),
                                                style: theme
                                                    .textTheme.headlineSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontFeatures: const [
                                                    FontFeature
                                                        .tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Until: ${_panelTimeFmt.format(eatingState.endLocal)}',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.restaurant_rounded,
                                              size: 72,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Ready to Fast?',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Goal: ${_formatGoalDuration(Duration(minutes: protocol.targetDurationMin))}',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ),

                          // Bottom: Start/Target End Panel (when active) + Preset Pill & Primary CTA Row
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive) ...[
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () =>
                                            _editActiveStart(context, controller, active),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text.rich(
                                                      TextSpan(
                                                        style: theme.textTheme.labelSmall
                                                            ?.copyWith(
                                                          color: theme.colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                        children: [
                                                          const TextSpan(
                                                            text: 'Started ',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: _formatRelativePhrase(
                                                              active.startTimeLocal,
                                                              nowUtc.toLocal(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          _panelTimeFmt.format(
                                                            active.startTimeLocal,
                                                          ),
                                                          style: theme.textTheme.bodyMedium
                                                              ?.copyWith(
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                        Text(
                                                          _panelDateFmt
                                                              .format(
                                                                active.startTimeLocal,
                                                              )
                                                              .toUpperCase(),
                                                          style: theme.textTheme.labelSmall
                                                              ?.copyWith(
                                                            color: theme.colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              SizedBox(
                                                width: 24,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.edit_rounded,
                                                    size: 16,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      InkWell(
                                        onTap: () =>
                                            _editActiveStart(context, controller, active),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text.rich(
                                                      TextSpan(
                                                        style: theme.textTheme.labelSmall
                                                            ?.copyWith(
                                                          color: theme.colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                        children: [
                                                          const TextSpan(
                                                            text: 'Target End ',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: _formatRelativePhrase(
                                                              active.targetEndTimeLocal,
                                                              nowUtc.toLocal(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          _panelTimeFmt.format(
                                                            active.targetEndTimeLocal,
                                                          ),
                                                          style: theme.textTheme.bodyMedium
                                                              ?.copyWith(
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                        Text(
                                                          _panelDateFmt
                                                              .format(
                                                                active.targetEndTimeLocal,
                                                              )
                                                              .toUpperCase(),
                                                          style: theme.textTheme.labelSmall
                                                              ?.copyWith(
                                                            color: theme.colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              SizedBox(
                                                width: 24,
                                                child: Center(
                                                  child: Icon(
                                                    isGoalMet
                                                        ? Icons.flag_rounded
                                                        : Icons.flag_outlined,
                                                    color: isGoalMet
                                                        ? const Color(0xFF00C853)
                                                        : theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ] else if (lastFast?.endTimeMs != null) ...[
                                InkWell(
                                  onTap: () => onOpenTimeline?.call(lastFast.id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history_rounded,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Last fast ended ${_formatHoursMinutes(nowUtc.difference(DateTime.fromMillisecondsSinceEpoch(lastFast!.endTimeMs!, isUtc: true)))} ago',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Row(
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.tune_rounded, size: 18),
                                    label: Text('${protocol.label} Preset'),
                                    onPressed: () async {
                                      final picked = await ProtocolPicker.show(
                                        context,
                                        selectedProtocolId: protocol.id,
                                        currentCustomDurationMin:
                                            protocol.targetDurationMin,
                                      );
                                      if (picked != null) {
                                        await controller.updateDefaultProtocol(
                                          picked.protocolId,
                                          customDurationMin: picked.targetDurationMin,
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: 54,
                                      child: isActive && isGoalMet
                                          ? FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF00C853),
                                                foregroundColor: Colors.black,
                                              ),
                                              onPressed: () => _completeActiveFast(
                                                context,
                                                controller,
                                                active,
                                              ),
                                              child: const Text(
                                                'Fast Complete?',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          : FilledButton.icon(
                                              onPressed: () {
                                                if (!isActive) {
                                                  _startNewFast(
                                                      context, controller);
                                                } else {
                                                  _completeActiveFast(
                                                    context,
                                                    controller,
                                                    active,
                                                  );
                                                }
                                              },
                                              icon: Icon(
                                                !isActive
                                                    ? Icons.play_circle_outline_rounded
                                                    : Icons.stop_circle_outlined,
                                              ),
                                              label: Text(
                                                !isActive
                                                    ? 'Begin Fast'
                                                    : 'End Fast',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
        },
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

  Future<void> _confirmAndDiscardActive(
    BuildContext context,
    FastingController controller,
    FastRecord active,
  ) async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Ongoing Fast?'),
        content: const Text(
          'This in-progress fast will be discarded and not saved to your timeline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteFastRecord(active.id);
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
    if (result.deleteRequested) {
      if (!context.mounted) return;
      await _confirmAndDiscardActive(context, controller, active);
      return;
    }
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
    final result = await FastEditorSheet.show(
      context,
      mode: FastEditorMode.completeActive,
      databaseService: controller.databaseService,
      recordId: active.id,
      initialProtocolId: active.protocolId,
      initialTargetDurationMin: active.targetDurationMin,
      initialStartTimeUtcMs: active.startTimeMs,
      initialEndTimeUtcMs: nowMs,
      initialMood: active.mood,
      initialNote: active.note,
    );
    if (result == null) return;
    if (result.deleteRequested) {
      if (!context.mounted) return;
      await _confirmAndDiscardActive(context, controller, active);
      return;
    }
    try {
      await controller.endActiveFast(
        startTimeUtcMs: result.startTimeUtcMs,
        endTimeUtcMs: result.endTimeUtcMs,
        protocolId: result.protocolId,
        targetDurationMin: result.targetDurationMin,
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
