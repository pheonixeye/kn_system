import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

class ThemeProvider extends ChangeNotifier {
  static const _boxName = 'settings';
  static const _modeKey = 'themeMode';
  static ThemeProvider? instance;

  Box? _box;
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    final stored = _box!.get(_modeKey);
    if (stored == 'dark') {
      _mode = ThemeMode.dark;
    }
    instance = this;
  }

  Future<void> toggleTheme() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    await _box?.put(_modeKey, isDark ? 'dark' : 'light');
    notifyListeners();
  }
}
