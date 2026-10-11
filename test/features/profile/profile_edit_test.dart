import 'dart:convert';

import 'package:balance/data/repositories/availability_repository.dart';
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/data/repositories/profile_repository.dart';
import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/data/repositories/task_repository.dart';
import 'package:balance/domain/models/app_profile.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/profile/avatar_store.dart';
import 'package:balance/features/profile/profile_avatar.dart';
import 'package:balance/features/profile/profile_screen.dart';
import 'package:balance/features/profile/profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A valid 1×1 PNG, small enough to decode in tests.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _Profiles implements ProfileRepository {
  String name = 'Tester';
  String? lastSaved;

  @override
  Future<AppProfile> fetchProfile() async =>
      AppProfile(displayName: name, timeZone: 'UTC');

  @override
  Future<AppProfile> updateTimeZone(String timeZone) async =>
      AppProfile(displayName: name, timeZone: timeZone);

  @override
  Future<AppProfile> updateDisplayName(String displayName) async {
    lastSaved = displayName;
    name = displayName;
    return AppProfile(displayName: displayName, timeZone: 'UTC');
  }
}

ProfileViewModel _viewModel(ProfileRepository profiles) => ProfileViewModel(
  LocalTaskRepository(),
  LocalAvailabilityRepository(),
  null,
  null,
  profiles,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Edit name', () {
    test('saves a trimmed name', () async {
      final profiles = _Profiles();
      final viewModel = _viewModel(profiles);
      await viewModel.load();

      expect(await viewModel.saveDisplayName('  Yi Ming  '), isTrue);
      expect(profiles.lastSaved, 'Yi Ming');
      expect(viewModel.userProfile?.displayName, 'Yi Ming');
      viewModel.dispose();
    });

    test('rejects an empty or too long name without saving', () async {
      final profiles = _Profiles();
      final viewModel = _viewModel(profiles);
      await viewModel.load();

      expect(await viewModel.saveDisplayName('   '), isFalse);
      expect(viewModel.errorMessage, 'Enter a name.');
      expect(
        await viewModel.saveDisplayName(
          'x' * (ProfileViewModel.maxNameLength + 1),
        ),
        isFalse,
      );
      expect(profiles.lastSaved, isNull);
      viewModel.dispose();
    });

    testWidgets('the pencil opens a dialog and the new name shows', (
      tester,
    ) async {
      final profiles = _Profiles();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            Provider<TaskRepository>(create: (_) => LocalTaskRepository()),
            Provider<AvailabilityRepository>(
              create: (_) => LocalAvailabilityRepository(),
            ),
            Provider<PlanRepository?>.value(value: null),
            Provider<RecoveryRepository?>.value(value: null),
            Provider<ProfileRepository?>.value(value: profiles),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tester'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Yi Ming');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(profiles.lastSaved, 'Yi Ming');
      expect(find.text('Yi Ming'), findsOneWidget);
      expect(find.text('Name updated.'), findsOneWidget);
    });
  });

  group('Profile picture', () {
    test('is saved, loaded and removed per account on this phone', () async {
      const store = AvatarStore();
      expect(await store.load('user-1'), isNull);

      expect(await store.save('user-1', _png), isTrue);
      expect(await store.load('user-1'), _png);
      // Another account on the same phone has its own picture.
      expect(await store.load('user-2'), isNull);

      expect(await store.remove('user-1'), isTrue);
      expect(await store.load('user-1'), isNull);
    });

    testWidgets('shows the initial, then the chosen photo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfileAvatar(
                owner: 'user-1',
                initial: 'Y',
                pickImage: () async => _png,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Y'), findsOneWidget);

      await tester.tap(find.byTooltip('Change profile picture'));
      await tester.pumpAndSettle();
      expect(find.text('Saved on this phone only'), findsOneWidget);
      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();

      expect(find.text('Profile picture updated.'), findsOneWidget);
      expect(find.text('Y'), findsNothing);
      expect(await const AvatarStore().load('user-1'), _png);

      await tester.tap(find.byTooltip('Change profile picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(find.text('Y'), findsOneWidget);
      expect(await const AvatarStore().load('user-1'), isNull);
    });
  });
}
