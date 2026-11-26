import 'package:fast_oclock/models/fast_record.dart';
import 'package:fast_oclock/screens/fasting_screen.dart';
import 'package:fast_oclock/services/backup_service.dart';
import 'package:fast_oclock/services/database_service.dart';
import 'package:fast_oclock/services/notification_service.dart';
import 'package:fast_oclock/services/preferences_service.dart';
import 'package:fast_oclock/state/fasting_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;
  late PreferencesService prefsService;
  late NotificationService notifService;
  late BackupService backupService;
  late FastingController controller;
  late DateTime fakeNowUtc;

  setUp(() async {
    fakeNowUtc = DateTime(2026, 11, 24, 12, 0).toUtc();
    SharedPreferences.setMockInitialValues({
      'pref_is_onboarded': true,
      'pref_default_protocol_id': '16_8',
    });
    dbService = DatabaseService(overridePath: inMemoryDatabasePath);
    prefsService = PreferencesService();
    notifService = NotificationService();
    backupService = BackupService(
      databaseService: dbService,
      preferencesService: prefsService,
    );
    controller = FastingController(
      databaseService: dbService,
      preferencesService: prefsService,
      notificationService: notifService,
      backupService: backupService,
      clockUtc: () => fakeNowUtc,
    );
  });

  tearDown(() async {
    await dbService.close();
  });

  Future<void> cleanupController(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  }

  Widget buildHarness() {
    return ChangeNotifierProvider<FastingController>.value(
      value: controller,
      child: const MaterialApp(
        home: Scaffold(body: FastingScreen()),
      ),
    );
  }

  testWidgets('shows eating window remaining and Until time, hiding Goal when in eating window',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      // 16:8 -> 8h eating window. Last fast ended 1h ago => 7h remaining.
      final lastEndMs =
          fakeNowUtc.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      await dbService.insertRecord(
        FastRecord(
          id: 'last_1',
          protocolId: '16_8',
          startTimeMs: lastEndMs - 16 * 3600000,
          endTimeMs: lastEndMs,
          targetDurationMin: 960,
          createdAtMs: lastEndMs - 16 * 3600000,
          updatedAtMs: lastEndMs,
        ),
        nowUtcMs: fakeNowUtc.millisecondsSinceEpoch,
      );
      await controller.init();
    });

    await tester.pumpWidget(buildHarness());
    await tester.pump();

    expect(find.text('Your time to eat'), findsOneWidget);
    expect(find.text('7h'), findsOneWidget);
    expect(find.textContaining('Until: '), findsOneWidget);
    expect(find.textContaining('Goal:'), findsNothing);

    await cleanupController(tester);
  });

  testWidgets('shows Ready to Fast and Goal when history is empty or eating window ended',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      // Last fast ended 10h ago (> 8h eating window for 16:8)
      final lastEndMs =
          fakeNowUtc.subtract(const Duration(hours: 10)).millisecondsSinceEpoch;
      await dbService.insertRecord(
        FastRecord(
          id: 'last_old',
          protocolId: '16_8',
          startTimeMs: lastEndMs - 16 * 3600000,
          endTimeMs: lastEndMs,
          targetDurationMin: 960,
          createdAtMs: lastEndMs - 16 * 3600000,
          updatedAtMs: lastEndMs,
        ),
        nowUtcMs: fakeNowUtc.millisecondsSinceEpoch,
      );
      await controller.init();
    });

    await tester.pumpWidget(buildHarness());
    await tester.pump();

    expect(find.text('Ready to Fast?'), findsOneWidget);
    expect(find.text('Goal: 16 hours'), findsOneWidget);
    expect(find.text('Your time to eat'), findsNothing);

    await cleanupController(tester);
  });
}
