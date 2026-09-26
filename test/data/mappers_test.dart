import 'package:balance/data/mappers/availability_mapper.dart';
import 'package:balance/data/mappers/check_in_mapper.dart';
import 'package:balance/data/mappers/plan_mapper.dart';
import 'package:balance/data/mappers/recovery_mapper.dart';
import 'package:balance/data/mappers/task_mapper.dart';
import 'package:balance/data/repositories/plan_repository.dart';
import 'package:balance/domain/enums/plan_status.dart';
import 'package:balance/domain/enums/task_flexibility.dart';
import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/enums/validation_status.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/check_in.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase mappers', () {
    test('maps a task in both directions', () {
      final task = TaskMapper.fromJson({
        'id': 'task-1',
        'title': 'Prepare demo',
        'estimated_minutes': 90,
        'remaining_minutes': 60,
        'due_at': '2026-09-30T10:00:00Z',
        'scheduled_start': '2026-09-29T08:00:00Z',
        'scheduled_end': '2026-09-29T09:00:00Z',
        'flexibility': 'needs_agreement',
        'status': 'planned',
        'is_protected': false,
        'is_optional': true,
      });

      expect(task.remainingMinutes, 60);
      expect(task.flexibility, TaskFlexibility.needsAgreement);
      expect(task.status, TaskStatus.planned);
      expect(
        TaskMapper.toInsert(task, 'user-1'),
        containsPair('user_id', 'user-1'),
      );
    });

    test('omits untouched schedule fields but can explicitly clear them', () {
      final task = TaskItem(
        id: 'task-2',
        title: 'Unscheduled task',
        estimatedMinutes: 30,
        dueAt: DateTime.utc(2026, 9, 30, 18),
        flexibility: TaskFlexibility.flexible,
      );
      expect(TaskMapper.toUpdate(task), isNot(contains('scheduled_start')));
      expect(TaskMapper.toUpdate(task), isNot(contains('scheduled_end')));
      expect(
        TaskMapper.toUpdate(task, clearSchedule: true),
        containsPair('scheduled_start', null),
      );
      expect(
        TaskMapper.toUpdate(task, clearSchedule: true),
        containsPair('scheduled_end', null),
      );
    });

    test('maps availability blocks', () {
      final block = AvailabilityMapper.fromJson({
        'id': 'availability-1',
        'start_at': '2026-09-29T08:00:00Z',
        'end_at': '2026-09-29T12:00:00Z',
        'block_type': 'available',
        'label': 'Morning',
      });

      expect(block.isAvailable, isTrue);
      expect(
        AvailabilityMapper.toInsert(block, 'user-1'),
        containsPair('block_type', 'available'),
      );
    });

    test('maps and serializes a check-in date', () {
      final checkIn = CheckInMapper.fromJson({
        'id': 'check-in-1',
        'check_in_date': '2026-09-29',
        'sleep_hours': 7.5,
        'mental': 4,
        'physical': 3,
        'social': 5,
        'errands': 2,
      });

      expect(checkIn.sleepHours, 7.5);
      expect(
        CheckInMapper.toUpsert(checkIn, 'user-1'),
        containsPair('check_in_date', '2026-09-29'),
      );
    });

    test('maps a confirmed plan change', () {
      final plan = PlanMapper.fromJson({
        'id': 'plan-1',
        'status': 'confirmed',
        'before_overload_minutes': 120,
        'after_overload_minutes': 0,
        'validation_status': 'feasible',
        'consequences': {'moved_tasks': 1},
        'confirmed_at': '2026-09-29T09:00:00Z',
        'created_at': '2026-09-29T08:30:00Z',
      });

      expect(plan.status, PlanStatus.confirmed);
      expect(plan.validationStatus, ValidationStatus.feasible);
      expect(plan.consequences['moved_tasks'], 1);
    });

    test('maps recovery slots and plan moves', () {
      final slot = RecoveryMapper.fromJson({
        'id': 'recovery-1',
        'plan_change_id': 'plan-1',
        'start_at': '2026-09-29T12:00:00Z',
        'end_at': '2026-09-29T12:30:00Z',
        'is_protected': true,
        'selected_activity': 'Walk',
        'completed_at': null,
      });
      final move = PlanMove(
        taskId: 'task-1',
        proposedStart: DateTime.utc(2026, 9, 29, 14),
        proposedEnd: DateTime.utc(2026, 9, 29, 15),
        movedMinutes: 60,
      );

      expect(slot.isProtected, isTrue);
      expect(move.toJson(), containsPair('moved_minutes', 60));
    });
  });

  group('Mapper write payloads', () {
    test('keep user ownership in insert payloads', () {
      final availability = AvailabilityBlock(
        id: 'new',
        startAt: DateTime.utc(2026, 9, 29, 8),
        endAt: DateTime.utc(2026, 9, 29, 9),
        isAvailable: true,
      );
      final checkIn = CheckIn(date: DateTime(2026, 9, 29));
      final recovery = RecoverySlot(
        id: 'new',
        startAt: DateTime.utc(2026, 9, 29, 12),
        endAt: DateTime.utc(2026, 9, 29, 12, 30),
      );
      final task = TaskItem(
        id: 'new',
        title: 'Prepare demo',
        estimatedMinutes: 60,
        dueAt: DateTime.utc(2026, 9, 30),
      );

      expect(
        AvailabilityMapper.toInsert(availability, 'user-1')['user_id'],
        'user-1',
      );
      expect(CheckInMapper.toUpsert(checkIn, 'user-1')['user_id'], 'user-1');
      expect(RecoveryMapper.toInsert(recovery, 'user-1')['user_id'], 'user-1');
      expect(TaskMapper.toInsert(task, 'user-1')['user_id'], 'user-1');
    });
  });
}
