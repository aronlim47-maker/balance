import 'package:balance/data/mappers/planning_data_mapper.dart';
import 'package:balance/domain/models/local_date.dart';
import 'package:balance/domain/models/planning_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local dates reject normalized invalid dates and preserve leap day', () {
    expect(() => LocalDate.parse('2026-02-29'), throwsFormatException);
    expect(
      () => LocalDate.parse('2026-09-27T00:00:00Z'),
      throwsFormatException,
    );
    expect(LocalDate.parse('2028-02-28').addDays(1).toString(), '2028-02-29');
    expect(LocalDate.parse('2026-12-31').addDays(1), LocalDate(2027, 1, 1));
  });

  Map<String, dynamic> snapshotRow() => {
    'user_id': 'owner',
    'local_date': '2026-09-27',
    'mental_score': null,
    'time_score': 0,
    'physical_score': null,
    'social_score': null,
    'errands_score': null,
    'total_score': null,
    'known_dimensions': ['time'],
    'coverage': 0.3,
    'trend': 'not_enough_history',
    'formula_version': 'world_status_v1',
    'computed_at': '2026-09-27T00:15:00+08:00',
  };

  test(
    'unknown scores remain null while an explicitly known zero stays zero',
    () {
      final result = PlanningDataMapper.worldStatusSnapshot(snapshotRow());
      expect(result.mentalScore, isNull);
      expect(result.timeScore, 0);
      expect(result.totalScore, isNull);
      expect(result.coverage, 0.3);
      expect(result.trend, WorldStatusTrend.notEnoughHistory);
      expect(result.localDate.toString(), '2026-09-27');
      expect(result.computedAt, DateTime.utc(2026, 9, 26, 16, 15));
    },
  );

  test('snapshot known dimensions do not alias the mutable input list', () {
    final row = snapshotRow();
    final result = PlanningDataMapper.worldStatusSnapshot(row);
    (row['known_dimensions'] as List).clear();
    expect(result.knownDimensions, ['time']);
    expect(() => result.knownDimensions.add('mental'), throwsUnsupportedError);
  });

  test('unknown server trend fails visibly instead of becoming stable', () {
    final row = snapshotRow()..['trend'] = 'unexpected';
    expect(
      () => PlanningDataMapper.worldStatusSnapshot(row),
      throwsFormatException,
    );
  });

  test(
    'social response distinguishes no response from explicit known zero',
    () {
      final response = PlanningDataMapper.socialWeekResponse({
        'user_id': 'owner',
        'week_start': '2026-09-21',
        'no_commitments': true,
      });
      expect(response.noSocialCommitments, isTrue);
      expect(response.weekStart, LocalDate(2026, 9, 21));
    },
  );

  test('confirmed exercise retains linkage and stable retry identity', () {
    final log = PlanningDataMapper.exerciseLog({
      'id': 'log',
      'user_id': 'owner',
      'task_id': 'task',
      'occurred_at': '2026-09-27T18:00:00+08:00',
      'duration_minutes': 30,
      'intensity': null,
      'source': 'manual',
      'request_id': 'stable-request',
    });
    expect(log.taskId, 'task');
    expect(log.requestId, 'stable-request');
    expect(log.intensity, isNull);
    expect(log.occurredAt, DateTime.utc(2026, 9, 27, 10));
  });

  test('legacy reflection retains unknown date and maps canonical body', () {
    final reflection = PlanningDataMapper.reflectionEntry({
      'id': 'legacy',
      'user_id': 'owner',
      'body': 'Rest helped.',
      'created_at': '2026-09-28T00:00:00Z',
    });
    expect(reflection.localDate, isNull);
    expect(reflection.requestId, 'legacy');
    expect(reflection.content, 'Rest helped.');
  });

  test('legacy social event accepts neutral pressure and missing retry ID', () {
    final event = PlanningDataMapper.socialEvent({
      'id': 'legacy',
      'user_id': 'owner',
      'start_at': '2026-09-28T00:00:00Z',
      'end_at': '2026-09-28T01:00:00Z',
      'pressure_level': 'neutral',
    });
    expect(event.pressureLevel, EnergyLevel.neutral);
    expect(event.requestId, 'legacy');
    expect(event.hasConflict, isNull);
  });

  test('award retains historical evidence and original rule version', () {
    final award = PlanningDataMapper.achievementAward({
      'user_id': 'owner',
      'achievement_key': 'safe_trade_off',
      'rule_version': 'achievements_v1',
      'source_event_id': 'event',
      'occurred_at': '2026-09-26T12:00:00Z',
      'awarded_at': '2026-09-27T12:00:00Z',
    });
    expect(award.sourceEventId, 'event');
    expect(award.ruleVersion, 'achievements_v1');
    expect(award.occurredAt.isBefore(award.awardedAt), isTrue);
  });
}
