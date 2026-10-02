import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/section_header.dart';
import '../../domain/enums/plan_status.dart';
import 'war_council_view_model.dart';

class PlanUpdatedScreen extends StatefulWidget {
  const PlanUpdatedScreen({super.key, required this.changeId});
  final String changeId;

  @override
  State<PlanUpdatedScreen> createState() => _PlanUpdatedScreenState();
}

class _PlanUpdatedScreenState extends State<PlanUpdatedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WarCouncilViewModel>().loadChange(widget.changeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WarCouncilViewModel>();
    final change = viewModel.currentChange?.id == widget.changeId
        ? viewModel.currentChange
        : null;
    final hasKnownChange = change != null;
    final isConfirmed =
        change?.status == PlanStatus.confirmed && !viewModel.wasUndone;
    final isUndone =
        hasKnownChange &&
        (change.status == PlanStatus.undone || viewModel.wasUndone);
    final taskTitle =
        change?.consequences['task_title'] as String? ??
        viewModel.confirmedOption?.taskTitle ??
        'Selected task';
    final movedMinutes =
        (change?.consequences['moved_minutes'] as num?)?.toInt() ??
        viewModel.confirmedOption?.movedMinutes;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan updated')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (viewModel.isLoadingChange && !hasKnownChange)
              const Center(child: CircularProgressIndicator())
            else
              Icon(
                isUndone
                    ? Icons.undo_rounded
                    : isConfirmed
                    ? Icons.check_circle
                    : Icons.info_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            const SizedBox(height: 18),
            SectionHeader(
              title: !hasKnownChange
                  ? viewModel.isLoadingChange
                        ? 'Loading plan…'
                        : 'Plan unavailable'
                  : isUndone
                  ? 'Changes were undone'
                  : isConfirmed
                  ? 'Plan confirmed'
                  : 'Plan not confirmed',
              subtitle: !hasKnownChange
                  ? viewModel.changeNotFound
                        ? 'This plan record could not be found. Return to War Council and refresh.'
                        : 'Check the plan status before making another change.'
                  : isUndone
                  ? 'The task placement was restored in Supabase.'
                  : isConfirmed
                  ? 'The task move was saved in Supabase.'
                  : 'No task move was applied.',
            ),
            const SizedBox(height: 22),
            if (hasKnownChange)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event_repeat),
                        title: Text(taskTitle),
                        subtitle: Text(
                          isUndone
                              ? 'Move reversed'
                              : !isConfirmed
                              ? 'No move applied'
                              : movedMinutes == null
                              ? 'Task placement changed'
                              : '$movedMinutes minutes moved',
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: const Text('Change reference'),
                        subtitle: Text(widget.changeId),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 22),
            if (viewModel.errorMessage != null) ...[
              Text(
                viewModel.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (!hasKnownChange && !viewModel.isLoadingChange)
              OutlinedButton(
                onPressed: () => viewModel.loadChange(widget.changeId),
                child: const Text('Try again'),
              ),
            if (viewModel.canUndoCurrentChange)
              OutlinedButton.icon(
                onPressed: () => _undo(context, viewModel),
                icon: const Icon(Icons.undo),
                label: Text(
                  viewModel.isSaving ? 'Restoring…' : 'Undo this plan',
                ),
              ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => context.go('/today'),
              child: const Text('Return to Today'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _undo(
    BuildContext context,
    WarCouncilViewModel viewModel,
  ) async {
    final undone = await viewModel.undoPlan(widget.changeId);
    if (!context.mounted || (undone && viewModel.refreshWarning == null)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          undone
              ? viewModel.refreshWarning!
              : viewModel.errorMessage ?? 'Undo failed.',
        ),
      ),
    );
  }
}
