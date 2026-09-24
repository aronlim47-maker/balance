import 'package:flutter/foundation.dart';

import '../../domain/models/task_item.dart';

class QuestBoardViewModel extends ChangeNotifier {
  final List<TaskItem> _tasks = [];
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
}
