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
import 'package:balance/features/council/plan_updated_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'capacity evidence and review belong to the original selected day',
    () async {
      final fixture = await _Fixture.create(serverOverload: 120);
      addTearDown(fixture.dispose);
      await fixture.viewModel.load();
      final originalDay = fixture.viewModel.selectedDay;
      final optionId = fixture.viewModel.selectedOptionId;
      final revision = fixture.viewModel.reviewRevision;
      fixture.dayController.selectDay(originalDay.add(const Duration(days: 1)));
      expect(fixture.viewModel.capacityMatchesServer, isFalse);
      expect(
        await fixture.viewModel.confirmSelectedPlan(
          expectedOptionId: optionId,
          expectedRevision: revision,
          expectedSourceDay: originalDay,
        ),
        isNull,
      );
      expect(fixture.plans.confirmCalls, 0);
    },
  );
  test(
    'reviewing an option does not write; stale review cannot confirm',
    () async {
      final fixture = await _Fixture.create(serverOverload: 120);
      addTearDown(fixture.dispose);
      await fixture.viewModel.load();
      final option = fixture.viewModel.selectedOption!;
      final revision = fixture.viewModel.reviewRevision;
      final preview = fixture.viewModel.previewFor(option);
      expect(preview.canApply, isTrue);
      expect(fixture.plans.confirmCalls, 0);
      await fixture.viewModel.load();
      expect(
        await fixture.viewModel.confirmSelectedPlan(
          expectedOptionId: option.id,
          expectedRevision: revision,
        ),
        isNull,
      );
      expect(fixture.plans.confirmCalls, 0);
      expect(fixture.viewModel.errorMessage, contains('changed while'));
    },
  );

  test('current explicit review confirms only the selected option', () async {
    final fixture = await _Fixture.create(serverOverload: 120);
    addTearDown(fixture.dispose);
    await fixture.viewModel.load();
    expect(
      await fixture.viewModel.confirmSelectedPlan(
        expectedOptionId: fixture.viewModel.selectedOptionId,
        expectedRevision: fixture.viewModel.reviewRevision,
      ),
      'change-1',
    );
    expect(fixture.plans.confirmCalls, 1);
    expect(fixture.plans.lastMoves.single.expectedTaskVersion, 1);
  });
  test(
    'combined plan sends every reviewed task move to the repository',
    () async {
      final fixture = await _Fixture.create(
        serverOverload: 120,
        combinedMoves: true,
      );
      addTearDown(fixture.dispose);
      await fixture.viewModel.load();

      expect(fixture.viewModel.options, hasLength(1));
      expect(fixture.viewModel.selectedOption!.allMoves, hasLength(2));
      expect(fixture.viewModel.canConfirm, isTrue);
      expect(await fixture.viewModel.confirmSelectedPlan(), 'change-1');
      expect(fixture.plans.lastMoves, hasLength(2));
      expect(fixture.plans.lastConsequences['task_count'], 2);
    },
  );
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

  test('draft plan is not confirmed and cannot be undone', () async {
    final fixture = await _Fixture.create(serverOverload: 120);
    fixture.plans.changeRows = [
      const PlanChange(id: 'draft-1', status: PlanStatus.draft),
    ];
    await fixture.viewModel.loadChange('draft-1');

    expect(fixture.viewModel.currentChange?.status, PlanStatus.draft);
    expect(fixture.viewModel.canUndoCurrentChange, isFalse);
    expect(await fixture.viewModel.undoPlan('draft-1'), isFalse);
    expect(fixture.plans.undoCalls, 0);
    fixture.dispose();
  });

  test('confirmed plan can be undone once', () async {
    final fixture = await _Fixture.create(serverOverload: 120);
    fixture.plans.changeRows = [
      const PlanChange(id: 'confirmed-1', status: PlanStatus.confirmed),
    ];
    await fixture.viewModel.loadChange('confirmed-1');

    expect(fixture.viewModel.canUndoCurrentChange, isTrue);
    expect(await fixture.viewModel.undoPlan('confirmed-1'), isTrue);
    expect(fixture.viewModel.wasUndone, isTrue);
    expect(fixture.viewModel.canUndoCurrentChange, isFalse);
    expect(await fixture.viewModel.undoPlan('confirmed-1'), isFalse);
    expect(fixture.plans.undoCalls, 1);
    fixture.dispose();
  });

  test('successful undo reports a failed refresh accurately', () async {
    final fixture = await _Fixture.create(serverOverload: 120);
    fixture.plans.changeRows = [
      const PlanChange(id: 'confirmed-1', status: PlanStatus.confirmed),
    ];
    await fixture.viewModel.loadChange('confirmed-1');
    fixture.plans.failReservationReads = true;

    expect(await fixture.viewModel.undoPlan('confirmed-1'), isTrue);
    expect(fixture.plans.undoCalls, 1);
    expect(fixture.viewModel.wasUndone, isTrue);
    expect(fixture.viewModel.refreshWarning, contains('plan was undone'));

    fixture.dispose();
  });

  testWidgets('draft result page never claims a plan was confirmed', (
    tester,
  ) async {
    final fixture = await _Fixture.create(serverOverload: 120);
    fixture.plans.changeRows = [
      const PlanChange(id: 'draft-1', status: PlanStatus.draft),
    ];
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: fixture.viewModel,
        child: const MaterialApp(home: PlanUpdatedScreen(changeId: 'draft-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plan not confirmed'), findsOneWidget);
    expect(find.text('No move applied'), findsOneWidget);
    expect(find.text('Undo this plan'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
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
    bool combinedMoves = false,
  }) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day + 4);
    final nextDay = DateTime(day.year, day.month, day.day + 1);
    final tasks = LocalTaskRepository();
    if (combinedMoves) {
      for (var index = 0; index < 2; index++) {
        final start = DateTime(day.year, day.month, day.day, 9 + index);
        await tasks.createTask(
          TaskItem(
            id: '',
            title: 'Flexible work ${index + 1}',
            estimatedMinutes: 60,
            dueAt: DateTime(day.year, day.month, day.day + 2, 18),
            scheduledStart: start,
            scheduledEnd: start.add(const Duration(hours: 1)),
          ),
        );
      }
    } else {
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
    }
    final availability = LocalAvailabilityRepository();
    if (!combinedMoves) {
      await availability.createAvailability(
        AvailabilityBlock(
          id: '',
          startAt: DateTime(day.year, day.month, day.day, 9),
          endAt: DateTime(day.year, day.month, day.day, 12),
          isAvailable: true,
        ),
      );
    }
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
  List<PlanMove> lastMoves = const [];
  Map<String, dynamic> lastConsequences = const {};
  int undoCalls = 0;
  bool failReservationReads = false;
  List<PlanChange> changeRows = const [];

  @override
  Future<int> calculateDayOverload(DateTime day) async => serverOverload;

  @override
  Future<bool> hasWarCouncilMigration() async => true;

  @override
  Future<List<PlanReservation>> fetchPlanReservations() async {
    if (failReservationReads) throw StateError('Simulated read failure');
    return const [];
  }

  @override
  Future<List<PlanChange>> fetchPlanChanges() async => changeRows;

  @override
  Future<PlanChange> confirm({
    required List<PlanMove> moves,
    DateTime? recoveryStart,
    DateTime? recoveryEnd,
    Map<String, dynamic> consequences = const <String, dynamic>{},
  }) async {
    confirmCalls++;
    lastMoves = moves;
    lastConsequences = consequences;
    return const PlanChange(id: 'change-1', status: PlanStatus.confirmed);
  }

  @override
  Future<void> undo(String changeId) async {
    undoCalls++;
  }
}
