import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads and persists the selected theme mode', () async {
    SharedPreferences.setMockInitialValues({
      'app.themeMode': ThemeMode.dark.name,
    });
    final controller = ThemeController();

    await controller.load();
    expect(controller.mode, ThemeMode.dark);

    await controller.toggle(Brightness.dark);
    expect(controller.mode, ThemeMode.light);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app.themeMode'), ThemeMode.light.name);
  });
}
