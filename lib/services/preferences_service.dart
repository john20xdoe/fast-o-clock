import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class PreferencesService {
  static const String keyIsOnboarded = 'pref_is_onboarded';
  static const String keyThemeMode = 'pref_theme_mode';
  static const String keyDefaultProtocolId = 'pref_default_protocol_id';
  static const String keyCustomDurationMin = 'pref_custom_duration_min';
  static const String keyNotifyGoalReached = 'pref_notify_goal_reached';
  static const String keyNotifyEatingWindow = 'pref_notify_eating_window';
  static const String keyShowRemainingTime = 'pref_show_remaining_time';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      isOnboarded: prefs.getBool(keyIsOnboarded) ?? false,
      themeMode: prefs.getString(keyThemeMode) ?? 'dark',
      defaultProtocolId: prefs.getString(keyDefaultProtocolId) ?? '16_8',
      customDurationMin: prefs.getInt(keyCustomDurationMin) ?? 960,
      notifyGoalReached: prefs.getBool(keyNotifyGoalReached) ?? true,
      notifyEatingWindow: prefs.getBool(keyNotifyEatingWindow) ?? false,
      showRemainingTime: prefs.getBool(keyShowRemainingTime) ?? false,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsOnboarded, settings.isOnboarded);
    await prefs.setString(keyThemeMode, settings.themeMode);
    await prefs.setString(keyDefaultProtocolId, settings.defaultProtocolId);
    await prefs.setInt(keyCustomDurationMin, settings.customDurationMin);
    await prefs.setBool(keyNotifyGoalReached, settings.notifyGoalReached);
    await prefs.setBool(keyNotifyEatingWindow, settings.notifyEatingWindow);
    await prefs.setBool(keyShowRemainingTime, settings.showRemainingTime);
  }
}
