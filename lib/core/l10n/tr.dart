import 'translations_ms.dart';
import 'translations_zh.dart';

/// The languages Balance can show. English is the source text.
enum AppLanguage {
  english('en', 'English'),
  chinese('zh', '中文'),
  malay('ms', 'Bahasa Melayu');

  const AppLanguage(this.code, this.nativeName);

  final String code;

  /// The language's own name, shown in the picker whatever the current
  /// language is, so a user can always find their language.
  final String nativeName;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.english,
  );
}

/// Translates English UI text into the current language.
///
/// The English text is the key, so English needs no table and any text
/// without a translation falls back to English instead of breaking. Text built
/// with values ("2h over") is matched against pattern keys whose values are
/// written `{0}`, `{1}`… ("{0} over" → "超出 {0}"); the values are translated
/// too when they have an entry of their own (for example a weekday).
///
/// Like `BalanceColors`, the current language is global so text produced
/// outside widgets (Council explanations, notifications) is translated too.
abstract final class Tr {
  static AppLanguage _language = AppLanguage.english;
  static final _cache = <String, String>{};

  static AppLanguage get language => _language;

  static void use(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    _cache.clear();
  }

  static Map<String, String> get _table => switch (_language) {
    AppLanguage.english => const {},
    AppLanguage.chinese => zhTranslations,
    AppLanguage.malay => msTranslations,
  };

  static String of(String english) {
    if (_language == AppLanguage.english || english.isEmpty) return english;
    final cached = _cache[english];
    if (cached != null) return cached;
    final result = _translate(english);
    if (_cache.length > 2000) _cache.clear();
    _cache[english] = result;
    return result;
  }

  static String _translate(String english) {
    final table = _table;
    final exact = table[english];
    if (exact != null) return exact;
    // Keep surrounding spaces and line breaks; translate the text inside.
    final trimmed = english.trim();
    if (trimmed != english && trimmed.isNotEmpty) {
      final inner = table[trimmed];
      if (inner != null) return english.replaceFirst(trimmed, inner);
    }
    for (final pattern in _patterns(table)) {
      final match = pattern.regex.firstMatch(english);
      if (match == null) continue;
      var out = pattern.translation;
      for (var i = 0; i < pattern.slots.length; i++) {
        final value = match.group(i + 1) ?? '';
        out = out.replaceAll('{${pattern.slots[i]}}', _value(value));
      }
      return out;
    }
    return english;
  }

  /// A value captured by a pattern: translated when it has its own entry.
  static String _value(String value) {
    // A value can itself be a translatable sentence ("90 minutes must be
    // moved…" inside a longer message), so run the full lookup on it.
    final translated = of(value);
    return translated != value ? translated : _durations(value);
  }

  /// "2h 30m" / "45m" / "3h" written with the language's own units.
  static String _durations(String value) {
    final match = RegExp(r'^(?:(\d+)h)?\s?(?:(\d+)m)?$').firstMatch(value);
    if (match == null || value.isEmpty) return value;
    final hours = match.group(1);
    final minutes = match.group(2);
    if (hours == null && minutes == null) return value;
    final h = _table['{0}h'] ?? '{0}h';
    final m = _table['{0}m'] ?? '{0}m';
    return [
      if (hours != null) h.replaceAll('{0}', hours),
      if (minutes != null) m.replaceAll('{0}', minutes),
    ].join(_language == AppLanguage.chinese ? '' : ' ');
  }

  static final _compiled = <AppLanguage, List<_Pattern>>{};

  static List<_Pattern> _patterns(Map<String, String> table) =>
      _compiled.putIfAbsent(_language, () {
        final slot = RegExp(r'\{(\d+)\}');
        final patterns = <_Pattern>[];
        table.forEach((key, translation) {
          if (!slot.hasMatch(key)) return;
          final slots = <String>[];
          final buffer = StringBuffer('^');
          var last = 0;
          for (final m in slot.allMatches(key)) {
            buffer.write(RegExp.escape(key.substring(last, m.start)));
            // A slot glued to a unit ("{0}h", "{0}s", "{0}%") is a number,
            // so "Room" can never match "{0}m".
            final next = m.end < key.length ? key[m.end] : ' ';
            final glued = RegExp(r'[A-Za-z%]').hasMatch(next);
            // Other slots may be empty: "task{1}" is "task" or "tasks".
            buffer.write(glued ? r'(\d+(?:\.\d+)?)' : '(.*?)');
            slots.add(m.group(1)!);
            last = m.end;
          }
          buffer.write(RegExp.escape(key.substring(last)));
          buffer.write(r'$');
          patterns.add(
            _Pattern(
              RegExp(buffer.toString(), dotAll: true),
              slots,
              translation,
            ),
          );
        });
        // Longer keys first so the most specific pattern wins.
        patterns.sort(
          (a, b) => b.regex.pattern.length.compareTo(a.regex.pattern.length),
        );
        return patterns;
      });
}

class _Pattern {
  const _Pattern(this.regex, this.slots, this.translation);
  final RegExp regex;
  final List<String> slots;
  final String translation;
}

extension TrString on String {
  /// This English text in the current language.
  String get tr => Tr.of(this);
}
