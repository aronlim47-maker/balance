import 'package:balance/data/repositories/local_planning_repositories.dart';
import 'package:balance/domain/models/movement_models.dart';
import 'package:balance/domain/models/social_event_record.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/today/today_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Social needs weekly event evidence', () async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final social = LocalSocialRepository();
    final viewModel = TodayViewModel(
      LocalTaskRepository(),
      LocalAvailabilityRepository(),
      null,
      null,
      null,
      null,
      null,
      social,
    )..selectDay(day);
    await viewModel.load();
    expect(
      viewModel.worldStatus.dimensions[WorldDimension.social]!.score,
      isNull,
    );

    expect(await viewModel.setNoSocialCommitments(true), isTrue);
    expect(viewModel.worldStatus.dimensions[WorldDimension.social]!.score, 0);
    expect(
      await viewModel.addSocialEvent(
        SocialEventRecord(
          id: '',
          startAt: DateTime(day.year, day.month, day.day, 18),
          endAt: DateTime(day.year, day.month, day.day, 19, 30),
          pressure: SocialPressure.moderate,
        ),
      ),
      isTrue,
      reason: viewModel.errorMessage,
    );
    expect(viewModel.noSocialCommitments, isFalse);
    expect(
      viewModel.worldStatus.dimensions[WorldDimension.social]!.score,
      isNotNull,
    );
    expect(await viewModel.setNoSocialCommitments(true), isFalse);
    expect(
      await viewModel.deleteSocialEvent(viewModel.socialEvents.single.id),
      isTrue,
    );
    expect(
      viewModel.worldStatus.dimensions[WorldDimension.social]!.score,
      isNull,
    );
  });

  test(
    'Physical needs opt-in and an actual record, and can return to Unknown',
    () async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day - 2);
      final occurredAt = DateTime(day.year, day.month, day.day, 12);
      final movement = LocalMovementRepository();
      final viewModel = TodayViewModel(
        LocalTaskRepository(),
        LocalAvailabilityRepository(),
        null,
        null,
        null,
        null,
        movement,
      )..selectDay(day);
      await viewModel.load();

      expect(
        viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
        isNull,
      );
      expect(
        await viewModel.recordExercise(
          ExerciseLog(id: '', occurredAt: occurredAt, durationMinutes: 30),
        ),
        isFalse,
      );

      expect(
        await viewModel.saveMovementSettings(
          const MovementSettings(trackingEnabled: true),
        ),
        isTrue,
        reason: viewModel.errorMessage,
      );
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
        isNull,
      );

      expect(
        await viewModel.recordExercise(
          ExerciseLog(id: '', occurredAt: occurredAt, durationMinutes: 30),
        ),
        isTrue,
      );
      expect(viewModel.exerciseLogsForDay, hasLength(1));
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
        isNotNull,
      );

      expect(
        await viewModel.deleteExercise(viewModel.exerciseLogsForDay.single.id),
        isTrue,
      );
      expect(viewModel.exerciseLogsForDay, isEmpty);
      expect(
        viewModel.worldStatus.dimensions[WorldDimension.physical]!.score,
        isNull,
      );
    },
  );
}
