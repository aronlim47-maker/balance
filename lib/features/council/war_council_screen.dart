import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/shared_widgets/balance_scaffold.dart';
import '../../core/shared_widgets/section_header.dart';
import 'trade_off_option_card.dart';
import 'war_council_view_model.dart';

class WarCouncilScreen extends StatelessWidget {
  const WarCouncilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WarCouncilViewModel>();
    return BalanceScaffold(
      title: 'War Council',
      currentIndex: 2,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const SectionHeader(
            title: 'Tonight is overloaded',
            subtitle: 'Choose a valid trade-off before confirming any change.',
          ),
          const SizedBox(height: 18),
          const _CapacitySummary(),
          const SizedBox(height: 26),
          const SectionHeader(
            title: 'Choose a plan',
            subtitle: 'Protected commitments will not be moved.',
          ),
          const SizedBox(height: 12),
          for (final option in viewModel.options) ...[
            TradeOffOptionCard(
              title: option.title,
              description: option.description,
              movedMinutes: option.movedMinutes,
              recoveryMinutes: option.recoveryMinutes,
              needsAgreement: option.needsAgreement,
              isSelected: viewModel.selectedOptionId == option.id,
              onTap: () => viewModel.selectOption(option.id),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: viewModel.canConfirm
                ? () async {
                    final changeId = await viewModel.confirmSelectedPlan();
                    if (context.mounted) {
                      context.push('/council/updated/$changeId');
                    }
                  }
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
      ),
    );
  }
}

class _CapacitySummary extends StatelessWidget {
  const _CapacitySummary();

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
                  value: '300 min',
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const Icon(Icons.arrow_forward),
              Expanded(
                child: _Metric(
                  label: 'Available',
                  value: '180 min',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded),
              SizedBox(width: 10),
              Expanded(child: Text('Capacity gap: 120 minutes')),
            ],
          ),
        ],
      ),
    ),
  );
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
