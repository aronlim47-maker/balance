import '../../domain/models/task_item.dart';

abstract interface class TaskRepository {
  Future<List<TaskItem>> fetchTasks();
}
