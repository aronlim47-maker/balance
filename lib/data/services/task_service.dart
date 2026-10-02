import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/task_item.dart';
import '../mappers/task_mapper.dart';
import '../repositories/task_repository.dart';
import 'authenticated_user.dart';

class TaskService implements TaskRepository {
  TaskService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TaskItem>> fetchTasks() async {
    requireAuthenticatedUserId(_client);
    final rows = await _client.from('tasks').select().order('due_at');
    return rows.map(TaskMapper.fromJson).toList(growable: false);
  }

  @override
  Future<TaskItem> createTask(TaskItem task) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('tasks')
        .insert(TaskMapper.toInsert(task, userId))
        .select()
        .single();
    return TaskMapper.fromJson(row);
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    requireAuthenticatedUserId(_client);
    var clearSchedule = false;
    if (task.scheduledStart == null && task.scheduledEnd == null) {
      final current = await _client
          .from('tasks')
          .select('scheduled_start,scheduled_end')
          .eq('id', task.id)
          .single();
      clearSchedule =
          current['scheduled_start'] != null ||
          current['scheduled_end'] != null;
    }
    final row = await _client
        .from('tasks')
        .update(TaskMapper.toUpdate(task, clearSchedule: clearSchedule))
        .eq('id', task.id)
        .eq('version', task.version)
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError('Task edit conflict: refresh before editing again.');
    }
    return TaskMapper.fromJson(row);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    requireAuthenticatedUserId(_client);
    final deleted = await _client
        .from('tasks')
        .delete()
        .eq('id', taskId)
        .select('id')
        .maybeSingle();
    if (deleted == null) throw StateError('Deletion not confirmed');
  }
}
