import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/fast_protocol.dart';
import '../services/backup_service.dart';
import '../state/fasting_controller.dart';
import '../widgets/protocol_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FastingController>();
    final settings = controller.settings;
    final theme = Theme.of(context);
    final defaultProtocol = FastProtocol.resolve(
      settings.defaultProtocolId,
      customDurationMin: settings.customDurationMin,
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Section 1: Fasting Preferences
              _buildSectionTitle(context, 'Fasting Preferences'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Fasting Patterns'),
                  subtitle: Text(defaultProtocol.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final picked = await ProtocolPicker.show(
                      context,
                      selectedProtocolId: settings.defaultProtocolId,
                      currentCustomDurationMin: settings.customDurationMin,
                    );
                    if (picked != null) {
                      await controller.updateDefaultProtocol(
                        picked.protocolId,
                        customDurationMin: picked.targetDurationMin,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Notifications
              _buildSectionTitle(context, 'Notifications'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Fasting Goal Reached'),
                      subtitle: const Text(
                        'Notify when your target fasting duration is complete',
                      ),
                      value: settings.notifyGoalReached,
                      onChanged: (val) => controller.setNotifyGoalReached(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.restaurant_outlined),
                      title: const Text('Eating Window Ending'),
                      subtitle: const Text(
                        'Reminds you to start your next fast for protocols under 24h',
                      ),
                      value: settings.notifyEatingWindow,
                      onChanged: (val) => controller.setNotifyEatingWindow(val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 3: Appearance
              _buildSectionTitle(context, 'Appearance'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Mode',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'dark',
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                            ButtonSegment(
                              value: 'light',
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: 'system',
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('System'),
                            ),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (selection) {
                            controller.updateThemeMode(selection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 4: Data & Family Backup
              _buildSectionTitle(context, 'Data & Family Backup'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload_file_rounded),
                      title: const Text('Export Backup to your Files'),
                      subtitle: const Text(
                        'Save or share your fasting history and settings',
                      ),
                      onTap: () => _exportBackup(context, controller),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: const Text('Import Backup from your Files'),
                      subtitle: const Text(
                        'Merge or restore from a backup file',
                      ),
                      onTap: () => _importBackup(context, controller),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 5: About
              _buildSectionTitle(context, 'About'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Fast O'Clock",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'v1.0.0',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'time to fast — a simple fasting tracker for beginners and pros alike.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '100% offline. Your data never leaves your device.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '© ${DateTime.now().year}. neurral and pinoy.dev',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _exportBackup(
    BuildContext context,
    FastingController controller,
  ) async {
    try {
      final jsonStr = await controller.exportBackupJson();
      final dateStamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = 'fast_oclock_backup_$dateStamp.json';
      final bytes = utf8.encode(jsonStr);

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'application/json',
          ),
        ],
        subject: "Fast O'Clock Backup ($dateStamp)",
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importBackup(
    BuildContext context,
    FastingController controller,
  ) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.first;
      String jsonContent;
      if (file.bytes != null) {
        jsonContent = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonContent = await File(file.path!).readAsString();
      } else {
        return;
      }

      if (!context.mounted) return;
      final mode = await showDialog<BackupImportMode>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Backup'),
          content: const Text(
            'Choose how to handle existing fasts on this device:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(BackupImportMode.replaceAll),
              child: const Text('Replace All'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(BackupImportMode.mergeById),
              child: const Text('Merge (Recommended)'),
            ),
          ],
        ),
      );
      if (mode == null) return;

      final result = await controller.importBackupJson(jsonContent, mode: mode);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.summary)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}
