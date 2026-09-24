import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/section_header.dart';
import 'war_council_view_model.dart';

class PlanUpdatedScreen extends StatelessWidget {
  const PlanUpdatedScreen({super.key, required this.changeId});
  final String changeId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WarCouncilViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Plan updated')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              viewModel.wasUndone ? Icons.undo_rounded : Icons.check_circle,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            SectionHeader(
              title: viewModel.wasUndone
                  ? 'Changes were undone'
                  : 'Your evening is balanced',
              subtitle: viewModel.wasUndone
                  ? 'Task placements and recovery time were restored.'
                  : 'The selected move and recovery reservation were saved together.',
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.event_repeat),
                      title: Text('Research task'),
                      subtitle: Text('150 minutes moved to tomorrow'),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.spa_outlined),
                      title: Text('Recovery protected'),
                      subtitle: Text('30 minutes reserved tonight'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Change reference'),
                      subtitle: Text(changeId),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (!viewModel.wasUndone)
              OutlinedButton.icon(
                onPressed: viewModel.undoPlan,
                icon: const Icon(Icons.undo),
                label: const Text('Undo this plan'),
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
}
