import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../core/shared_widgets/section_header.dart';
import '../../core/router/app_router.dart';
import '../../domain/enums/validation_status.dart';
import 'trade_off_option_card.dart';
import 'war_council_view_model.dart';

class WarCouncilScreen extends StatefulWidget {
  const WarCouncilScreen({super.key});

  @override
  State<WarCouncilScreen> createState() => _WarCouncilScreenState();
}

class _WarCouncilScreenState extends State<WarCouncilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WarCouncilViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WarCouncilViewModel>();
    return BalanceScaffold(
      title: 'War Council',
      currentIndex: 2,
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _DaySelector(viewModel: viewModel),
            const SizedBox(height: 18),
            SectionHeader(
              title: viewModel.capacity.overloadMinutes > 0
                  ? 'Over capacity'
                  : 'On track',
            ),
            const SizedBox(height: 18),
            _CapacitySummary(viewModel: viewModel),
            const SizedBox(height: 12),
            _ProtectedItems(viewModel: viewModel),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(switch (viewModel.validationStatus) {
                  ValidationStatus.feasible => 'Feasible',
                  ValidationStatus.needsReview => 'Needs Review',
                  ValidationStatus.needsAgreement => 'Needs Agreement',
                  ValidationStatus.noFeasiblePlan => 'No Feasible Plan',
                }),
              ),
            ),
            if (viewModel.isLoading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              if (!viewModel.isConfigured || !viewModel.migrationReady) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      viewModel.isConfigured
                          ? 'Database update needed to confirm plans.'
                          : 'Connect Supabase to confirm plans.',
                    ),
                  ),
                ),
              ],
              if (viewModel.errorMessage != null) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(viewModel.errorMessage!),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: viewModel.load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (viewModel.migrationReady &&
                  viewModel.validationStatus == ValidationStatus.needsReview &&
                  viewModel.errorMessage == null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      viewModel.isCheckingCapacity
                          ? 'Checking capacity with Supabase…'
                          : viewModel.capacityCheckError ?? 'The app and database calculate different capacity for this day. Check your profile time zone in Supabase, then refresh before confirming.',
                    ),
                  ),
                ),
              ],
              if (viewModel.validationStatus ==
                  ValidationStatus.needsAgreement) ...[
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Get agreement and update the task before confirming.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              const SectionHeader(
                title: 'Choose a plan',
                subtitle: 'Suggestions only. Nothing moves until confirmed.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.today),
                icon: const Icon(Icons.today_outlined),
                label: const Text('Back to Today'),
              ),
              const SizedBox(height: 12),
              if (viewModel.options.isEmpty)
                _NoPlanGuidance(viewModel: viewModel)
              else
                for (final option in viewModel.options) ...[
                  TradeOffOptionCard(
                    title: option.title,
                    description: option.description,
                    movedMinutes: option.movedMinutes,
                    recoveryMinutes: 0,
                    protectedSummary:
                        'Existing protected tasks and recovery stay unchanged.',
                    costSummary:
                        '${option.movedMinutes} min added on ${DateFormat.MMMd().format(option.proposedStart.toLocal())}.',
                    roomSummary:
                        '${option.movedMinutes} min moved from this day. Recovery time is not reserved by this suggestion.',
                    reviewSummary: option.needsAgreement
                        ? 'Get agreement before this change can be confirmed.'
                        : 'Check the proposed time and deadline before confirming.',
                    needsAgreement: option.needsAgreement,
                    isSelected: viewModel.selectedOptionId == option.id,
                    onTap: () => viewModel.selectOption(option.id),
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: viewModel.canConfirm
                    ? () => _confirm(context, viewModel)
                    : null,
                icon: viewModel.isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  viewModel.isSaving ? 'Saving plan…' : 'Confirm selected plan',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WarCouncilViewModel viewModel,
  ) async {
    final changeId = await viewModel.confirmSelectedPlan();
    if (!context.mounted) return;
    if (changeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.errorMessage ?? 'The plan could not be confirmed.',
          ),
        ),
      );
      return;
    }
    context.push('/council/updated/$changeId');
  }
}

class _NoPlanGuidance extends StatelessWidget {
  const _NoPlanGuidance({required this.viewModel});

  final WarCouncilViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.capacity.overloadMinutes == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('No capacity gap today.'),
        ),
      );
    }

    final reason = viewModel.allDayTasksProtected
        ? 'All tasks are fixed or protected.'
        : viewModel.hasUnscheduledFlexibleWork
        ? 'Schedule flexible work before its deadline to compare moves.'
        : 'No safe move fits before the deadlines.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No feasible plan yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(reason),
            const SizedBox(height: 12),
            const Text(
              'Check real availability, review flexible tasks, or ask for a deadline change.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.quests),
                  child: const Text('Review tasks'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.viewModel});

  final WarCouncilViewModel viewModel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous day',
        onPressed: () => viewModel.selectDay(
          DateTime(
            viewModel.selectedDay.year,
            viewModel.selectedDay.month,
            viewModel.selectedDay.day - 1,
          ),
        ),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          DateFormat.yMMMMEEEEd().format(viewModel.selectedDay),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        tooltip: 'Next day',
        onPressed: () => viewModel.selectDay(
          DateTime(
            viewModel.selectedDay.year,
            viewModel.selectedDay.month,
            viewModel.selectedDay.day + 1,
          ),
        ),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _CapacitySummary extends StatelessWidget {
  const _CapacitySummary({required this.viewModel});

  final WarCouncilViewModel viewModel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Planned',
                  value: '${viewModel.capacity.plannedMinutes} min',
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const Icon(Icons.arrow_forward),
              Expanded(
                child: _Metric(
                  label: 'Available',
                  value: '${viewModel.capacity.availableMinutes} min',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              Icon(
                viewModel.capacity.overloadMinutes > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${viewModel.capacity.plannedMinutes <= viewModel.capacity.availableMinutes && viewModel.capacity.overloadMinutes > 0 ? 'Deadline gap' : 'Capacity gap'}: ${viewModel.capacity.overloadMinutes} minutes',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ProtectedItems extends StatelessWidget {
  const _ProtectedItems({required this.viewModel});

  final WarCouncilViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tasks = viewModel.protectedTasks;
    final recovery = viewModel.protectedRecoverySlots;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protected items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (tasks.isEmpty && recovery.isEmpty)
              const Text('No fixed tasks or protected recovery on this day.'),
            for (final task in tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text(task.title),
                subtitle: Text(
                  task.isProtected ? 'Protected task' : 'Fixed task',
                ),
              ),
            for (final slot in recovery)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.spa_outlined),
                title: const Text('Protected recovery'),
                subtitle: Text(
                  '${DateFormat.jm().format(slot.startAt.toLocal())}–${DateFormat.jm().format(slot.endAt.toLocal())}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    ],
  );
}
