import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/shared_widgets/section_header.dart';
import '../../core/theme/balance_colors.dart';
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
    final taskTitles =
        (change?.consequences['task_titles'] as List?)
            ?.whereType<String>()
            .toList() ??
        viewModel.confirmedOption?.allMoves
            .map((move) => move.taskTitle)
            .toList() ??
        const <String>[];
    final taskCount =
        (change?.consequences['task_count'] as num?)?.toInt() ??
        taskTitles.length;
    return Scaffold(
      appBar: AppBar(
        title: const Eyebrow('War Council'),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (viewModel.isLoadingChange && !hasKnownChange)
              const Center(child: CircularProgressIndicator())
            else
              Align(
                alignment: Alignment.centerLeft,
                child: _DiamondBadge(
                  icon: isUndone
                      ? Icons.undo_rounded
                      : isConfirmed
                      ? Icons.check
                      : Icons.info_outline,
                  tone: isConfirmed
                      ? RpgTone.calm
                      : isUndone
                      ? RpgTone.accent
                      : RpgTone.muted,
                ),
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
                  ? '$taskCount task placement${taskCount == 1 ? '' : 's'} restored in Supabase.'
                  : isConfirmed
                  ? '$taskCount task${taskCount == 1 ? '' : 's'} updated in Supabase.'
                  : 'No task moves were applied.',
            ),
            const SizedBox(height: 22),
            if (hasKnownChange)
              RpgPanel(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RpgLabel(isUndone ? 'What was restored' : 'What moved'),
                      ListTile(
                        leading: DiamondIcon(
                          size: 12,
                          filled: true,
                          color: isConfirmed
                              ? BalanceColors.accentBright
                              : BalanceColors.textFaint,
                        ),
                        title: Text(taskTitle),
                        subtitle: Text(
                          isUndone
                              ? 'Move reversed'
                              : !isConfirmed
                              ? 'No move applied'
                              : movedMinutes == null
                              ? 'Task placement changed'
                              : '$movedMinutes minutes moved across $taskCount task${taskCount == 1 ? '' : 's'}',
                        ),
                      ),
                      for (final title in taskTitles)
                        if (taskTitles.length > 1)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.task_alt),
                            title: Text(title),
                          ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                        ),
                        title: const Text(
                          'Change reference',
                          style: TextStyle(
                            fontSize: 14,
                            color: BalanceColors.textMuted,
                          ),
                        ),
                        subtitle: Text(
                          widget.changeId,
                          style: const TextStyle(
                            fontSize: 12,
                            color: BalanceColors.textFaint,
                          ),
                        ),
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
            FilledButton.icon(
              onPressed: () => context.go('/today'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Return to Today'),
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

/// Outlined diamond with an icon inside, shown at the top of the page.
class _DiamondBadge extends StatelessWidget {
  const _DiamondBadge({required this.icon, required this.tone});
  final IconData icon;
  final RpgTone tone;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 64,
    child: Stack(
      alignment: Alignment.center,
      children: [
        DiamondIcon(size: 60, color: tone.border, strokeWidth: 1.6),
        Icon(icon, size: 24, color: tone.foreground),
      ],
    ),
  );
}
