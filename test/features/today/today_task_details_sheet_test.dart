import 'package:balance/domain/enums/load_category.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/models/plan_reservation.dart';
import 'package:balance/features/today/today_task_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Council reservation shows its time and explanation', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 4);
    final task = TaskItem(
      id: 'moved',
      title: 'Study',
      estimatedMinutes: 180,
      dueAt: day.add(const Duration(days: 3)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayTaskDetailsSheet(
            task: task,
            reservations: [
              PlanReservation(
                taskId: task.id,
                startAt: day.add(const Duration(hours: 9)),
                endAt: day.add(const Duration(hours: 11)),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Council slot'), findsOneWidget);
    expect(find.textContaining('Council moved part'), findsOneWidget);
  });
  testWidgets('unscheduled due task explains its capacity effect', (
    tester,
  ) async {
    final task = TaskItem(
      id: 'due',
      title: 'Review lecture notes',
      estimatedMinutes: 60,
      dueAt: DateTime(2026, 9, 27, 18),
      loadCategory: LoadCategory.study,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TodayTaskDetailsSheet(task: task)),
      ),
    );

    expect(find.text('Review lecture notes'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.textContaining('no time slot is reserved'), findsOneWidget);
  });

  testWidgets('scheduled task shows its time and capacity effect', (
    tester,
  ) async {
    final task = TaskItem(
      id: 'scheduled',
      title: 'Project meeting',
      estimatedMinutes: 60,
      dueAt: DateTime(2026, 9, 30, 18),
      scheduledStart: DateTime(2026, 9, 27, 9),
      scheduledEnd: DateTime(2026, 9, 27, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TodayTaskDetailsSheet(task: task)),
      ),
    );

    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.textContaining('overlaps this day'), findsOneWidget);
    expect(find.text('Needs Review'), findsOneWidget);
  });
}
