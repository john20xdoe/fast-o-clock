import 'package:fast_oclock/app.dart';
import 'package:fast_oclock/services/backup_service.dart';
import 'package:fast_oclock/services/database_service.dart';
import 'package:fast_oclock/services/notification_service.dart';
import 'package:fast_oclock/services/preferences_service.dart';
import 'package:fast_oclock/state/fasting_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('FastOClockApp renders Onboarding on first launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final dbService = DatabaseService(overridePath: inMemoryDatabasePath);
    final prefsService = PreferencesService();
    final notifService = NotificationService();
    final backupService = BackupService(
      databaseService: dbService,
      preferencesService: prefsService,
    );
    final controller = FastingController(
      databaseService: dbService,
      preferencesService: prefsService,
      notificationService: notifService,
      backupService: backupService,
    );
    await tester.runAsync(() async {
      await controller.init();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<FastingController>.value(
        value: controller,
        child: const FastOClockApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Fast O'Clock"), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    controller.dispose();
    await tester.runAsync(() async {
      await dbService.close();
    });
  });
}
