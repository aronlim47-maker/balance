import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
import '../../core/state/planning_day_controller.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/check_in_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../domain/models/availability_block.dart';
import '../../domain/models/check_in.dart';
import '../../domain/models/movement_models.dart';
import '../../domain/models/social_event_record.dart';
import '../../domain/models/task_item.dart';
import 'availability_form_sheet.dart';
import 'capacity_gap_card.dart';
import 'daily_review_card.dart';
import 'movement_card.dart';
import 'social_card.dart';
import 'today_view_model.dart';
import 'today_task_details_sheet.dart';
import 'world_status_card.dart';
import '../../data/repositories/world_history_repository.dart';
import '../../data/services/verified_progress_service.dart';
import '../../core/utils/app_error_message.dart';

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
      context.read<CheckInRepository>(),
      context.read<MovementRepository>(),
      context.read<SocialRepository>(),
      context.read<WorldHistoryRepository?>(),
    )..load(),
    child: const _TodayContent(),
  );
}

class _TodayContent extends StatelessWidget {
  const _TodayContent();

  @override
  Widget build(BuildContext context) => Consumer<TodayViewModel>(
    builder: (context, viewModel, _) => BalanceScaffold(
      title: 'World Status',
      headline: 'Today',
      subtitle: DateFormat('EEEE, d MMMM').format(viewModel.selectedDay),
      headerTrailing: _StatusBadge(label: viewModel.worldStatus.label),
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
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.loadErrorMessage != null &&
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
              Text(viewModel.loadErrorMessage!, textAlign: TextAlign.center),
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
          if (viewModel.isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (viewModel.loadErrorMessage != null && viewModel.hasLoaded) ...[
            const SizedBox(height: 8),
            _InlineLoadError(
              message: viewModel.loadErrorMessage!,
              onRetry: viewModel.load,
            ),
          ],
          if (viewModel.historyNotice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                viewModel.historyNotice!,
                style: const TextStyle(color: BalanceColors.textMuted),
              ),
            ),
          const SizedBox(height: 16),
          WorldStatusCard(
            plannedMinutes: viewModel.plannedMinutes,
            availableMinutes: viewModel.availableMinutes,
            status: viewModel.worldStatus,
            selectedDay: viewModel.selectedDay,
            previousTotals: viewModel.previousTotals,
          ),
          if (viewModel.overloadMinutes > 0 &&
              viewModel.earlyReviewCandidate != null &&
              context.read<VerifiedProgressService?>() != null)
            TextButton.icon(
              onPressed: () => _acknowledgeOverload(context, viewModel),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('I reviewed this overload'),
            ),
          const SizedBox(height: 12),
          DailyReviewCard(
            review: viewModel.checkIn,
            isSaving: viewModel.isSavingReview,
            onEdit: () => _openDailyReview(context, viewModel),
          ),
          const SizedBox(height: 12),
          MovementCard(
            selectedDay: viewModel.selectedDay,
            settings: viewModel.movementSettings,
            latestExercise: viewModel.latestExercise,
            dayLogs: viewModel.exerciseLogsForDay,
            isSaving: viewModel.isSavingMovement,
            onTrackingChanged: (enabled) => _saveMovementSettings(
              context,
              viewModel,
              MovementSettings(
                trackingEnabled: enabled,
                targetDays: viewModel.movementSettings.targetDays,
                targetRecoveryMinutes:
                    viewModel.movementSettings.targetRecoveryMinutes,
                targetSocialMinutesWeek:
                    viewModel.movementSettings.targetSocialMinutesWeek,
              ),
            ),
            onTargetDaysChanged: (days) => _saveMovementSettings(
              context,
              viewModel,
              MovementSettings(
                trackingEnabled: viewModel.movementSettings.trackingEnabled,
                targetDays: days,
                targetRecoveryMinutes:
                    viewModel.movementSettings.targetRecoveryMinutes,
                targetSocialMinutesWeek:
                    viewModel.movementSettings.targetSocialMinutesWeek,
              ),
            ),
            onAdd: () => _openExercise(context, viewModel),
            onDelete: (log) => _deleteExercise(context, viewModel, log),
          ),
          const SizedBox(height: 12),
          SocialCard(
            events: viewModel.socialEvents,
            noCommitments: viewModel.noSocialCommitments,
            isSaving: viewModel.isSavingSocial,
            onAdd: () => _openSocialEvent(context, viewModel),
            onDelete: (event) => _deleteSocialEvent(context, viewModel, event),
            onNoCommitmentsChanged: (value) =>
                _setNoSocialCommitments(context, viewModel, value),
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
              (task) => RpgPanel(
                tone: RpgTone.muted,
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                onTap: () => _showTaskDetails(context, task),
                child: ListTile(
                  leading: DiamondIcon(
                    size: 16,
                    color: task.isProtected
                        ? BalanceColors.calm
                        : BalanceColors.textFaint,
                  ),
                  title: Text(
                    task.title,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                  subtitle: Text(
                    '${task.effectiveRemainingMinutes} min · ${task.scheduledStart == null ? 'Due this day' : 'Scheduled this day'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTaskDetails(BuildContext context, TaskItem task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => TodayTaskDetailsSheet(task: task),
    );
  }

  Future<void> _setNoSocialCommitments(
    BuildContext context,
    TodayViewModel viewModel,
    bool value,
  ) async {
    final saved = await viewModel.setNoSocialCommitments(value);
    if (!context.mounted || (saved && viewModel.refreshWarning == null)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? viewModel.refreshWarning!
              : viewModel.errorMessage ?? 'Could not save your response.',
        ),
      ),
    );
  }

  Future<void> _acknowledgeOverload(
    BuildContext context,
    TodayViewModel viewModel,
  ) async {
    final service = context.read<VerifiedProgressService?>();
    final candidate = viewModel.earlyReviewCandidate;
    if (service == null || candidate == null) return;
    try {
      await service.acknowledgeOverload(candidate.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review recorded. Check Journey for progress.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                error,
                fallback: 'Could not record this review. Try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openSocialEvent(
    BuildContext context,
    TodayViewModel viewModel,
  ) async {
    final event = await showModalBottomSheet<SocialEventRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => SocialEventSheet(
        day: viewModel.selectedDay,
        tasks: viewModel.socialTasks,
      ),
    );
    if (event == null || !context.mounted) return;
    final saved = await viewModel.addSocialEvent(event);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? viewModel.refreshWarning ?? 'Social event saved.'
              : viewModel.errorMessage ?? 'Could not save the event.',
        ),
      ),
    );
  }

  Future<void> _deleteSocialEvent(
    BuildContext context,
    TodayViewModel viewModel,
    SocialEventRecord event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove social event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await viewModel.deleteSocialEvent(event.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? viewModel.refreshWarning ?? 'Social event removed.'
              : viewModel.errorMessage ?? 'Could not remove the event.',
        ),
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

  Future<void> _openDailyReview(
    BuildContext context,
    TodayViewModel viewModel,
  ) async {
    final review = await showModalBottomSheet<CheckIn>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DailyReviewSheet(
        date: viewModel.selectedDay,
        existing: viewModel.checkIn,
      ),
    );
    if (review == null || !context.mounted) return;
    final saved = await viewModel.saveDailyReview(review);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Daily Review saved.'
              : viewModel.errorMessage ??
                    'Could not save Daily Review. Please try again.',
        ),
      ),
    );
  }

  Future<void> _saveMovementSettings(
    BuildContext context,
    TodayViewModel viewModel,
    MovementSettings settings,
  ) async {
    final saved = await viewModel.saveMovementSettings(settings);
    if (!context.mounted || (saved && viewModel.refreshWarning == null)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? viewModel.refreshWarning!
              : viewModel.errorMessage ??
                    'Could not save movement settings. Please try again.',
        ),
      ),
    );
  }

  Future<void> _openExercise(
    BuildContext context,
    TodayViewModel viewModel,
  ) async {
    final log = await showModalBottomSheet<ExerciseLog>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExerciseLogSheet(
        day: viewModel.selectedDay,
        tasks: viewModel.exerciseTasks,
      ),
    );
    if (log == null || !context.mounted) return;
    final saved = await viewModel.recordExercise(log);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? viewModel.refreshWarning ?? 'Exercise recorded.'
              : viewModel.errorMessage ??
                    'Could not save exercise. Please try again.',
        ),
      ),
    );
  }

  Future<void> _deleteExercise(
    BuildContext context,
    TodayViewModel viewModel,
    ExerciseLog log,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove exercise record?'),
        content: const Text(
          'Physical will be recalculated from remaining records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await viewModel.deleteExercise(log.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? viewModel.refreshWarning ?? 'Exercise record removed.'
              : viewModel.errorMessage ??
                    'Could not remove exercise. Please try again.',
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

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.viewModel});

  final TodayViewModel viewModel;

  String _relative(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(today).inDays;
    return switch (diff) {
      0 => 'Viewing today',
      1 => 'Viewing tomorrow',
      -1 => 'Viewing yesterday',
      _ => 'Viewing ${DateFormat.MMMd().format(day)}',
    };
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      RpgSquareButton(
        tooltip: 'Previous day',
        onPressed: () => viewModel.selectDay(
          viewModel.selectedDay.subtract(const Duration(days: 1)),
        ),
        icon: Icons.arrow_back,
      ),
      Expanded(
        child: Center(
          child: RpgLabel(
            _relative(viewModel.selectedDay),
            tone: RpgTone.accent,
            size: 13,
          ),
        ),
      ),
      RpgSquareButton(
        tooltip: 'Next day',
        onPressed: () => viewModel.selectDay(
          viewModel.selectedDay.add(const Duration(days: 1)),
        ),
        icon: Icons.arrow_forward,
      ),
    ],
  );
}

