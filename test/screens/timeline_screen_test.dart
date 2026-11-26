import 'package:fast_oclock/models/fast_record.dart';
import 'package:fast_oclock/screens/timeline_screen.dart';
import 'package:fast_oclock/services/backup_service.dart';
import 'package:fast_oclock/services/database_service.dart';
import 'package:fast_oclock/services/notification_service.dart';
import 'package:fast_oclock/services/preferences_service.dart';
import 'package:fast_oclock/state/fasting_controller.dart';
import 'package:fast_oclock/widgets/timeline_calendar.dart';
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

  Future<void> seedFast({
    required String id,
    required int daysAgo,
    required int durationHours,
    String protocolId = '16_8',
    int targetDurationMin = 960,
    String? mood,
    String? note,
    bool isClean = true,
    String? endReason,
  }) async {
    final endLocal = DateTime(2026, 11, 24 - daysAgo, 10, 0);
    final endMs = endLocal.toUtc().millisecondsSinceEpoch;
    final startMs = endMs - durationHours * 3600000;
    await dbService.insertRecord(
      FastRecord(
        id: id,
        protocolId: protocolId,
        startTimeMs: startMs,
        endTimeMs: endMs,
        targetDurationMin: targetDurationMin,
        mood: mood,
        note: note,
        isClean: isClean,
        endReason: endReason,
        createdAtMs: startMs,
        updatedAtMs: endMs,
      ),
      nowUtcMs: fakeNowUtc.millisecondsSinceEpoch,
    );
  }

  setUp(() async {
    fakeNowUtc = DateTime(2026, 11, 24, 12, 0).toUtc();
    SharedPreferences.setMockInitialValues({'pref_is_onboarded': true});
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

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildHarness({
    String? focusedRecordId,
    VoidCallback? onFocusedRecordHandled,
  }) {
    return ChangeNotifierProvider<FastingController>.value(
      value: controller,
      child: MaterialApp(
        home: TimelineScreen(
          focusedRecordId: focusedRecordId,
          onFocusedRecordHandled: onFocusedRecordHandled,
        ),
      ),
    );
  }

  testWidgets(
      'renders header, 3-stat KPI strip, calendar, timeline spine, neutral cards, and no FAB',
      (WidgetTester tester) async {
    setPhoneViewport(tester);
    await tester.runAsync(() async {
      await seedFast(
        id: 'f_met',
        daysAgo: 1,
        durationHours: 17,
        isClean: false,
        note: 'Clean energy',
      );
      await seedFast(
        id: 'f_early',
        daysAgo: 2,
        durationHours: 10,
        endReason: 'hungry',
      );
      await controller.init();
    });

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Log Fast'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(TimelineCalendar), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('NOVEMBER 2026'), findsOneWidget);
    expect(find.text('Best 1d'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    expect(find.text('Goal Met'), findsWidgets);
    expect(find.text('Ended Early'), findsOneWidget);
    expect(find.text('Modified'), findsOneWidget);
    expect(find.text('Hungry'), findsOneWidget);
    expect(find.text('+1h'), findsOneWidget);
    expect(find.text('-6h'), findsOneWidget);

    await cleanupController(tester);
  });

  testWidgets('calendar month navigation and day tap tooltip work',
      (WidgetTester tester) async {
    setPhoneViewport(tester);
    await tester.runAsync(() async {
      await seedFast(id: 'f1', daysAgo: 1, durationHours: 16);
      await controller.init();
    });

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    // Tap day 23 on November 2026 calendar
    await tester.tap(find.text('23'));
    await tester.pumpAndSettle();
    expect(find.text('23 · 16h 00m · Goal Met'), findsOneWidget);

    // Navigate to October 2026 -> list filters to October (empty here)
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('No fasts in October 2026'), findsOneWidget);
    expect(find.text('NOVEMBER 2026'), findsNothing);

    await cleanupController(tester);
  });

  testWidgets('active fast 1s ticks emit zero controller notifications to Timeline',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedFast(id: 'f1', daysAgo: 1, durationHours: 16);
      await controller.init();
      await controller.startFast(
        startTimeUtcMs:
            fakeNowUtc.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      );
    });

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    int controllerNotifications = 0;
    int tickCount = 0;
    controller.addListener(() => controllerNotifications++);
    controller.clockTick.addListener(() => tickCount++);

    await tester.pumpWidget(buildHarness());
    await tester.pump();

    fakeNowUtc = fakeNowUtc.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    fakeNowUtc = fakeNowUtc.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(tickCount, 2);
    expect(controllerNotifications, 0);
    await cleanupController(tester);
  });

  testWidgets('focusedRecordId highlights target record and calls handler',
      (WidgetTester tester) async {
    setPhoneViewport(tester);
    await tester.runAsync(() async {
      await seedFast(id: 'target_id', daysAgo: 1, durationHours: 16);
      await controller.init();
    });

    bool handled = false;
    await tester.pumpWidget(
      buildHarness(
        focusedRecordId: 'target_id',
        onFocusedRecordHandled: () => handled = true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(handled, isTrue);

    await tester.pump(const Duration(milliseconds: 1300));
    await cleanupController(tester);
  });
}
