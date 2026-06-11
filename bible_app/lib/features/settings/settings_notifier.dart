import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/prefs_service.dart';

class SettingsNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      return PrefsService.instance.getThemeMode();
    } catch (_) {
      return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    PrefsService.instance.saveThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<SettingsNotifier, ThemeMode>(
  SettingsNotifier.new,
);
