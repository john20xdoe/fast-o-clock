import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/app_settings.dart';
import '../models/fast_protocol.dart';
import '../models/fast_record.dart';
import '../models/metabolic_stage.dart';
import '../models/timeline_summary.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';

enum DayFastStatus { none, active, completedBelowGoal, goalMet }

class DayFastSummary {
  final DateTime localDate;
  final DayFastStatus status;

  const DayFastSummary({
    required this.localDate,
    required this.status,
  });
}

class FastingController extends ChangeNotifier with WidgetsBindingObserver {
  final DatabaseService _databaseService;
  final PreferencesService _preferencesService;
  final NotificationService _notificationService;
  final BackupService _backupService;
  final DateTime Function() _clockUtc;

  FastRecord? _activeFast;
  List<FastRecord> _history = const [];
  AppSettings _settings = const AppSettings();
  bool _isInitialized = false;
  Timer? _ticker;
  int _historyVersion = 0;

  late final ValueNotifier<DateTime> _clockTick;
  late int _lastNotifiedDayKey;

  int? _cachedStatsVersion;
  String? _cachedStatsActiveId;
  int? _cachedStatsDayKey;
  int _cachedCurrentStreak = 0;
  Duration _cachedAverageDuration = Duration.zero;
  List<DayFastSummary> _cachedSevenDays = const [];

  FastingController({
    required DatabaseService databaseService,
    required PreferencesService preferencesService,
    required NotificationService notificationService,
    required BackupService backupService,
    DateTime Function()? clockUtc,
  })  : _databaseService = databaseService,
        _preferencesService = preferencesService,
        _notificationService = notificationService,
        _backupService = backupService,
        _clockUtc = clockUtc ?? (() => DateTime.now().toUtc()) {
    final initialNow = _clockUtc();
    _clockTick = ValueNotifier<DateTime>(initialNow);
    _lastNotifiedDayKey = _dayKeyFor(initialNow.toLocal());
    WidgetsBinding.instance.addObserver(this);
  }

  static int _dayKeyFor(DateTime local) =>
      local.year * 10000 + local.month * 100 + local.day;

  bool get isInitialized => _isInitialized;
  FastRecord? get activeFast => _activeFast;
  List<FastRecord> get history => _history;
  AppSettings get settings => _settings;
  DatabaseService get databaseService => _databaseService;
  ValueListenable<DateTime> get clockTick => _clockTick;
  int get historyVersion => _historyVersion;
  int get localDayKey => _dayKeyFor(_clockUtc().toLocal());

  DateTime get nowUtc => _clockUtc();

  FastProtocol get selectedProtocol {
    if (_activeFast != null) {
      return FastProtocol.resolve(
        _activeFast!.protocolId,
        customDurationMin: _activeFast!.targetDurationMin,
      );
    }
    return FastProtocol.resolve(
      _settings.defaultProtocolId,
      customDurationMin: _settings.customDurationMin,
    );
  }

  MetabolicStage get currentMetabolicStage {
    final active = _activeFast;
    if (active == null) return MetabolicStage.stages.first;
    return MetabolicStage.forElapsedDuration(active.elapsedDuration(nowUtc));
  }

  FastRecord? get lastCompletedFast =>
      _history.isNotEmpty ? _history.first : null;

  Future<void> init() async {
    _settings = await _preferencesService.loadSettings();
    await _reloadRecords();
    _isInitialized = true;
    _syncTicker();
    notifyListeners();
  }

