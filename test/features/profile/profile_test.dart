import 'package:balance/data/repositories/availability_repository.dart';
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/data/repositories/profile_repository.dart';
import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/data/repositories/task_repository.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/app_profile.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/profile/profile_screen.dart';
import 'package:balance/features/profile/profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('summarizes local tasks and labels workload pressure', () async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final tasks = LocalTaskRepository();
    await tasks.createTask(
      TaskItem(
        id: '',
        title: 'Prepare demo',
        estimatedMinutes: 120,
        dueAt: day.add(const Duration(hours: 18)),
      ),
    );
    final availability = LocalAvailabilityRepository();
    await availability.createAvailability(
      AvailabilityBlock(
        id: '',
        startAt: day.add(const Duration(hours: 9)),
        endAt: day.add(const Duration(hours: 10)),
        isAvailable: true,
      ),
    );
    final viewModel = ProfileViewModel(tasks, availability);

    await viewModel.load();

    expect(viewModel.plannedTaskCount, 1);
    expect(viewModel.completedTaskCount, 0);
    expect(viewModel.confirmedPlanCount, isNull);
    expect(viewModel.todayCapacity.overloadMinutes, 60);
    expect(viewModel.stressMeterPercent, 100);
    viewModel.dispose();
  });

  test('loads and updates the signed-in planning time zone', () async {
    final repository = _FakeProfileRepository();
    final viewModel = ProfileViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
      null,
      null,
      repository,
    );

    await viewModel.load();
    expect(viewModel.userProfile?.timeZone, 'UTC');
    expect(await viewModel.saveTimeZone(' Asia/Kuala_Lumpur '), isTrue);
    expect(repository.lastSaved, 'Asia/Kuala_Lumpur');
    expect(viewModel.userProfile?.timeZone, 'Asia/Kuala_Lumpur');
    viewModel.dispose();
  });

  testWidgets('shows local mode and disables sign out', (tester) async {
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
          Provider<ProfileRepository?>.value(value: null),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Stress meter'), findsOneWidget);
    expect(find.textContaining('Local preview'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sign out'), 240);
    final signOut = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign out'),
    );
    expect(signOut.onPressed, isNull);
  });
}

class _FakeProfileRepository implements ProfileRepository {
  String? lastSaved;

  @override
  Future<AppProfile> fetchProfile() async =>
      const AppProfile(displayName: 'Tester', timeZone: 'UTC');

  @override
  Future<AppProfile> updateTimeZone(String timeZone) async {
    lastSaved = timeZone;
    return AppProfile(displayName: 'Tester', timeZone: timeZone);
  }
}
