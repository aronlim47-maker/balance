import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/shared_widgets/section_header.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
import '../../core/router/app_router.dart';
import '../../domain/enums/validation_status.dart';
import 'no_plan_explanation_card.dart';
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
      headline: 'Compare plans',
      subtitle: 'Feasible options for today. Nothing changes until you confirm.',
      currentIndex: 2,
      actions: [
        // Only entry to confirmed plans, so a plan can still be undone after
        // the user leaves the plan-updated screen.
        IconButton(
          tooltip: 'Plan history',
          icon: const Icon(Icons.history),
          onPressed: () => context.push(AppRoutes.planHistory),
        ),
      ],
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
              child: RpgTag(
                switch (viewModel.validationStatus) {
                  ValidationStatus.feasible => 'Feasible',
                  ValidationStatus.needsReview => 'Needs Review',
                  ValidationStatus.needsAgreement => 'Needs Agreement',
                  ValidationStatus.noFeasiblePlan => 'No Feasible Plan',
                },
                tone: switch (viewModel.validationStatus) {
                  ValidationStatus.feasible => RpgTone.calm,
                  ValidationStatus.needsReview => RpgTone.warning,
                  ValidationStatus.needsAgreement => RpgTone.warning,
                  ValidationStatus.noFeasiblePlan => RpgTone.danger,
                },
                filled: true,
              ),
            ),
            if (viewModel.isLoading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              if (!viewModel.isConfigured || !viewModel.migrationReady) ...[
                const SizedBox(height: 18),
                RpgPanel(
                  tone: RpgTone.warning,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
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
                RpgPanel(
                  tone: RpgTone.danger,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
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
                RpgPanel(
                  tone: RpgTone.warning,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
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
                const RpgPanel(
                  tone: RpgTone.warning,
                  child: Padding(
                    padding: EdgeInsets.all(2),
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
                    '${option.allMoves.length} task moves to new times before their deadlines.',
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
                    : const Icon(Icons.play_arrow_rounded),
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
      return const RpgPanel(
        tone: RpgTone.calm,
        child: Text('No capacity gap today.'),
      );
    }

    return NoPlanExplanationCard(
      explanation: viewModel.noPlanExplanation,
      onOpenTasks: () => context.go(AppRoutes.quests),
      onOpenToday: () => context.go(AppRoutes.today),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.viewModel});

  final WarCouncilViewModel viewModel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      RpgSquareButton(
        tooltip: 'Previous day',
        onPressed: () => viewModel.selectDay(
          DateTime(
            viewModel.selectedDay.year,
            viewModel.selectedDay.month,
            viewModel.selectedDay.day - 1,
          ),
        ),
        icon: Icons.arrow_back,
      ),
      Expanded(
        child: Center(
          child: RpgLabel(
            DateFormat('EEE d MMM').format(viewModel.selectedDay),
            tone: RpgTone.neutral,
            size: 15,
          ),
        ),
      ),
      RpgSquareButton(
        tooltip: 'Next day',
        onPressed: () => viewModel.selectDay(
          DateTime(
            viewModel.selectedDay.year,
            viewModel.selectedDay.month,
            viewModel.selectedDay.day + 1,
          ),
        ),
        icon: Icons.arrow_forward,
      ),
    ],
  );
}

class _CapacitySummary extends StatelessWidget {
  const _CapacitySummary({required this.viewModel});

  final WarCouncilViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final capacity = viewModel.capacity;
    final over = capacity.overloadMinutes > 0;
    // Split the gap so the numbers add up for the student: work beyond all
    // free time, plus work due before enough free time has started.
    final extraWork = math.max(
      0,
      capacity.plannedMinutes - capacity.availableMinutes,
    );
    final dueBeforeFreeTime = math.max(
      0,
      capacity.overloadMinutes - extraWork,
    );
    return RpgPanel(
      tone: over ? RpgTone.danger : RpgTone.neutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(
            'Time capacity',
            trailing: over
                ? RpgTag(
              '${formatShortDuration(capacity.overloadMinutes)} over',
              tone: RpgTone.danger,
            )
                : capacity.availableMinutes == 0
                ? const RpgTag('No time added', tone: RpgTone.muted)
                : const RpgTag('Fits', tone: RpgTone.calm),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Planned',
                  value: '${capacity.plannedMinutes} min',
                  color: over ? BalanceColors.danger : BalanceColors.text,
                ),
              ),
              const Icon(Icons.arrow_forward, color: BalanceColors.textFaint),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  label: 'Available',
                  value: '${capacity.availableMinutes} min',
                  color: BalanceColors.accentBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              DiamondIcon(
                size: 14,
                filled: over,
                color: over ? BalanceColors.danger : BalanceColors.calm,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${capacity.plannedMinutes <= capacity.availableMinutes && capacity.overloadMinutes > 0 ? 'Deadline gap' : 'Capacity gap'}: ${capacity.overloadMinutes} minutes',
                    ),
                    if (over && dueBeforeFreeTime > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (extraWork > 0)
                            '$extraWork min more work than free time',
                          '$dueBeforeFreeTime min due before free time starts',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: BalanceColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProtectedItems extends StatelessWidget {
  const _ProtectedItems({required this.viewModel});

  final WarCouncilViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tasks = viewModel.protectedTasks;
    final recovery = viewModel.protectedRecoverySlots;
    return RpgPanel(
      tone: RpgTone.calm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RpgLabel('What stays protected', tone: RpgTone.calm, size: 13),
          const SizedBox(height: 4),
          Text(
            'Protected items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty && recovery.isEmpty)
            const Text(
              'No fixed tasks or protected recovery on this day.',
              style: TextStyle(color: BalanceColors.textMuted),
            ),
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.shield_outlined,
                color: BalanceColors.calm,
              ),
              title: Text(task.title),
              subtitle: Text(
                task.isProtected ? 'Protected task' : 'Fixed task',
              ),
            ),
          for (final slot in recovery)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.eco_outlined, color: BalanceColors.calm),
              title: const Text('Protected recovery'),
              subtitle: Text(
                '${DateFormat.jm().format(slot.startAt.toLocal())}–${DateFormat.jm().format(slot.endAt.toLocal())}',
              ),
            ),
        ],
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
      RpgLabel(label, size: 12),
      const SizedBox(height: 4),
      Text(
        value.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          fontWeight: FontWeight.w700,
          fontSize: 24,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    ],
  );
}