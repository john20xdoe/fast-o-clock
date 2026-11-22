import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fast_protocol.dart';
import '../models/fast_record.dart';
import '../services/database_service.dart';
import '../state/fasting_controller.dart';
import '../widgets/fast_editor_sheet.dart';

class TimelineScreen extends StatelessWidget {
  static final DateFormat _dayHeaderFmt = DateFormat('EEE, MMM d, yyyy');
  static final DateFormat _shortTimeFmt = DateFormat('h:mm a');
  static final DateFormat _weekdayLetterFmt = DateFormat('E');

  const TimelineScreen({super.key});

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FastingController>();
    final theme = Theme.of(context);
    final history = controller.history;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPastFast(context, controller),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Past Fast'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timeline & Stats',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryCard(context, controller),
                      ],
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete your first fast or tap "+ Add Past Fast" to log a previous fast.',
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
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
                    sliver: SliverList.builder(
                      itemCount: history.length,
                      itemBuilder: (ctx, index) {
                        final record = history[index];
                        return _buildHistoryCard(context, controller, record);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    FastingController controller,
  ) {
    final theme = Theme.of(context);
    final sevenDays = controller.lastSevenDaysSummary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  context,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF8A00),
                  value: '${controller.currentStreak}d',
                  label: 'Streak',
                ),
                _buildMetricItem(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF00C853),
                  value: '${controller.totalCompletedFasts}',
                  label: 'Total Fasts',
                ),
                _buildMetricItem(
                  context,
                  icon: Icons.schedule_rounded,
                  iconColor: theme.colorScheme.primary,
                  value: _formatDuration(controller.averageFastDuration),
                  label: 'Average',
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: sevenDays.map((day) {
                final dayLetter =
                    _weekdayLetterFmt.format(day.localDate).substring(0, 1);
                Color barColor;
                Border? border;
                switch (day.status) {
                  case DayFastStatus.goalMet:
                    barColor = const Color(0xFF00C853);
                    break;
                  case DayFastStatus.completedBelowGoal:
                    barColor = const Color(0xFFFF8A00);
                    break;
                  case DayFastStatus.active:
                    barColor = Colors.transparent;
                    border = Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    );
                    break;
                  case DayFastStatus.none:
                    barColor = theme.colorScheme.surfaceContainerHighest;
                    break;
                }
                return Column(
                  children: [
                    Container(
                      width: 18,
                      height: 36,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(9),
                        border: border,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLetter,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    FastingController controller,
    FastRecord record,
  ) {
    final theme = Theme.of(context);
    final protocol = FastProtocol.resolve(
      record.protocolId,
      customDurationMin: record.targetDurationMin,
    );
    final goalMet = record.isGoalMet;
    final statusColor =
        goalMet ? const Color(0xFF00C853) : const Color(0xFF90A4AE);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _editPastFast(context, controller, record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dayHeaderFmt
                        .format(record.endTimeLocal ?? record.startTimeLocal),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          protocol.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          goalMet ? 'Goal Met' : 'Ended Early',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(record.elapsedDuration()),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (record.endTimeLocal != null)
                    Text(
                      '${_shortTimeFmt.format(record.startTimeLocal)} → ${_shortTimeFmt.format(record.endTimeLocal!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (record.mood != null ||
                  (record.note != null && record.note!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (record.mood != null) ...[
                      Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.mood!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (record.note != null && record.note!.isNotEmpty)
                      Expanded(
                        child: Text(
                          record.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
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
