import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads and persists the selected theme mode', () async {
    SharedPreferences.setMockInitialValues({
      'app.themeMode': ThemeMode.dark.name,
    });
    final container = ProviderContainer.test();
    final controller = container.read(themeControllerProvider.notifier);

    await controller.load();
    expect(container.read(themeControllerProvider), ThemeMode.dark);

    await controller.toggle(Brightness.dark);
    expect(container.read(themeControllerProvider), ThemeMode.light);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app.themeMode'), ThemeMode.light.name);
  });
}
