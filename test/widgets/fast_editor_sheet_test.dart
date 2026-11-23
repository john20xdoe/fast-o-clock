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
        expect(find.text('Optional Note'), findsNothing);

        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save to Timeline'),
        );
        expect(saveButton.onPressed, isNull);
        expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
      },
    );

    testWidgets(
      'editPast shows error and disables Save when < 4h, enables when >= 4h',
      (tester) async {
        await tester.pumpWidget(
          wrapSheet(
            FastEditorSheet(
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
        expect(find.text('Optional Note'), findsNothing);
        final disabledSave = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(disabledSave.onPressed, isNull);

        await tester.pumpWidget(
          wrapSheet(
            FastEditorSheet(
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
  });
}
