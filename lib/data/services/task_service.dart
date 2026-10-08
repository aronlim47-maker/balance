import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/task_item.dart';
import '../mappers/task_mapper.dart';
import '../repositories/task_repository.dart';
import 'authenticated_user.dart';
import 'owned_rows.dart';

class TaskService implements TaskRepository {
  TaskService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TaskItem>> fetchTasks() async {
    final rows = await readOwnedRows(
      _client,
      (owner) => _client
          .from('tasks')
          .select()
          .eq('user_id', owner)
          .order('due_at')
          .order('id'),
    );
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
    ensureAuthenticatedUserUnchanged(_client, userId);
    return TaskMapper.fromJson(row);
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    final userId = requireAuthenticatedUserId(_client);
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
      ensureAuthenticatedUserUnchanged(_client, userId);
    }
    final row = await _client
        .from('tasks')
        .update(TaskMapper.toUpdate(task, clearSchedule: clearSchedule))
        .eq('id', task.id)
        .eq('version', task.version)
        .select()
        .maybeSingle();
    ensureAuthenticatedUserUnchanged(_client, userId);
    if (row == null) {
      throw StateError('Task edit conflict: refresh before editing again.');
    }
    return TaskMapper.fromJson(row);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final userId = requireAuthenticatedUserId(_client);
    final deleted = await _client
        .from('tasks')
        .delete()
        .eq('id', taskId)
        .select('id')
        .maybeSingle();
    ensureAuthenticatedUserUnchanged(_client, userId);
    if (deleted == null) throw StateError('Deletion not confirmed');
  }
}
