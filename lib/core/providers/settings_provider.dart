import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';

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
  SettingsNotifier({LocalStore? store})
      : _store = store ?? LocalStore.instance,
        super(_restore(store ?? LocalStore.instance));

  final LocalStore _store;

  /// Read before the first frame rather than after it. Loading the theme
  /// asynchronously meant the app painted in the system theme and then snapped
  /// to the chosen one — a visible flash on every launch for anyone who had
  /// picked dark mode.
  static SettingsState _restore(LocalStore store) {
    final themeIndex = store.getInt(StorageKeys.themeMode);

    return SettingsState(
      themeMode: (themeIndex != null &&
              themeIndex >= 0 &&
              themeIndex < ThemeMode.values.length)
          ? ThemeMode.values[themeIndex]
          : ThemeMode.system,
      reportRadius: store.getDouble(StorageKeys.reportRadius) ?? 10.0,
      languageCode: store.getString(StorageKeys.languageCode) ?? 'en',
      nearbyAlertsEnabled: store.getBool(StorageKeys.nearbyAlerts) ?? true,
    );
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.setInt(StorageKeys.themeMode, mode.index);
  }

  Future<void> updateReportRadius(double radius) async {
    state = state.copyWith(reportRadius: radius);
    await _store.setDouble(StorageKeys.reportRadius, radius);
  }

  Future<void> updateLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    await _store.setString(StorageKeys.languageCode, code);
  }

  Future<void> updateNearbyAlerts(bool enabled) async {
    state = state.copyWith(nearbyAlertsEnabled: enabled);
    await _store.setBool(StorageKeys.nearbyAlerts, enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
