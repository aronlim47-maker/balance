import 'dart:async';

import 'package:balance/core/state/planning_day_controller.dart';
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/domain/models/plan_change.dart';
import 'package:balance/domain/models/plan_reservation.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/features/council/war_council_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an older plan detail response cannot replace the latest detail',
    () async {
      final plans = _Plans();
      final day = PlanningDayController();
      final model = WarCouncilViewModel(
        LocalTaskRepository(),
        LocalAvailabilityRepository(),
        day,
        plans,
      );
      final first = model.loadChange('first');
      final second = model.loadChange('second');
      plans.reads[1].complete([const PlanChange(id: 'second')]);
      await second;
      plans.reads[0].complete([const PlanChange(id: 'first')]);
      await first;
      expect(model.currentChange?.id, 'second');
      model.dispose();
      day.dispose();
    },
  );

  test('an older task load cannot replace the latest Council load', () async {
    final tasks = _Tasks();
    final day = PlanningDayController();
    final model = WarCouncilViewModel(
      tasks,
      LocalAvailabilityRepository(),
      day,
    );
    final first = model.load();
    final second = model.load();
    tasks.reads[1].complete([_task('new')]);
    await second;
    tasks.reads[0].complete([_task('old')]);
    await first;
    expect(model.protectedTasks.single.id, 'new');
    model.dispose();
    day.dispose();
  });

  test(
    'disposing the account scope invalidates an in-flight Council load',
    () async {
      final tasks = _Tasks();
      final day = PlanningDayController();
      final model = WarCouncilViewModel(
        tasks,
        LocalAvailabilityRepository(),
        day,
      );
      final loading = model.load();
      model.dispose();
      tasks.reads.single.complete([_task('old-account')]);
      await loading;
      expect(model.protectedTasks, isEmpty);
      day.dispose();
    },
  );
}

TaskItem _task(String id) => TaskItem(
  id: id,
  title: id,
  estimatedMinutes: 60,
  dueAt: DateTime.now(),
  isProtected: true,
);

class _Tasks extends LocalTaskRepository {
  final reads = <Completer<List<TaskItem>>>[];
  @override
  Future<List<TaskItem>> fetchTasks() {
    final pending = Completer<List<TaskItem>>();
    reads.add(pending);
    return pending.future;
  }
}

class _Plans implements PlanRepository {
  final reads = <Completer<List<PlanChange>>>[];
  @override
  Future<List<PlanChange>> fetchPlanChanges() {
    final pending = Completer<List<PlanChange>>();
    reads.add(pending);
    return pending.future;
  }

  @override
  Future<List<PlanReservation>> fetchPlanReservations() async => [];
  @override
  Future<int> calculateDayOverload(DateTime day) async => 0;
  @override
  Future<bool> hasWarCouncilMigration() async => true;
  @override
  Future<void> undo(String changeId) async {}
  @override
  Future<PlanChange> confirm({
    required List<PlanMove> moves,
    DateTime? recoveryStart,
    DateTime? recoveryEnd,
    Map<String, dynamic> consequences = const {},
  }) async => const PlanChange(id: 'new');
}
