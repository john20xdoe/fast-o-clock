import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/backup_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'state/fasting_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final databaseService = DatabaseService();
  final preferencesService = PreferencesService();
  final notificationService = NotificationService();
  await notificationService.init();

  final backupService = BackupService(
    databaseService: databaseService,
    preferencesService: preferencesService,
  );

  final controller = FastingController(
    databaseService: databaseService,
    preferencesService: preferencesService,
    notificationService: notificationService,
    backupService: backupService,
  );
  await controller.init();

  runApp(
    ChangeNotifierProvider<FastingController>.value(
      value: controller,
      child: const FastOClockApp(),
    ),
  );
}
