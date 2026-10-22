import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tr.dart';

/// Holds the chosen language, saves it on the device and restores it.
///
/// English is the default until the user picks another language in Profile.
/// Like the theme, the choice is read in `bootstrap()` before the first frame.
class LanguageController extends ChangeNotifier {
  LanguageController({AppLanguage language = AppLanguage.english, this._prefs})
    : _language = language {
    _apply(language);
  }

  static const storageKey = 'balance.language';

  AppLanguage _language;
  SharedPreferences? _prefs;

  AppLanguage get language => _language;
  Locale get locale => Locale(_language.code);

  static Future<LanguageController> load() async {
    await initializeDateFormatting();
    try {
      final prefs = await SharedPreferences.getInstance();
      return LanguageController(
        language: AppLanguage.fromCode(prefs.getString(storageKey)),
        prefs: prefs,
      );
    } catch (_) {
      return LanguageController();
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    _apply(language);
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(storageKey, language.code);
    } catch (_) {
      // Saving is best effort: the change still applies for this session.
    }
  }

  static void _apply(AppLanguage language) {
    Tr.use(language);
    // Dates and times ("Wed 14 Oct", "9:00 AM") follow the language too.
    // English keeps the system default, exactly as before languages existed.
    Intl.defaultLocale = language == AppLanguage.english ? null : language.code;
  }
}
