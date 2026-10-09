import 'package:flutter/material.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';

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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RpgPanel(
    selected: isSelected,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          selected: isSelected,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: DiamondIcon(
                      size: 16,
                      filled: isSelected,
                      color: isSelected
                          ? BalanceColors.accentBright
                          : BalanceColors.textFaint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                            letterSpacing: 0.8,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const RpgLabel('What changes', size: 11),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const RpgTag('Selected', tone: RpgTone.accent),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(44, 4, 16, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              RpgTag('$movedMinutes min moved', icon: Icons.swap_horiz),
              if (recoveryMinutes > 0)
                RpgTag(
                  '$recoveryMinutes min recovery',
                  tone: RpgTone.calm,
                  icon: Icons.eco_outlined,
                ),
              if (needsAgreement)
                const RpgTag(
                  'Needs agreement',
                  tone: RpgTone.warning,
                  icon: Icons.groups_outlined,
                ),
            ],
          ),
        ),
        ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(44, 0, 12, 0),
          title: const Text(
            'See trade-offs',
            style: TextStyle(color: BalanceColors.accentBright, fontSize: 14),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(44, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EffectLine(
              label: 'Protected',
              value: protectedSummary,
              valueColor: BalanceColors.calm,
            ),
            const SizedBox(height: 10),
            _EffectLine(label: 'Cost', value: costSummary),
            const SizedBox(height: 10),
            _EffectLine(label: 'Room created', value: roomSummary),
            const SizedBox(height: 10),
            _EffectLine(
              label: 'Check before confirming',
              value: reviewSummary,
              valueColor: BalanceColors.warning,
            ),
          ],
        ),
      ],
    ),
  );
}

class _EffectLine extends StatelessWidget {
  const _EffectLine({
    required this.label,
    required this.value,
    this.valueColor = BalanceColors.text,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Wording kept as-is (not uppercased) so labels stay stable.
      Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.displayFont,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1.8,
          color: BalanceColors.textMuted,
        ),
      ),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: valueColor, height: 1.35)),
    ],
  );
}
