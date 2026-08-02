import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final double reportRadius;
  final String languageCode;

  /// Collect in-app alerts for incidents reported inside [reportRadius].
  final bool nearbyAlertsEnabled;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.reportRadius = 10.0,
    this.languageCode = 'en',
    this.nearbyAlertsEnabled = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? reportRadius,
    String? languageCode,
    bool? nearbyAlertsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      reportRadius: reportRadius ?? this.reportRadius,
      languageCode: languageCode ?? this.languageCode,
      nearbyAlertsEnabled: nearbyAlertsEnabled ?? this.nearbyAlertsEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme
    final themeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    final themeMode = ThemeMode.values[themeIndex];

    // Load radius
    final radius = prefs.getDouble('report_radius') ?? 10.0;

    // Load language
    final lang = prefs.getString('language_code') ?? 'en';

    // Load alert preference
    final alerts = prefs.getBool('nearby_alerts_enabled') ?? true;

    state = state.copyWith(
      themeMode: themeMode,
      reportRadius: radius,
      languageCode: lang,
      nearbyAlertsEnabled: alerts,
    );
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> updateReportRadius(double radius) async {
    state = state.copyWith(reportRadius: radius);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('report_radius', radius);
  }

  Future<void> updateLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
  }

  Future<void> updateNearbyAlerts(bool enabled) async {
    state = state.copyWith(nearbyAlertsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nearby_alerts_enabled', enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
