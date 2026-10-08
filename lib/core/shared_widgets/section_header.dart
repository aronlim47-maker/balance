import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/balance_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w700,
            fontSize: 26,
            letterSpacing: 0.6,
            height: 1.1,
            color: BalanceColors.text,
          ),
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(
          subtitle!,
          style: const TextStyle(
            fontSize: 15,
            height: 1.35,
            color: BalanceColors.textMuted,
          ),
        ),
      ],
    ],
  );
}
