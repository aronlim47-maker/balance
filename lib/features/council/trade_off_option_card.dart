import 'package:flutter/material.dart';

class TradeOffOptionCard extends StatelessWidget {
  const TradeOffOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.movedMinutes,
    required this.recoveryMinutes,
    required this.protectedSummary,
    required this.costSummary,
    required this.roomSummary,
    required this.reviewSummary,
    required this.isSelected,
    required this.onTap,
    this.needsAgreement = false,
    this.capacitySummary,
  });

  final String title;
  final String description;
  final int movedMinutes;
  final int recoveryMinutes;
  final String protectedSummary;
  final String costSummary;
  final String roomSummary;
  final String reviewSummary;
  final bool isSelected;
  final bool needsAgreement;
  final String? capacitySummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: isSelected
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                _Tag(icon: Icons.swap_horiz, label: '$movedMinutes min moved'),
                if (recoveryMinutes > 0)
                  _Tag(
                    icon: Icons.spa_outlined,
                    label: '$recoveryMinutes min recovery',
                  ),
                if (needsAgreement)
                  const _Tag(
                    icon: Icons.groups_outlined,
                    label: 'Needs agreement',
                  ),
              ],
            ),
          ),
          ExpansionTile(
            subtitle: capacitySummary == null ? null : Text(capacitySummary!),
            title: const Text('See trade-offs'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _EffectLine(label: 'Protected', value: protectedSummary),
              const SizedBox(height: 8),
              _EffectLine(label: 'Cost', value: costSummary),
              const SizedBox(height: 8),
              _EffectLine(label: 'Room created', value: roomSummary),
              const SizedBox(height: 8),
              _EffectLine(
                label: 'Check before confirming',
                value: reviewSummary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EffectLine extends StatelessWidget {
  const _EffectLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(label)],
    ),
  );
}
