import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'balance_colors.dart';
import 'balance_palette.dart';

/// Holds the light/dark choice, saves it on the device and restores it.
///
/// Dark is the default until the user picks light. The choice is stored in
/// [SharedPreferences] (already used by the app) under [storageKey] and is
/// read in `bootstrap()` before the first frame, so the app never flashes
/// the wrong look on start.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode mode = ThemeMode.dark, this._prefs})
      : _mode = _onlyLightOrDark(mode) {
    BalanceColors.use(palette);
  }

  static const storageKey = 'balance.theme_mode';

  ThemeMode _mode;
  SharedPreferences? _prefs;

  /// Reads the saved choice. Falls back to dark if storage is unavailable.
  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      return ThemeController(
        mode: saved == 'light' ? ThemeMode.light : ThemeMode.dark,
        prefs: prefs,
      );
    } catch (_) {
      return ThemeController();
    }
  }

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  BalancePalette get palette =>
      isDark ? BalancePalette.dark : BalancePalette.light;

  /// Switches between dark and light right away and saves the choice.
  Future<void> toggle() =>
      setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setMode(ThemeMode mode) async {
    final next = _onlyLightOrDark(mode);
    if (next == _mode) return;
    _mode = next;
    // Update the shared colour tokens before listeners rebuild the app.
    BalanceColors.use(palette);
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(storageKey, isDark ? 'dark' : 'light');
    } catch (_) {
      // Saving is best effort: the switch still works for this session.
    }
  }

  // Balance has two looks; "follow the system" is not offered, so the look
  // only changes when the user taps the switch.
  static ThemeMode _onlyLightOrDark(ThemeMode mode) =>
      mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
}
