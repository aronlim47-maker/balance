import '../../domain/models/task_item.dart';

abstract interface class TaskRepository {
  Future<List<TaskItem>> fetchTasks();
  Future<TaskItem> createTask(TaskItem task);
  Future<TaskItem> updateTask(TaskItem task);
  Future<void> deleteTask(String taskId);
}
