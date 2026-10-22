import 'package:balance/core/l10n/dates.dart';
import 'package:balance/core/l10n/language_controller.dart';
import 'package:balance/core/l10n/translations_ms.dart';
import 'package:balance/core/l10n/translations_zh.dart';
import 'package:balance/core/l10n/tr.dart';
import 'package:balance/domain/enums/load_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('English is the source text and is returned unchanged', () {
    expect('Sign in'.tr, 'Sign in');
    expect('2h over'.tr, '2h over');
    expect(AppDates.weekdayDayMonth(DateTime(2026, 10, 14)), 'Wed 14 Oct');
    expect(AppDates.clock(DateTime(2026, 10, 14, 20, 5)), '8:05 PM');
  });

  test('exact text, patterns, nested values and units in Chinese', () {
    Tr.use(AppLanguage.chinese);
    expect('Sign in'.tr, '登录');
    // A pattern whose value is a duration in the language's own units.
    expect('2h 30m over'.tr, '超出 2小时30分钟');
    // A value that is itself a translated sentence.
    expect(
      '90 minutes must be moved, reduced or recovered. '
              'All of it is due before your free time starts.'
          .tr,
      '需要移动、减少或恢复 90 分钟。全部都在你的空闲时间开始前到期。',
    );
    // Plural slots may be empty: "1 task" and "2 tasks" both match.
    expect('1 task updated.'.tr, '已更新 1 个任务。');
    expect('2 tasks updated.'.tr, '已更新 2 个任务。');
    // A word ending in "m" is not mistaken for minutes.
    expect('Room'.tr, '空余');
    // Unknown text falls back to English instead of breaking.
    expect('Something new'.tr, 'Something new');
    // Enum labels follow the language.
    expect(LoadCategory.study.label, '学习');
  });

  test('Malay uses its own table and keeps placeholders', () {
    Tr.use(AppLanguage.malay);
    expect('Add task'.tr, 'Tambah tugas');
    expect('Try again in 42s'.tr, 'Cuba lagi dalam 42s');
  });

  test('both tables cover the same text and keep every placeholder', () {
    expect(msTranslations.keys.toSet(), zhTranslations.keys.toSet());
    final slot = RegExp(r'\{\d+\}');
    for (final table in [zhTranslations, msTranslations]) {
      table.forEach((english, translated) {
        expect(translated.trim(), isNotEmpty, reason: english);
        final allowed = slot.allMatches(english).map((m) => m[0]).toSet();
        for (final used in slot.allMatches(translated)) {
          expect(allowed, contains(used[0]), reason: english);
        }
      });
    }
  });

  test('the choice is saved and restored', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await LanguageController.load();
    expect(controller.language, AppLanguage.english);
    await controller.setLanguage(AppLanguage.malay);
    expect(Tr.language, AppLanguage.malay);
    expect(AppDates.weekday(DateTime(2026, 10, 14)), isNot('Wed'));

    final restored = await LanguageController.load();
    expect(restored.language, AppLanguage.malay);
    expect(restored.locale.languageCode, 'ms');
  });
}
