import 'dart:async';
import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/data/repositories/social_repository.dart';
import 'package:balance/domain/models/social_event_record.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saving last week does not mark newly selected week as no commitments', () async {
    final social = _DelayedSocial();
    final vm = TodayViewModel(LocalTaskRepository(), LocalAvailabilityRepository(),
      null, null, null, null, null, social);
    vm.selectDay(DateTime(2026, 9, 28));
    await vm.load();
    final saving = vm.setNoSocialCommitments(true);
    vm.selectDay(DateTime(2026, 10, 5));
    social.complete();
    await saving;
    await vm.load();
    expect(vm.noSocialCommitments, isFalse);
    expect(await social.fetchNoCommitmentsForWeek(DateTime(2026, 9, 28)), isTrue);
    vm.dispose();
  });
}

class _DelayedSocial implements SocialRepository {
  final Completer<void> gate = Completer<void>();
  final Map<int, bool> answers = {};
  void complete() => gate.complete();
  @override
  Future<void> saveNoCommitmentsForWeek(DateTime day, bool value) async {
    await gate.future;
    answers[day.day] = value;
  }
  @override
  Future<bool> fetchNoCommitmentsForWeek(DateTime day) async => answers[day.day] ?? false;
  @override
  Future<List<SocialEventRecord>> fetchEventsForWeek(DateTime day) async => [];
  @override
  Future<SocialEventRecord> createEvent(SocialEventRecord event) async => event;
  @override
  Future<void> deleteEvent(String id) async {}
}