  Future<void> _reloadRecords() async {
    _activeFast = await _databaseService.getActiveFast();
    _history = await _databaseService.getCompletedFasts();
    _historyVersion++;
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    final now = _clockUtc();
    _clockTick.value = now;
    _lastNotifiedDayKey = _dayKeyFor(now.toLocal());
    if (_activeFast != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final tickNow = _clockUtc();
        _clockTick.value = tickNow;
        final dayKey = _dayKeyFor(tickNow.toLocal());
        if (dayKey != _lastNotifiedDayKey) {
          _lastNotifiedDayKey = dayKey;
          notifyListeners();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = _clockUtc();
      final newDayKey = _dayKeyFor(now.toLocal());
      final dayChanged = newDayKey != _lastNotifiedDayKey;
      _syncTicker();
      if (dayChanged) {
        notifyListeners();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clockTick.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- Onboarding & Settings ---

  Future<void> completeOnboarding({
    String? defaultProtocolId,
    int? customDurationMin,
  }) async {
    _settings = _settings.copyWith(
      isOnboarded: true,
      defaultProtocolId: defaultProtocolId ?? _settings.defaultProtocolId,
      customDurationMin: customDurationMin ?? _settings.customDurationMin,
    );
    await _preferencesService.saveSettings(_settings);
    if (_settings.notifyGoalReached || _settings.notifyEatingWindow) {
      await _notificationService.requestPermissions();
    }
    notifyListeners();
  }

  Future<void> updateDefaultProtocol(
    String protocolId, {
    int? customDurationMin,
  }) async {
    _settings = _settings.copyWith(
      defaultProtocolId: protocolId,
      customDurationMin: customDurationMin ?? _settings.customDurationMin,
    );
    await _preferencesService.saveSettings(_settings);

    // If a fast is currently active, also update its protocol/target goal
    if (_activeFast != null) {
      final protocol = FastProtocol.resolve(
        protocolId,
        customDurationMin: _settings.customDurationMin,
      );
      await updateActiveFast(
        protocolId: protocol.id,
        targetDurationMin: protocol.targetDurationMin,
      );
    } else {
      await _scheduleEatingWindowIfNeeded();
      notifyListeners();
    }
  }

  Future<void> updateThemeMode(String themeMode) async {
    _settings = _settings.copyWith(themeMode: themeMode);
    await _preferencesService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateBedtime(int? minutesOfDay) async {
    _settings = minutesOfDay == null
        ? _settings.copyWith(clearBedtime: true)
        : _settings.copyWith(bedtimeMinutesOfDay: minutesOfDay);
    await _preferencesService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> toggleShowRemainingTime() async {
    _settings = _settings.copyWith(
      showRemainingTime: !_settings.showRemainingTime,
    );
    await _preferencesService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setNotifyGoalReached(bool enabled) async {
    if (enabled) {
      await _notificationService.requestPermissions();
    }
    _settings = _settings.copyWith(notifyGoalReached: enabled);
    await _preferencesService.saveSettings(_settings);

    if (!enabled) {
      await _notificationService.cancelGoalReached();
    } else if (_activeFast != null) {
      await _scheduleActiveGoalNotification(_activeFast!);
    }
    notifyListeners();
  }

  Future<void> setNotifyEatingWindow(bool enabled) async {
    if (enabled) {
      await _notificationService.requestPermissions();
    }
    _settings = _settings.copyWith(notifyEatingWindow: enabled);
    await _preferencesService.saveSettings(_settings);

    if (!enabled) {
      await _notificationService.cancelEatingWindowEnding();
    } else if (_activeFast == null) {
      await _scheduleEatingWindowIfNeeded();
    }
    notifyListeners();
  }

  Future<void> _scheduleEatingWindowIfNeeded() async {
    if (!_settings.notifyEatingWindow || _activeFast != null) return;
    final last = lastCompletedFast;
    if (last?.endTimeMs == null) {
      await _notificationService.cancelEatingWindowEnding();
      return;
    }
    final protocol = selectedProtocol;
    if (protocol.targetDurationMin >= 1440) {
      await _notificationService.cancelEatingWindowEnding();
      return;
    }
    await _notificationService.scheduleEatingWindowEnding(
      fastEndTimeUtcMs: last!.endTimeMs!,
      targetDurationMin: protocol.targetDurationMin,
    );
  }

  // --- Fast Lifecycle Actions ---

  Future<void> startFast({
    int? startTimeUtcMs,
    String? protocolId,
    int? targetDurationMin,
  }) async {
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final pId = protocolId ?? _settings.defaultProtocolId;
    final resolved = FastProtocol.resolve(
      pId,
      customDurationMin: targetDurationMin ?? _settings.customDurationMin,
    );
    final record = FastRecord(
      id: FastRecord.generateId(),
      protocolId: resolved.id,
      startTimeMs: startTimeUtcMs ?? nowMs,
      endTimeMs: null,
      targetDurationMin: targetDurationMin ?? resolved.targetDurationMin,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );

    await _databaseService.insertRecord(record, nowUtcMs: nowMs);
    await _notificationService.cancelEatingWindowEnding();
    await _scheduleActiveGoalNotification(record);

    await _reloadRecords();
    _syncTicker();
    notifyListeners();
  }

  Future<void> updateActiveFast({
    int? startTimeUtcMs,
    String? protocolId,
    int? targetDurationMin,
  }) async {
    final active = _activeFast;
    if (active == null) return;
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final updated = active.copyWith(
      startTimeMs: startTimeUtcMs ?? active.startTimeMs,
      protocolId: protocolId ?? active.protocolId,
      targetDurationMin: targetDurationMin ?? active.targetDurationMin,
      updatedAtMs: nowMs,
    );

    await _databaseService.updateRecord(updated, nowUtcMs: nowMs);
    await _scheduleActiveGoalNotification(updated);

    await _reloadRecords();
    notifyListeners();
  }

  Future<void> endActiveFast({
    int? startTimeUtcMs,
    int? endTimeUtcMs,
    String? protocolId,
    int? targetDurationMin,
    String? note,
    String? mood,
    bool isClean = true,
    String? endReason,
  }) async {
    final active = _activeFast;
    if (active == null) return;
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final endMs = endTimeUtcMs ?? nowMs;
    final completed = active.copyWith(
      startTimeMs: startTimeUtcMs ?? active.startTimeMs,
      endTimeMs: endMs,
      protocolId: protocolId ?? active.protocolId,
      targetDurationMin: targetDurationMin ?? active.targetDurationMin,
      note: note,
      clearNote: note == null || note.trim().isEmpty,
      mood: mood,
      clearMood: mood == null,
      isClean: isClean,
      endReason: endReason,
      clearEndReason: endReason == null,
      updatedAtMs: nowMs,
    );

    await _databaseService.updateRecord(completed, nowUtcMs: nowMs);
    await _notificationService.cancelGoalReached();

    if (_settings.notifyEatingWindow &&
        completed.targetDurationMin < 1440) {
      await _notificationService.scheduleEatingWindowEnding(
        fastEndTimeUtcMs: completed.endTimeMs!,
        targetDurationMin: completed.targetDurationMin,
      );
    } else {
      await _notificationService.cancelEatingWindowEnding();
    }

    await _reloadRecords();
    _syncTicker();
    notifyListeners();
  }

  Future<void> addPastFast({
    required String protocolId,
    required int targetDurationMin,
    required int startTimeUtcMs,
    required int endTimeUtcMs,
    String? note,
    String? mood,
    bool isClean = true,
    String? endReason,
  }) async {
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final record = FastRecord(
      id: FastRecord.generateId(),
      protocolId: protocolId,
      startTimeMs: startTimeUtcMs,
      endTimeMs: endTimeUtcMs,
      targetDurationMin: targetDurationMin,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      mood: mood,
      isClean: isClean,
      endReason: endReason,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );

    await _databaseService.insertRecord(record, nowUtcMs: nowMs);
    await _reloadRecords();
    notifyListeners();
  }

  Future<void> updateCompletedFast({
    required String id,
    required String protocolId,
    required int targetDurationMin,
    required int startTimeUtcMs,
    required int endTimeUtcMs,
    String? note,
    String? mood,
    bool isClean = true,
    String? endReason,
  }) async {
    final existing = await _databaseService.getRecordById(id);
    if (existing == null) return;
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final updated = existing.copyWith(
      protocolId: protocolId,
      targetDurationMin: targetDurationMin,
      startTimeMs: startTimeUtcMs,
      endTimeMs: endTimeUtcMs,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      clearNote: note == null || note.trim().isEmpty,
      mood: mood,
      clearMood: mood == null,
      isClean: isClean,
      endReason: endReason,
      clearEndReason: endReason == null,
      updatedAtMs: nowMs,
    );

    await _databaseService.updateRecord(updated, nowUtcMs: nowMs);
    await _reloadRecords();
    notifyListeners();
  }

  Future<void> deleteFastRecord(String id) async {
    final wasActive = _activeFast?.id == id;
    await _databaseService.deleteRecord(id);
    if (wasActive) {
      await _notificationService.cancelGoalReached();
      await _notificationService.cancelEatingWindowEnding();
    }
    await _reloadRecords();
    _syncTicker();
    notifyListeners();
  }

  Future<void> _scheduleActiveGoalNotification(FastRecord active) async {
    if (!_settings.notifyGoalReached) {
      await _notificationService.cancelGoalReached();
      return;
    }
    final protocol = FastProtocol.resolve(
      active.protocolId,
      customDurationMin: active.targetDurationMin,
    );
    await _notificationService.scheduleGoalReached(
      targetEndTimeUtcMs: active.targetEndTimeMs,
      protocolLabel: protocol.label,
    );
  }

  // --- Backup & Restore ---

  Future<String> exportBackupJson() {
    return _backupService.exportBackupJson(
      exportedAtMs: nowUtc.millisecondsSinceEpoch,
    );
  }

  Future<String> exportSampleMonthBackupJson() {
    return _backupService.exportSampleMonthBackupJson(
      exportedAtMs: nowUtc.millisecondsSinceEpoch,
    );
  }

  Future<BackupImportResult> importBackupJson(
    String jsonString, {
    BackupImportMode mode = BackupImportMode.mergeById,
  }) async {
    final result = await _backupService.importBackupJson(
      jsonString,
      mode: mode,
      nowUtcMs: nowUtc.millisecondsSinceEpoch,
    );
    _settings = await _preferencesService.loadSettings();
    await _reloadRecords();
    if (_activeFast != null) {
      await _notificationService.cancelEatingWindowEnding();
      await _scheduleActiveGoalNotification(_activeFast!);
    } else {
      await _notificationService.cancelGoalReached();
      await _notificationService.cancelEatingWindowEnding();
    }
    _syncTicker();
    notifyListeners();
    return result;
  }

  // --- Streak & Summary Metrics ---

  int get totalCompletedFasts => _history.length;

  Duration get averageFastDuration {
    _ensureStatsCache();
    return _cachedAverageDuration;
  }

  /// Consecutive local calendar days (by end_time_ms) with >= 1 goal-met fast.
  int get currentStreak {
    _ensureStatsCache();
    return _cachedCurrentStreak;
  }

  /// Last 7 local calendar days (today - 6 through today).
  List<DayFastSummary> get lastSevenDaysSummary {
    _ensureStatsCache();
    return _cachedSevenDays;
  }

  void _ensureStatsCache() {
    final now = _clockUtc();
    final dayKey = _dayKeyFor(now.toLocal());
    final activeId = _activeFast?.id;
    if (_cachedStatsVersion == _historyVersion &&
        _cachedStatsActiveId == activeId &&
        _cachedStatsDayKey == dayKey) {
      return;
    }

    _cachedStatsVersion = _historyVersion;
    _cachedStatsActiveId = activeId;
    _cachedStatsDayKey = dayKey;

    final snapshot = TimelineSnapshot.build(
      history: _history,
      activeFast: _activeFast,
      nowUtc: now,
    );

    _cachedAverageDuration = snapshot.allTimeAverageDuration;
    _cachedCurrentStreak = snapshot.currentStreak;
    _cachedSevenDays = List.unmodifiable(
      TimelineSnapshot.buildLastSevenDays(
        history: _history,
        activeFast: _activeFast,
        nowUtc: now,
      ),
    );
  }
}
