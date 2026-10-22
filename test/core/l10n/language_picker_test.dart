import 'package:balance/app.dart';
import 'package:balance/core/l10n/language_controller.dart';
import 'package:balance/core/l10n/tr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Profile → Language switches the whole app and back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final language = LanguageController();
    await tester.pumpWidget(BalanceApp(languageController: language));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Language'), 200);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    // Each language is listed in its own script.
    expect(find.text('中文'), findsOneWidget);
    expect(find.text('Bahasa Melayu'), findsOneWidget);
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();

    expect(language.language, AppLanguage.chinese);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('Language'), findsNothing);

    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(language.language, AppLanguage.english);
    expect(find.text('Language'), findsOneWidget);
  });
}
