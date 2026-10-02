import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
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
      currentIndex: 4,
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Weekly pattern',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: () => viewModel.shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${DateFormat.MMMd().format(viewModel.weekStart)} – '
                    '${DateFormat.MMMd().format(viewModel.weekStart.add(const Duration(days: 6)))}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: () => viewModel.shiftWeek(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (viewModel.weekError != null) Text(viewModel.weekError!),
            if (viewModel.week != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.week!.recoveryRecordedDays == 0
                            ? 'No recorded recovery history for this week.'
                            : 'Protected recovery on ${viewModel.week!.protectedRecoveryDays} of ${viewModel.week!.recoveryRecordedDays} recorded days',
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < 7; i++)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat.E().format(
                                  viewModel.weekStart.add(Duration(days: i)),
                                ),
                              ),
                            ),
                            Text(
                              viewModel.week!.dailyScores[i] == null
                                  ? 'No record'
                                  : '${viewModel.week!.dailyScores[i]}/100',
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'Only days captured at the time have a score.',
                      ),
                    ],
                  ),
                ),
              ),
            if (viewModel.week == null && viewModel.weekError == null)
              const Text(
                'Connect your account to see recorded weekly patterns.',
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: context.read<VerifiedProgressService?>() == null
                  ? null
                  : () => _reflect(context, viewModel),
              icon: const Icon(Icons.edit_note),
              label: const Text('Add optional reflection'),
            ),
            Text(
              'Achievements',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text('${viewModel.unlockedCount} of 7 unlocked'),
            if (viewModel.isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(viewModel.errorMessage!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final definition in viewModel.definitions) ...[
              _AchievementCard(
                definition: definition,
                award: viewModel.awardFor(definition.key),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Text(
              'Only verified actions unlock achievements. Rest never removes progress.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.definition, required this.award});

  final AchievementDefinition definition;
  final AchievementAward? award;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(
        award == null ? Icons.lock_outline : Icons.verified_outlined,
      ),
      title: Text(definition.practicalName),
      subtitle: Text(
        award == null
            ? 'Locked'
            : 'Unlocked ${DateFormat.yMMMd().format(award!.awardedAt.toLocal())}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(definition.condition),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            definition.rpgName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
