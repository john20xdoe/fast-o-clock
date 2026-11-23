import 'package:fast_oclock/services/backup_service.dart';
import 'package:fast_oclock/services/database_service.dart';
import 'package:fast_oclock/services/notification_service.dart';
import 'package:fast_oclock/services/preferences_service.dart';
import 'package:fast_oclock/state/fasting_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;
  late PreferencesService prefsService;
  late NotificationService notifService;
  late BackupService backupService;
  late FastingController controller;

  DateTime fakeNowUtc = DateTime.utc(2026, 11, 21, 12, 0);

  setUp(() async {
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
    await controller.init();
  });

  tearDown(() async {
    controller.dispose();
    await dbService.close();
  });

  group('FastingController', () {
    test('starts, updates, and completes a fast with accurate streak math',
        () async {
      // Log a completed 16:8 fast ending yesterday
      final yesterdayEnd =
          fakeNowUtc.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final yesterdayStart = yesterdayEnd - 16 * 3600 * 1000;
      await controller.addPastFast(
        protocolId: '16_8',
        targetDurationMin: 960,
        startTimeUtcMs: yesterdayStart,
        endTimeUtcMs: yesterdayEnd,
      );
      expect(controller.currentStreak, 1);

      // Start an active fast 17 hours ago and complete it today
      final activeStart =
          fakeNowUtc.subtract(const Duration(hours: 17)).millisecondsSinceEpoch;
      await controller.startFast(
        startTimeUtcMs: activeStart,
        protocolId: '16_8',
        targetDurationMin: 960,
      );
      expect(controller.activeFast, isNotNull);
      expect(controller.activeFast!.isGoalMetAt(fakeNowUtc), isTrue);

      await controller.endActiveFast(
        endTimeUtcMs: fakeNowUtc.millisecondsSinceEpoch,
        mood: 'great',
        note: 'Solid fast',
      );

      expect(controller.activeFast, isNull);
      expect(controller.totalCompletedFasts, 2);
      expect(controller.currentStreak, 2);
    });
  });
}
