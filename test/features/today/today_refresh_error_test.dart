import 'package:balance/core/state/planning_day_controller.dart';
import 'package:balance/data/repositories/availability_repository.dart';
import 'package:balance/data/repositories/check_in_repository.dart';
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/movement_repository.dart';
import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/data/repositories/social_repository.dart';
import 'package:balance/data/repositories/task_repository.dart';
import 'package:balance/data/repositories/world_history_repository.dart';
import 'package:balance/domain/enums/load_category.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Today keeps its last plan visible and retries a failed refresh',
    (tester) async {
      final tasks = _FailingTasks();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tasks.createTask(
        TaskItem(
          id: '',
          title: 'Keep this plan visible',
          estimatedMinutes: 60,
          dueAt: today.add(const Duration(hours: 20)),
          scheduledStart: today.add(const Duration(hours: 9)),
          scheduledEnd: today.add(const Duration(hours: 10)),
          loadCategory: LoadCategory.study,
        ),
      );
      final availability = LocalAvailabilityRepository();
      await availability.createAvailability(
        AvailabilityBlock(
          id: '',
          startAt: today.add(const Duration(hours: 8)),
          endAt: today.add(const Duration(hours: 17)),
          isAvailable: true,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthViewModel()),
            ChangeNotifierProvider(create: (_) => PlanningDayController()),
            Provider<TaskRepository>.value(value: tasks),
            Provider<AvailabilityRepository>.value(value: availability),
            Provider<PlanRepository?>.value(value: null),
            Provider<RecoveryRepository?>.value(value: null),
            Provider<CheckInRepository>.value(value: LocalCheckInRepository()),
            Provider<MovementRepository>.value(
              value: LocalMovementRepository(),
            ),
            Provider<SocialRepository>.value(value: LocalSocialRepository()),
            Provider<WorldHistoryRepository?>.value(value: null),
          ],
          child: const MaterialApp(home: TodayScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1h PLANNED'), findsOneWidget);

      tasks.failReads = true;
      await tester.drag(find.byType(ListView).last, const Offset(0, 420));
      await tester.pumpAndSettle();
      expect(find.text('1h PLANNED'), findsOneWidget);
      expect(
        find.text('Could not load today’s plan. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      tasks.failReads = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('1h PLANNED'), findsOneWidget);
      expect(
        find.text('Could not load today’s plan. Please try again.'),
        findsNothing,
      );
    },
  );
}

class _FailingTasks extends LocalTaskRepository {
  bool failReads = false;

  @override
  Future<List<TaskItem>> fetchTasks() {
    if (failReads) throw StateError('Simulated read failure');
    return super.fetchTasks();
  }
}
