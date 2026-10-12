import 'dart:async';

import 'package:balance/features/sanctuary/camp_scene.dart';

/// Runs before every test file. The Sanctuary campfire flickers for as long
/// as it is on screen in the app; tests draw it still so screens settle.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  CampScene.loop = false;
  await testMain();
}
