import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

typedef ThemePreferencesLoader = Future<SharedPreferences> Function();

/// Injectable so initialization/write ordering can be tested deterministically.
final themePreferencesLoaderProvider = Provider<ThemePreferencesLoader>(
  (ref) => SharedPreferences.getInstance,
);

class ThemeController extends Notifier<ThemeMode> {
  static const _preferenceKey = 'app.themeMode';
  int _mutationVersion = 0;

  @override
  ThemeMode build() {
    _mutationVersion = 0;
    Future.microtask(load);
    return ThemeMode.system;
  }

  Future<void> load() async {
    final version = _mutationVersion;
    final preferences = await ref.read(themePreferencesLoaderProvider)();
    final savedMode = preferences.getString(_preferenceKey);
    final nextMode = switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    if (!ref.mounted || version != _mutationVersion || state == nextMode) {
      return;
    }
    state = nextMode;
  }

  Future<void> toggle(Brightness currentBrightness) async {
    await setMode(
      currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    _mutationVersion += 1;
    state = mode;

    final preferences = await ref.read(themePreferencesLoaderProvider)();
    await preferences.setString(_preferenceKey, mode.name);
  }
}
