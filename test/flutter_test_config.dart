import 'dart:async';

import 'package:balance/core/l10n/tr.dart';
import 'package:balance/features/sanctuary/camp_scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Runs before every test file. The Sanctuary campfire flickers for as long
/// as it is on screen in the app; tests draw it still so screens settle.
/// Tests read the English text, so every test starts in English even if an
/// earlier test switched language.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  CampScene.loop = false;
  setUp(() {
    Tr.use(AppLanguage.english);
    Intl.defaultLocale = null;
  });
  await testMain();
}
