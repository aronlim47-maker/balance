import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../core/state/planning_day_controller.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/models/availability_block.dart';
import 'availability_form_sheet.dart';
import 'capacity_gap_card.dart';
import 'today_view_model.dart';
import 'world_status_card.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => TodayViewModel(
      context.read<TaskRepository>(),
      context.read<AvailabilityRepository>(),
      context.read<PlanRepository?>(),
      context.read<RecoveryRepository?>(),
      context.read<PlanningDayController>(),
    )..load(),
    child: const _TodayContent(),
  );
}

class _TodayContent extends StatelessWidget {
  const _TodayContent();

  @override
  Widget build(BuildContext context) => Consumer<TodayViewModel>(
    builder: (context, viewModel, _) => BalanceScaffold(
      title: 'Today',
      currentIndex: 0,
      actions: [
        IconButton(
          tooltip: 'Add time block',
          onPressed: () => _openAvailabilityForm(context, viewModel),
          icon: const Icon(Icons.add),
        ),
      ],
      body: _buildBody(context, viewModel),
    ),
  );

  Widget _buildBody(BuildContext context, TodayViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.errorMessage != null &&
        viewModel.tasksForDay.isEmpty &&
        viewModel.availabilityForDay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              Text(viewModel.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: viewModel.load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _DaySelector(viewModel: viewModel),
          const SizedBox(height: 16),
          WorldStatusCard(
            plannedMinutes: viewModel.plannedMinutes,
            availableMinutes: viewModel.availableMinutes,
          ),
          const SizedBox(height: 12),
          CapacityGapCard(overloadMinutes: viewModel.overloadMinutes),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Availability',
            actionLabel: 'Add',
            onAction: () => _openAvailabilityForm(context, viewModel),
          ),
          const SizedBox(height: 10),
          if (viewModel.availabilityForDay.isEmpty)
            const _EmptyCard(
              message: 'No availability has been added for this day.',
            )
          else
            ...viewModel.availabilityForDay.map(
              (block) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AvailabilityCard(
                  block: block,
                  onEdit: () =>
                      _openAvailabilityForm(context, viewModel, block: block),
                  onDelete: () =>
                      _deleteAvailability(context, viewModel, block),
                ),
              ),
            ),
          const SizedBox(height: 14),
          const _SectionTitle(title: 'Planned tasks'),
          const SizedBox(height: 10),
          if (viewModel.tasksForDay.isEmpty)
            const _EmptyCard(message: 'No planned tasks are due on this day.')
          else
            ...viewModel.tasksForDay.map(
              (task) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text('${task.effectiveRemainingMinutes} minutes'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAvailabilityForm(
    BuildContext context,
    TodayViewModel viewModel, {
    AvailabilityBlock? block,
  }) async {
    final result = await showModalBottomSheet<AvailabilityBlock>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          AvailabilityFormSheet(day: viewModel.selectedDay, block: block),
    );
    if (result == null || !context.mounted) return;
    final saved = await viewModel.saveAvailability(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? (block == null ? 'Time block added.' : 'Time block updated.')
              : viewModel.errorMessage ?? 'The time block could not be saved.',
        ),
      ),
    );
  }

  Future<void> _deleteAvailability(
    BuildContext context,
    TodayViewModel viewModel,
    AvailabilityBlock block,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete time block?'),
        content: const Text('This action cannot be undone.'),
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
    final deleted = await viewModel.deleteAvailability(block.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Time block deleted.'
              : viewModel.errorMessage ??
                    'The time block could not be deleted.',
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.viewModel});

  final TodayViewModel viewModel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous day',
        onPressed: () => viewModel.selectDay(
          viewModel.selectedDay.subtract(const Duration(days: 1)),
        ),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Column(
          children: [
            Text(
              DateFormat.EEEE().format(viewModel.selectedDay),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(DateFormat.yMMMMd().format(viewModel.selectedDay)),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Next day',
        onPressed: () => viewModel.selectDay(
          viewModel.selectedDay.add(const Duration(days: 1)),
        ),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.block,
    required this.onEdit,
    required this.onDelete,
  });

  final AvailabilityBlock block;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(block.isAvailable ? Icons.event_available : Icons.block),
      title: Text(block.label ?? (block.isAvailable ? 'Available' : 'Blocked')),
      subtitle: Text(
        '${DateFormat.jm().format(block.startAt.toLocal())} – '
        '${DateFormat.jm().format(block.endAt.toLocal())}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({this.title = '', this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Text(message)),
  );
}
