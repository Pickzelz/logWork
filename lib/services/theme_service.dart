import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
  static const _kKey = 'theme_mode';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kKey) ?? 'light';
    mode.value = s == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, m == ThemeMode.dark ? 'dark' : 'light');
  }

  static Future<void> toggle() async {
    await setMode(mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