/// Small status tag next to the TODAY headline, e.g. "BUILDING".
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = switch (label) {
      'Low' => RpgTone.calm,
      'Building' => RpgTone.warning,
      'High' => RpgTone.warning,
      'Over capacity' => RpgTone.danger,
      _ => RpgTone.muted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tone == RpgTone.muted ? Colors.transparent : tone.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tone.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DiamondIcon(size: 10, filled: true, color: tone.foreground),
              const SizedBox(width: 6),
              RpgLabel(
                label == 'Not enough data' ? 'No data yet' : label,
                tone: tone == RpgTone.muted ? RpgTone.muted : tone,
                size: 12,
                spacing: 1.6,
              ),
            ],
          ),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) => RpgPanel(
    tone: block.isAvailable ? RpgTone.muted : RpgTone.danger,
    padding: EdgeInsets.zero,
    child: ListTile(
      leading: Icon(
        block.isAvailable ? Icons.event_available : Icons.block,
        color: block.isAvailable
            ? BalanceColors.accentBright
            : BalanceColors.danger,
      ),
      title: Text(
        block.label ?? (block.isAvailable ? 'Available' : 'Blocked'),
        style: const TextStyle(
          fontFamily: AppTheme.displayFont,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.8,
        ),
      ),
      subtitle: Text(
        '${DateFormat.jm().format(block.startAt.toLocal())} – '
        '${DateFormat.jm().format(block.endAt.toLocal())}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Time block actions',
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
  Widget build(BuildContext context) => SectionRule(
    title,
    trailing: actionLabel == null
        ? null
        : TextButton(onPressed: onAction, child: Text(actionLabel!)),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => RpgPanel(
    tone: RpgTone.muted,
    dashed: true,
    padding: const EdgeInsets.all(18),
    child: Text(
      message,
      style: const TextStyle(color: BalanceColors.textMuted),
    ),
  );
}
