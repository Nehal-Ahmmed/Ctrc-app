import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final double reportRadius;
  final String languageCode;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.reportRadius = 10.0,
    this.languageCode = 'en',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? reportRadius,
    String? languageCode,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      reportRadius: reportRadius ?? this.reportRadius,
      languageCode: languageCode ?? this.languageCode,
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
    
    state = state.copyWith(
      themeMode: themeMode,
      reportRadius: radius,
      languageCode: lang,
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
