import 'package:balance/core/state/planning_day_controller.dart';
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/domain/enums/plan_status.dart';
import 'package:balance/domain/enums/task_flexibility.dart';
import 'package:balance/domain/enums/validation_status.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/plan_change.dart';
import 'package:balance/domain/models/plan_reservation.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/features/council/war_council_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks a matching, flexible plan feasible and confirms it', () async {
    final fixture = await _Fixture.create(serverOverload: 120);
    await fixture.viewModel.load();

    expect(fixture.viewModel.capacity.overloadMinutes, 120);
    expect(fixture.viewModel.validationStatus, ValidationStatus.feasible);
    expect(fixture.viewModel.canConfirm, isTrue);
    expect(await fixture.viewModel.confirmSelectedPlan(), 'change-1');
    expect(fixture.plans.confirmCalls, 1);
    fixture.dispose();
  });

  test('blocks confirmation when Supabase capacity differs', () async {
    final fixture = await _Fixture.create(serverOverload: 0);
    await fixture.viewModel.load();

    expect(fixture.viewModel.validationStatus, ValidationStatus.needsReview);
    expect(fixture.viewModel.capacityMatchesServer, isFalse);
    expect(fixture.viewModel.canConfirm, isFalse);
    expect(await fixture.viewModel.confirmSelectedPlan(), isNull);
    expect(fixture.plans.confirmCalls, 0);
    fixture.dispose();
  });

  test('shows agreement work but cannot confirm it', () async {
    final fixture = await _Fixture.create(
      serverOverload: 120,
      flexibility: TaskFlexibility.needsAgreement,
    );
    await fixture.viewModel.load();

    expect(fixture.viewModel.options, hasLength(1));
    expect(fixture.viewModel.options.single.needsAgreement, isTrue);
    expect(fixture.viewModel.validationStatus, ValidationStatus.needsAgreement);
    expect(fixture.viewModel.canConfirm, isFalse);
    fixture.dispose();
  });

  test('reports no feasible plan and lists fixed work as protected', () async {
    final fixture = await _Fixture.create(
      serverOverload: 120,
      flexibility: TaskFlexibility.fixed,
    );
    await fixture.viewModel.load();

    expect(fixture.viewModel.options, isEmpty);
    expect(fixture.viewModel.validationStatus, ValidationStatus.noFeasiblePlan);
    expect(fixture.viewModel.protectedTasks.single.title, 'Flexible work');
    expect(fixture.viewModel.hasUnscheduledFlexibleWork, isTrue);
    expect(fixture.viewModel.canConfirm, isFalse);
    fixture.dispose();
  });

  test('recognizes a day when every task is protected', () async {
    final fixture = await _Fixture.create(
      serverOverload: 120,
      flexibility: TaskFlexibility.fixed,
      protectDueToday: true,
    );
    await fixture.viewModel.load();

    expect(fixture.viewModel.allDayTasksProtected, isTrue);
    expect(fixture.viewModel.options, isEmpty);
    expect(fixture.viewModel.canConfirm, isFalse);
    fixture.dispose();
  });

  test('does not present a missing deep-linked plan as confirmed', () async {
    final fixture = await _Fixture.create(serverOverload: 120);
    await fixture.viewModel.loadChange('missing-change');

    expect(fixture.viewModel.currentChange, isNull);
    expect(fixture.viewModel.changeNotFound, isTrue);
    expect(fixture.viewModel.isLoadingChange, isFalse);
    fixture.dispose();
  });

  test('keeps a just-confirmed plan visible during a delayed read', () async {
    final fixture = await _Fixture.create(serverOverload: 120);
    await fixture.viewModel.load();
    expect(await fixture.viewModel.confirmSelectedPlan(), 'change-1');
    await fixture.viewModel.loadChange('change-1');

    expect(fixture.viewModel.currentChange?.id, 'change-1');
    expect(fixture.viewModel.changeNotFound, isFalse);
    fixture.dispose();
  });
}

class _Fixture {
  _Fixture(this.viewModel, this.plans, this.dayController);

  final WarCouncilViewModel viewModel;
  final _FakePlanRepository plans;
  final PlanningDayController dayController;

  static Future<_Fixture> create({
    required int serverOverload,
    TaskFlexibility flexibility = TaskFlexibility.flexible,
    bool protectDueToday = false,
  }) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day + 4);
    final nextDay = DateTime(day.year, day.month, day.day + 1);
    final tasks = LocalTaskRepository();
    await tasks.createTask(
      TaskItem(
        id: '',
        title: 'Flexible work',
        estimatedMinutes: 180,
        dueAt: DateTime(day.year, day.month, day.day + 2, 18),
        flexibility: flexibility,
        scheduledStart: DateTime(day.year, day.month, day.day, 9),
        scheduledEnd: DateTime(day.year, day.month, day.day, 12),
      ),
    );
    await tasks.createTask(
      TaskItem(
        id: '',
        title: 'Due today',
        estimatedMinutes: 120,
        dueAt: DateTime(day.year, day.month, day.day, 18),
        isProtected: protectDueToday,
      ),
    );
    final availability = LocalAvailabilityRepository();
    await availability.createAvailability(
      AvailabilityBlock(
        id: '',
        startAt: DateTime(day.year, day.month, day.day, 9),
        endAt: DateTime(day.year, day.month, day.day, 12),
        isAvailable: true,
      ),
    );
    await availability.createAvailability(
      AvailabilityBlock(
        id: '',
        startAt: DateTime(nextDay.year, nextDay.month, nextDay.day, 9),
        endAt: DateTime(nextDay.year, nextDay.month, nextDay.day, 11),
        isAvailable: true,
      ),
    );
    final plans = _FakePlanRepository(serverOverload);
    final dayController = PlanningDayController()..selectDay(day);
    final viewModel = WarCouncilViewModel(
      tasks,
      availability,
      dayController,
      plans,
    );
    return _Fixture(viewModel, plans, dayController);
  }

  void dispose() {
    viewModel.dispose();
    dayController.dispose();
  }
}

class _FakePlanRepository implements PlanRepository {
  _FakePlanRepository(this.serverOverload);

  final int serverOverload;
  int confirmCalls = 0;

  @override
  Future<int> calculateDayOverload(DateTime day) async => serverOverload;

  @override
  Future<bool> hasWarCouncilMigration() async => true;

  @override
  Future<List<PlanReservation>> fetchPlanReservations() async => const [];

  @override
  Future<List<PlanChange>> fetchPlanChanges() async => const [];

  @override
  Future<PlanChange> confirm({
    required List<PlanMove> moves,
    DateTime? recoveryStart,
    DateTime? recoveryEnd,
    Map<String, dynamic> consequences = const <String, dynamic>{},
  }) async {
    confirmCalls++;
    return const PlanChange(id: 'change-1', status: PlanStatus.confirmed);
  }

  @override
  Future<void> undo(String changeId) async {}
}
