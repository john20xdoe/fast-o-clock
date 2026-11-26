import 'package:fast_oclock/services/database_service.dart';
import 'package:fast_oclock/widgets/fast_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;
  final fixedNowUtc = DateTime.utc(2026, 11, 23, 12, 0);
  final nowMs = fixedNowUtc.millisecondsSinceEpoch;

  setUp(() {
    dbService = DatabaseService(overridePath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await dbService.close();
  });

  Widget wrapSheet(FastEditorSheet sheet) {
    return MaterialApp(
      home: Scaffold(body: sheet),
    );
  }

  group('FastEditorSheet 4h minimum validation', () {
    testWidgets(
      'completeActive shows error and disables Save to Timeline when < 4h',
      (tester) async {
        await tester.pumpWidget(
          wrapSheet(
            FastEditorSheet(
              mode: FastEditorMode.completeActive,
              databaseService: dbService,
              recordId: 'active_1',
              initialProtocolId: '16_8',
              initialTargetDurationMin: 960,
              initialStartTimeUtcMs: nowMs - 2 * 3600000,
              initialEndTimeUtcMs: nowMs,
              clockUtc: () => fixedNowUtc,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(DatabaseService.minCompletedFastDurationError),
          findsOneWidget,
        );
        expect(find.text('How did this fasting feel?'), findsNothing);
        expect(find.text('Add note'), findsNothing);

        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save to Timeline'),
        );
        expect(saveButton.onPressed, isNull);
        expect(find.text('Delete'), findsOneWidget);
      },
    );

    testWidgets(
      'editPast shows error and disables Save when < 4h, enables when >= 4h',
      (tester) async {
        await tester.pumpWidget(
          wrapSheet(
            FastEditorSheet(
              key: const ValueKey('past_1'),
              mode: FastEditorMode.editPast,
              databaseService: dbService,
              recordId: 'past_1',
              initialProtocolId: '16_8',
              initialTargetDurationMin: 960,
              initialStartTimeUtcMs: nowMs - 3 * 3600000,
              initialEndTimeUtcMs: nowMs,
              clockUtc: () => fixedNowUtc,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(DatabaseService.minCompletedFastDurationError),
          findsOneWidget,
        );
        expect(find.text('How did this fasting feel?'), findsNothing);
        expect(find.text('Add note'), findsNothing);
        final disabledSave = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(disabledSave.onPressed, isNull);

        await tester.pumpWidget(
          wrapSheet(
            FastEditorSheet(
              key: const ValueKey('past_2'),
              mode: FastEditorMode.editPast,
              databaseService: dbService,
              recordId: 'past_2',
              initialProtocolId: '16_8',
              initialTargetDurationMin: 960,
              initialStartTimeUtcMs: nowMs - 4 * 3600000,
              initialEndTimeUtcMs: nowMs,
              clockUtc: () => fixedNowUtc,
            ),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();

        expect(
          find.text(DatabaseService.minCompletedFastDurationError),
          findsNothing,
        );
        final enabledSave = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(enabledSave.onPressed, isNotNull);
      },
    );

    testWidgets(
      'shows Clean/Modified toggle, conditional Early-End Reason, target chips, and collapsed note',
      (tester) async {
        await tester.pumpWidget(
          wrapSheet(
            FastEditorSheet(
              mode: FastEditorMode.addPast,
              databaseService: dbService,
              initialProtocolId: '16_8',
              initialTargetDurationMin: 960,
              initialStartTimeUtcMs: nowMs - 10 * 3600000,
              initialEndTimeUtcMs: nowMs,
              clockUtc: () => fixedNowUtc,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Target Hours'), findsOneWidget);
        expect(find.text('16h'), findsOneWidget);
        expect(find.text('Clean'), findsOneWidget);
        expect(find.text('Modified'), findsOneWidget);
        expect(find.text('Early-End Reason'), findsOneWidget);
        expect(find.text('Hungry'), findsOneWidget);

        // Collapsed note expands on tap
        expect(find.text('Optional Note'), findsNothing);
        await tester.ensureVisible(find.text('Add note'));
        await tester.tap(find.text('Add note'));
        await tester.pumpAndSettle();
        expect(find.text('Optional Note'), findsOneWidget);
      },
    );

    testWidgets(
      'addPast defaults to blank Start and End times with Save disabled and no overlap error',
      (tester) async {
        await tester.pumpWidget(
          wrapSheet(
            FastEditorSheet(
              mode: FastEditorMode.addPast,
              databaseService: dbService,
              initialProtocolId: '16_8',
              initialTargetDurationMin: 960,
              clockUtc: () => fixedNowUtc,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Select start time'), findsOneWidget);
        expect(find.text('Select end time'), findsOneWidget);
        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(saveButton.onPressed, isNull);
      },
    );
  });
}
