import 'package:flutter/material.dart';

class AppSettings {
  final bool isOnboarded;
  final String themeMode; // 'dark', 'light', 'system'
  final String defaultProtocolId;
  final int customDurationMin;
  final bool notifyGoalReached;
  final bool notifyEatingWindow;
  final bool showRemainingTime;
  final int? bedtimeMinutesOfDay;

  const AppSettings({
    this.isOnboarded = false,
    this.themeMode = 'dark',
    this.defaultProtocolId = '16_8',
    this.customDurationMin = 960,
    this.notifyGoalReached = true,
    this.notifyEatingWindow = false,
    this.showRemainingTime = false,
    this.bedtimeMinutesOfDay,
  });

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  AppSettings copyWith({
    bool? isOnboarded,
    String? themeMode,
    String? defaultProtocolId,
    int? customDurationMin,
    bool? notifyGoalReached,
    bool? notifyEatingWindow,
    bool? showRemainingTime,
    int? bedtimeMinutesOfDay,
    bool clearBedtime = false,
  }) {
    return AppSettings(
      isOnboarded: isOnboarded ?? this.isOnboarded,
      themeMode: themeMode ?? this.themeMode,
      defaultProtocolId: defaultProtocolId ?? this.defaultProtocolId,
      customDurationMin: customDurationMin ?? this.customDurationMin,
      notifyGoalReached: notifyGoalReached ?? this.notifyGoalReached,
      notifyEatingWindow: notifyEatingWindow ?? this.notifyEatingWindow,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      bedtimeMinutesOfDay: clearBedtime
          ? null
          : (bedtimeMinutesOfDay ?? this.bedtimeMinutesOfDay),
    );
  }

  Map<String, dynamic> toBackupJson() => {
        'defaultProtocolId': defaultProtocolId,
        'customDurationMin': customDurationMin,
        'themeMode': themeMode,
        'notifyGoalReached': notifyGoalReached,
        'notifyEatingWindow': notifyEatingWindow,
        'showRemainingTime': showRemainingTime,
        'bedtimeMinutesOfDay': bedtimeMinutesOfDay,
      };

  factory AppSettings.fromBackupJson(
    Map<String, dynamic> json, {
    bool isOnboarded = true,
  }) {
    return AppSettings(
      isOnboarded: isOnboarded,
      defaultProtocolId: (json['defaultProtocolId'] as String?) ?? '16_8',
      customDurationMin: (json['customDurationMin'] as num?)?.toInt() ?? 960,
      themeMode: (json['themeMode'] as String?) ?? 'dark',
      notifyGoalReached: (json['notifyGoalReached'] as bool?) ?? true,
      notifyEatingWindow: (json['notifyEatingWindow'] as bool?) ?? false,
      showRemainingTime: (json['showRemainingTime'] as bool?) ?? false,
      bedtimeMinutesOfDay: (json['bedtimeMinutesOfDay'] as num?)?.toInt(),
    );
  }
}
