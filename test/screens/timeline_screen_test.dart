import 'package:fast_oclock/models/fast_record.dart';
import 'package:fast_oclock/screens/timeline_screen.dart';
import 'package:fast_oclock/services/backup_service.dart';
import 'package:fast_oclock/services/database_service.dart';
import 'package:fast_oclock/services/notification_service.dart';
import 'package:fast_oclock/services/preferences_service.dart';
import 'package:fast_oclock/state/fasting_controller.dart';
import 'package:fast_oclock/widgets/timeline_chart.dart';
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
      'renders redesigned header, KPIs, chart, month header, distinct moods, and no FAB',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedFast(
        id: 'f_great',
        daysAgo: 1,
        durationHours: 17,
        mood: 'great',
        note: 'Clean energy',
      );
      await seedFast(
        id: 'f_bad',
        daysAgo: 2,
        durationHours: 10,
        mood: 'bad',
      );
      await controller.init();
    });

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Log Fast'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(DurationBarChart), findsOneWidget);
    expect(find.text('NOVEMBER 2026'), findsOneWidget);
    expect(find.text('Streak · Best 1d'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // Distinct mood icons rendered
    expect(find.byIcon(Icons.sentiment_very_satisfied_rounded), findsOneWidget);
    expect(
      find.byIcon(Icons.sentiment_very_dissatisfied_rounded),
      findsOneWidget,
    );
    await cleanupController(tester);
  });

  testWidgets('range toggle scopes KPIs without hiding older history',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      // 1 recent fast (within 7d) + 1 older fast (12 days ago)
      await seedFast(id: 'recent', daysAgo: 1, durationHours: 16);
      await seedFast(id: 'older', daysAgo: 12, durationHours: 10);
      await controller.init();
    });

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    // Default 7D when history <= 7: 1/1 = 100%
    expect(find.text('100%'), findsOneWidget);
    // Older fast is still visible in the history list
    expect(find.text('10h 00m'), findsWidgets);

    // Switch to 30D: 1/2 = 50%
    await tester.tap(find.text('30D'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);
    await cleanupController(tester);
  });

  testWidgets('empty filter shows reset message and Show All restores items',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedFast(id: 'f1', daysAgo: 1, durationHours: 16);
      await controller.init();
    });

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes (0)'));
    await tester.pumpAndSettle();

    expect(find.text('No fasts match this filter'), findsOneWidget);
    await tester.tap(find.text('Show All'));
    await tester.pumpAndSettle();

    expect(find.text('No fasts match this filter'), findsNothing);
    expect(find.text('16h 00m'), findsWidgets);
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

    int controllerNotifications = 0;
    controller.addListener(() => controllerNotifications++);

    await tester.pumpWidget(buildHarness());
    await tester.pump();

    fakeNowUtc = fakeNowUtc.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    fakeNowUtc = fakeNowUtc.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(controllerNotifications, 0);
    await cleanupController(tester);
  });

  testWidgets('focusedRecordId invokes callback and highlights target card',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedFast(id: 'target_fast', daysAgo: 1, durationHours: 17);
      await seedFast(id: 'other_fast', daysAgo: 2, durationHours: 16);
      await controller.init();
    });

    bool handled = false;
    await tester.pumpWidget(
      buildHarness(
        focusedRecordId: 'target_fast',
        onFocusedRecordHandled: () => handled = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(handled, isTrue);

    // Wait out 1200ms highlight timer cleanly before teardown
    await tester.pump(const Duration(milliseconds: 1300));
    await cleanupController(tester);
  });
}
