import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';
import 'quest_board_view_model.dart';
import 'task_card.dart';
import 'task_form_screen.dart';

class QuestBoardScreen extends StatelessWidget {
  const QuestBoardScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        QuestBoardViewModel(context.read<TaskRepository>())..loadTasks(),
    child: const _QuestBoardContent(),
  );
}

class _QuestBoardContent extends StatefulWidget {
  const _QuestBoardContent();

  @override
  State<_QuestBoardContent> createState() => _QuestBoardContentState();
}

class _QuestBoardContentState extends State<_QuestBoardContent> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<QuestBoardViewModel>(
    builder: (context, viewModel, _) => BalanceScaffold(
      title: 'Quest Board',
      currentIndex: 1,
      actions: [
        PopupMenuButton<QuestSort>(
          tooltip: 'Sort tasks: ${_sortLabel(viewModel.sort)}',
          icon: const Icon(Icons.sort),
          onSelected: viewModel.setSort,
          itemBuilder: (_) => [
            for (final sort in QuestSort.values)
              CheckedPopupMenuItem(
                value: sort,
                checked: viewModel.sort == sort,
                child: Text(_sortLabel(sort)),
              ),
          ],
        ),
        IconButton(
          tooltip: 'Add task',
          onPressed: () => _openTaskForm(context, viewModel),
          icon: const Icon(Icons.add),
        ),
      ],
      body: _body(context, viewModel),
    ),
  );

  Widget _body(BuildContext context, QuestBoardViewModel viewModel) {
    if (viewModel.isLoading && viewModel.tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.errorMessage != null && viewModel.tasks.isEmpty) {
      return _ErrorState(
        message: viewModel.errorMessage!,
        onRetry: viewModel.loadTasks,
      );
    }
    if (viewModel.tasks.isEmpty) {
      return _EmptyState(onAdd: () => _openTaskForm(context, viewModel));
    }

    final visibleTasks = viewModel.visibleTasks;
    return Column(
      children: [
        _filters(context, viewModel),
        Expanded(
          child: RefreshIndicator(
            onRefresh: viewModel.loadTasks,
            child: visibleTasks.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.search_off_outlined, size: 48),
                      const SizedBox(height: 12),
                      const Center(child: Text('No matching tasks')),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => _clearFilters(viewModel),
                          child: const Text('Clear filters'),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleTasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = visibleTasks[index];
                      return TaskCard(
                        task: task,
                        onEdit: () =>
                            _openTaskForm(context, viewModel, task: task),
                        onDelete: () =>
                            _confirmDelete(context, viewModel, task),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filters(BuildContext context, QuestBoardViewModel viewModel) {
    final dates = viewModel.startDate == null
        ? 'Date range'
        : '${DateFormat.MMMd().format(viewModel.startDate!)}–${DateFormat.MMMd().format(viewModel.endDate!)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: viewModel.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search tasks',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: viewModel.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        viewModel.setSearchQuery('');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Filter by status',
                  onSelected: (value) =>
                      viewModel.setStatusFilter(switch (value) {
                        'planned' => TaskStatus.planned,
                        'completed' => TaskStatus.completed,
                        'cancelled' => TaskStatus.cancelled,
                        _ => null,
                      }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('All statuses')),
                    PopupMenuItem(value: 'planned', child: Text('Planned')),
                    PopupMenuItem(value: 'completed', child: Text('Completed')),
                    PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  child: Chip(
                    label: Text(
                      'Status: ${_statusLabel(viewModel.statusFilter)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Filter by flexibility',
                  onSelected: (value) =>
                      viewModel.setFlexibilityFilter(switch (value) {
                        'flexible' => TaskFlexibility.flexible,
                        'fixed' => TaskFlexibility.fixed,
                        'agreement' => TaskFlexibility.needsAgreement,
                        _ => null,
                      }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('All types')),
                    PopupMenuItem(value: 'flexible', child: Text('Flexible')),
                    PopupMenuItem(value: 'fixed', child: Text('Fixed')),
                    PopupMenuItem(
                      value: 'agreement',
                      child: Text('Needs agreement'),
                    ),
                  ],
                  child: Chip(
                    label: Text(
                      'Type: ${_flexibilityLabel(viewModel.flexibilityFilter)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Filter protected tasks',
                  onSelected: (value) =>
                      viewModel.setProtectedFilter(switch (value) {
                        'protected' => true,
                        'unprotected' => false,
                        _ => null,
                      }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('All tasks')),
                    PopupMenuItem(value: 'protected', child: Text('Protected')),
                    PopupMenuItem(
                      value: 'unprotected',
                      child: Text('Not protected'),
                    ),
                  ],
                  child: Chip(
                    label: Text(
                      'Protection: ${viewModel.protectedFilter == null
                          ? 'All'
                          : viewModel.protectedFilter!
                          ? 'Yes'
                          : 'No'}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(dates),
                  onPressed: () => _pickDateRange(context, viewModel),
                ),
                if (viewModel.startDate != null)
                  IconButton(
                    tooltip: 'Clear date range',
                    onPressed: () => viewModel.setDateRange(null, null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          if (viewModel.hasActiveFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _clearFilters(viewModel),
                child: const Text('Clear filters'),
              ),
            ),
        ],
      ),
    );
  }

  void _clearFilters(QuestBoardViewModel viewModel) {
    _searchController.clear();
    viewModel.clearFilters();
  }

  Future<void> _pickDateRange(
    BuildContext context,
    QuestBoardViewModel viewModel,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: viewModel.startDate == null
          ? null
          : DateTimeRange(start: viewModel.startDate!, end: viewModel.endDate!),
    );
    if (range != null && mounted) {
      viewModel.setDateRange(range.start, range.end);
    }
  }

  String _statusLabel(TaskStatus? status) => switch (status) {
    TaskStatus.planned => 'Planned',
    TaskStatus.completed => 'Completed',
    TaskStatus.cancelled => 'Cancelled',
    null => 'All',
  };

  String _flexibilityLabel(TaskFlexibility? flexibility) =>
      switch (flexibility) {
        TaskFlexibility.flexible => 'Flexible',
        TaskFlexibility.fixed => 'Fixed',
        TaskFlexibility.needsAgreement => 'Needs agreement',
        null => 'All',
      };

  String _sortLabel(QuestSort sort) => switch (sort) {
    QuestSort.dueSoonest => 'Due soonest',
    QuestSort.dueLatest => 'Due latest',
    QuestSort.title => 'Title A–Z',
    QuestSort.remainingMost => 'Most time remaining',
  };

  Future<void> _openTaskForm(
    BuildContext context,
    QuestBoardViewModel viewModel, {
    TaskItem? task,
  }) async {
    final result = await showModalBottomSheet<TaskItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: TaskFormScreen(task: task),
      ),
    );
    if (result == null || !context.mounted) return;
    final saved = await viewModel.saveTask(result);
    if (!context.mounted) return;
    _showResult(
      context,
      saved,
      saved
          ? (task == null ? 'Task created.' : 'Task updated.')
          : viewModel.errorMessage ?? 'The task could not be saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    QuestBoardViewModel viewModel,
    TaskItem task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete “${task.title}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await viewModel.deleteTask(task.id);
    if (!context.mounted) return;
    _showResult(
      context,
      deleted,
      deleted
          ? 'Task deleted.'
          : viewModel.errorMessage ?? 'The task could not be deleted.',
    );
  }

  void _showResult(BuildContext context, bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? Theme.of(context).colorScheme.inverseSurface
            : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first task to start comparing planned work with available time.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Create task'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Tasks could not be loaded',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
