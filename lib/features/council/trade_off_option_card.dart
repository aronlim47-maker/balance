import 'package:flutter/material.dart';

class TradeOffOptionCard extends StatelessWidget {
  const TradeOffOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.movedMinutes,
    required this.recoveryMinutes,
    required this.isSelected,
    required this.onTap,
    this.needsAgreement = false,
  });

  final String title;
  final String description;
  final int movedMinutes;
  final int recoveryMinutes;
  final bool isSelected;
  final bool needsAgreement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: isSelected
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(description),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tag(
                          icon: Icons.swap_horiz,
                          label: '$movedMinutes min moved',
                        ),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
