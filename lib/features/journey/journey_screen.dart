import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
import '../../data/repositories/achievement_repository.dart';
import '../../domain/models/achievement_models.dart';
import 'journey_view_model.dart';
import '../../data/services/verified_progress_service.dart';
import '../../data/repositories/world_history_repository.dart';
import '../../core/utils/app_error_message.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => JourneyViewModel(
      context.read<AchievementRepository>(),
      context.read<WorldHistoryRepository?>(),
    )..load(),
    child: const _JourneyContent(),
  );
}

class _JourneyContent extends StatelessWidget {
  const _JourneyContent();

  @override
  Widget build(BuildContext context) => Consumer<JourneyViewModel>(
    builder: (context, viewModel, _) => BalanceScaffold(
      title: 'Journey',
      headline: 'Weekly reflection',
      subtitle: 'A private look at the week\'s patterns.',
      currentIndex: 4,
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                RpgSquareButton(
                  tooltip: 'Previous week',
                  onPressed: () => viewModel.shiftWeek(-1),
                  icon: Icons.arrow_back,
                ),
                Expanded(
                  child: Center(
                    child: RpgLabel(
                      '${DateFormat('EEE d MMM').format(viewModel.weekStart)} – '
                      '${DateFormat('EEE d MMM').format(viewModel.weekStart.add(const Duration(days: 6)))}',
                      tone: RpgTone.neutral,
                      size: 15,
                    ),
                  ),
                ),
                RpgSquareButton(
                  tooltip: 'Next week',
                  onPressed: () => viewModel.shiftWeek(1),
                  icon: Icons.arrow_forward,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (viewModel.weekError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RpgPanel(
                  tone: RpgTone.danger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(viewModel.weekError!),
                      TextButton(
                        onPressed: viewModel.isLoading ? null : viewModel.load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            if (viewModel.week != null) ...[
              RpgPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PanelHeader('Weekly pattern'),
                    const SizedBox(height: 2),
                    const Text(
                      'World Status score per day',
                      style: TextStyle(
                        fontSize: 12,
                        color: BalanceColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _WeekBars(
                      weekStart: viewModel.weekStart,
                      scores: viewModel.week!.dailyScores,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Only days captured at the time have a score.',
                      style: TextStyle(
                        fontSize: 13,
                        color: BalanceColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _RecoveryKept(week: viewModel.week!),
            ],
            if (viewModel.week == null && viewModel.weekError == null)
              const RpgPanel(
                tone: RpgTone.muted,
                dashed: true,
                child: Text(
                  'Connect your account to see recorded weekly patterns.',
                  style: TextStyle(color: BalanceColors.textMuted),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: context.read<VerifiedProgressService?>() == null
                  ? null
                  : () => _reflect(context, viewModel),
              icon: const Icon(Icons.edit_note),
              label: const Text('Add optional reflection'),
            ),
            const SizedBox(height: 28),
            const Eyebrow('Journey milestones'),
            const SizedBox(height: 8),
            const RpgHeadline('Achievements', size: 26),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${viewModel.unlockedCount} of 7 unlocked',
                    style: const TextStyle(color: BalanceColors.textMuted),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: SegmentMeter(
                    total: 7,
                    filled: viewModel.unlockedCount > 7
                        ? 7
                        : viewModel.unlockedCount,
                    color: BalanceColors.calmFill,
                    height: 6,
                    gap: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const RpgPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PanelHeader('How progress works', divider: true),
                  SizedBox(height: 10),
                  Text(
                    'Only verified actions unlock achievements. Rest never removes progress.',
                    style: TextStyle(height: 1.35),
                  ),
                ],
              ),
            ),
            if (viewModel.isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              RpgPanel(
                tone: RpgTone.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(viewModel.errorMessage!),
                    TextButton(
                      onPressed: viewModel.isLoading ? null : viewModel.load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final definition in viewModel.definitions) ...[
              _AchievementCard(
                definition: definition,
                award: viewModel.awardFor(definition.key),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _reflect(
    BuildContext context,
    JourneyViewModel viewModel,
  ) async {
    final service = context.read<VerifiedProgressService?>();
    if (service == null) return;
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Weekly reflection'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'What worked for you this week?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || content == null) return;
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a reflection first.')),
      );
      return;
    }
    try {
      await service.saveReflection(content);
      await viewModel.load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(viewModel.reflectionSavedMessage)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                error,
                fallback: 'Could not save reflection. Try again.',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.weekStart, required this.scores});
  final DateTime weekStart;
  final List<int?> scores;

  @override
  Widget build(BuildContext context) {
    const maxHeight = 96.0;
    return SizedBox(
      height: maxHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final score = i < scores.length ? scores[i] : null;
                  final day = weekStart.add(Duration(days: i));
                  final over = score != null && score >= 75;
                  return Semantics(
                    label:
                        '${DateFormat.EEEE().format(day)}: ${score == null ? 'No record' : '$score out of 100'}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          score == null ? '–' : '$score',
                          style: const TextStyle(
                            fontSize: 11,
                            color: BalanceColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: score == null
                              ? 4
                              : ((score < 4 ? 4 : (score > 100 ? 100 : score)) /
                                        100) *
                                    maxHeight,
                          color: score == null
                              ? BalanceColors.surfaceRaised
                              : over
                              ? BalanceColors.dangerFill
                              : BalanceColors.accent,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.E().format(day).substring(0, 1),
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: over
                                ? BalanceColors.danger
                                : BalanceColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RecoveryKept extends StatelessWidget {
  const _RecoveryKept({required this.week});
  final WeeklyJourney week;

  @override
  Widget build(BuildContext context) => RpgPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelHeader(
          'Recovery kept',
          tone: RpgTone.calm,
          trailing: week.recoveryRecordedDays == 0
              ? null
              : RpgLabel(
                  '${week.protectedRecoveryDays} / ${week.recoveryRecordedDays}',
                  tone: RpgTone.neutral,
                  size: 15,
                ),
        ),
        const SizedBox(height: 6),
        Text(
          week.recoveryRecordedDays == 0
              ? 'No recorded recovery history for this week.'
              : 'Protected recovery on ${week.protectedRecoveryDays} of ${week.recoveryRecordedDays} recorded days',
          style: const TextStyle(color: BalanceColors.textMuted),
        ),
        if (week.recoveryRecordedDays > 0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < week.recoveryRecordedDays; i++)
                DiamondIcon(
                  size: 14,
                  filled: i < week.protectedRecoveryDays,
                  color: i < week.protectedRecoveryDays
                      ? BalanceColors.calm
                      : BalanceColors.textFaint,
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.definition, required this.award});

  final AchievementDefinition definition;
  final AchievementAward? award;

  @override
  Widget build(BuildContext context) {
    final unlocked = award != null;
    return RpgPanel(
      tone: RpgTone.muted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Icon(
              unlocked ? Icons.verified_outlined : Icons.shield_outlined,
              size: 22,
              color: unlocked ? BalanceColors.calm : BalanceColors.textFaint,
              semanticLabel: unlocked ? 'Unlocked' : 'Locked',
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.practicalName,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 0.8,
                    color: unlocked
                        ? BalanceColors.text
                        : BalanceColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  definition.condition,
                  style: const TextStyle(
                    fontSize: 13,
                    color: BalanceColors.textMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentMeter(
                  total: 1,
                  filled: unlocked ? 1 : 0,
                  color: BalanceColors.calmFill,
                  height: 5,
                ),
                const SizedBox(height: 8),
                Text(
                  definition.rpgName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: BalanceColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RpgTag(
            unlocked
                ? 'Unlocked ${DateFormat.MMMd().format(award!.awardedAt.toLocal())}'
                : 'Locked',
            tone: unlocked ? RpgTone.calm : RpgTone.muted,
          ),
        ],
      ),
    );
  }
}
