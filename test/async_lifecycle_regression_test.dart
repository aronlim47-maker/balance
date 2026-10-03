import 'dart:async';

import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/recovery_repository.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/domain/models/social_event_record.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/profile/profile_view_model.dart';
import 'package:balance/features/sanctuary/sanctuary_view_model.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Today ignores a load that finishes after disposal', () async {
    final tasks = _DelayedTasks();
    final model = TodayViewModel(tasks, LocalAvailabilityRepository());
    var notifications = 0;
    model.addListener(() => notifications++);
    final loading = model.load();
    model.dispose();
    final before = notifications;
    tasks.pending.complete([]);
    await loading;
    expect(notifications, before);
  });

  test('Profile can close while its child Today is loading', () async {
    final tasks = _DelayedTasks();
    final model = ProfileViewModel(tasks, LocalAvailabilityRepository());
    var notifications = 0;
    model.addListener(() => notifications++);
    final loading = model.load();
    model.dispose();
    final before = notifications;
    tasks.pending.complete([]);
    await loading;
    expect(notifications, before);
  });

  test('Sanctuary ignores loads after disposal', () async {
    final repository = _ControlledRecovery();
    final model = SanctuaryViewModel(repository);
    final loading = model.load();
    model.dispose();
    repository.reads.single.complete([_slot('late')]);
    await loading;
    expect(model.slots, isEmpty);
  });

  test('Sanctuary accepts only the newest concurrent refresh', () async {
    final repository = _ControlledRecovery();
    final model = SanctuaryViewModel(repository);
    final first = model.load();
    final second = model.load();
    repository.reads[1].complete([_slot('new')]);
    await second;
    repository.reads[0].complete([_slot('old')]);
    await first;
    expect(model.slots.single.id, 'new');
    model.dispose();
  });

  test(
    'refresh cannot unlock or replace an in-flight Sanctuary save',
    () async {
      final repository = _ControlledRecovery();
      final model = SanctuaryViewModel(repository);
      final saving = model.save(_slot(''));
      await model.load();
      expect(repository.reads, isEmpty);
      expect(model.busy, isTrue);
      expect(await model.save(_slot('')), isFalse);
      repository.write.complete(_slot('saved'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, hasLength(1));
      expect(model.busy, isTrue);
      await model.load();
      expect(repository.reads, hasLength(1));
      repository.reads.single.complete([_slot('saved')]);
      expect(await saving, isTrue);
      expect(model.busy, isFalse);
      expect(model.slots.single.id, 'saved');
      model.dispose();
    },
  );

  test('failed social creation keeps the previous weekly response', () async {
    final social = _FailingSocial();
    final day = DateTime.now();
    await social.saveNoCommitmentsForWeek(day, true);
    final model = TodayViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
      null,
      null,
      null,
      null,
      null,
      social,
    );
    await model.load();
    expect(await model.addSocialEvent(_event(day)), isFalse);
    expect(await social.fetchNoCommitmentsForWeek(day), isTrue);
    expect(model.noSocialCommitments, isTrue);
    model.dispose();
  });

  test('social creation clears the response and refreshes the view', () async {
    final social = LocalSocialRepository();
    final day = DateTime.now();
    await social.saveNoCommitmentsForWeek(day, true);
    final model = TodayViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
      null,
      null,
      null,
      null,
      null,
      social,
    );
    await model.load();
    expect(await model.addSocialEvent(_event(day)), isTrue);
    expect(model.noSocialCommitments, isFalse);
    expect(model.socialEvents, hasLength(1));
    model.dispose();
  });
}

RecoverySlot _slot(String id) => RecoverySlot(
  id: id,
  startAt: DateTime(2026, 10, 1, 9),
  endAt: DateTime(2026, 10, 1, 10),
);

SocialEventRecord _event(DateTime day) => SocialEventRecord(
  id: '',
  startAt: day,
  endAt: day.add(const Duration(hours: 1)),
  pressure: SocialPressure.low,
);

class _DelayedTasks extends LocalTaskRepository {
  final pending = Completer<List<TaskItem>>();
  @override
  Future<List<TaskItem>> fetchTasks() => pending.future;
}

class _FailingSocial extends LocalSocialRepository {
  @override
  Future<SocialEventRecord> createEvent(SocialEventRecord event) async {
    throw StateError('Simulated transaction failure');
  }
}

class _ControlledRecovery implements RecoveryRepository {
  final reads = <Completer<List<RecoverySlot>>>[];
  final write = Completer<RecoverySlot>();
  @override
  Future<List<RecoverySlot>> fetchRecoverySlots() {
    final pending = Completer<List<RecoverySlot>>();
    reads.add(pending);
    return pending.future;
  }

  @override
  Future<RecoverySlot> createRecoverySlot(RecoverySlot slot) => write.future;
  @override
  Future<RecoverySlot> updateRecoverySlot(RecoverySlot slot) => write.future;
  @override
  Future<void> deleteRecoverySlot(String id) async {
    await write.future;
  }
}
