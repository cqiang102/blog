import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  static const _preferenceKey = 'app.themeMode';

  @override
  ThemeMode build() {
    Future.microtask(load);
    return ThemeMode.system;
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_preferenceKey);
    final nextMode = switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    if (state == nextMode || !ref.mounted) return;
    state = nextMode;
  }

  Future<void> toggle(Brightness currentBrightness) async {
    await setMode(
      currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, mode.name);
  }
}
