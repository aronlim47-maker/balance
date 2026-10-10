import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/sound_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
import '../../domain/models/achievement_models.dart';
import '../auth/auth_view_model.dart';

/// Badge colour for earned achievements.
const _gold = Color(0xFFE8C46A);

IconData _emblem(String key) => switch (key) {
  'protected_rest' => Icons.bedtime_outlined,
  'safe_trade_off' => Icons.balance_outlined,
  'deadline_safety' => Icons.hourglass_bottom_rounded,
  'early_review' => Icons.visibility_outlined,
  'protected_limit' => Icons.shield_outlined,
  'reflection' => Icons.menu_book_outlined,
  'team_coordination' => Icons.groups_outlined,
  _ => Icons.workspace_premium_outlined,
};

/// RPG-style wall of seven badges: earned ones glow, locked ones are dimmed.
/// Practical names come first; tapping a badge shows how to unlock it.
class AchievementWall extends StatelessWidget {
  const AchievementWall({
    super.key,
    required this.definitions,
    required this.awardFor,
  });

  final List<AchievementDefinition> definitions;
  final AchievementAward? Function(String key) awardFor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 3 : 2;
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final d in definitions)
            SizedBox(
              width: width,
              child: _Badge(definition: d, award: awardFor(d.key)),
            ),
        ],
      );
    },
  );
}

class _Emblem extends StatelessWidget {
  const _Emblem({
    required this.keyName,
    required this.unlocked,
    this.size = 56,
  });

  final String keyName;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: unlocked
          ? const RadialGradient(colors: [Color(0xFF3A3220), Color(0xFF1B1F29)])
          : null,
      color: unlocked ? null : BalanceColors.surfaceSunken,
      border: Border.all(
        color: unlocked ? _gold : BalanceColors.outline,
        width: unlocked ? 2 : 1.5,
      ),
      boxShadow: unlocked
          ? [BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 16)]
          : null,
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          _emblem(keyName),
          size: size * 0.46,
          color: unlocked ? _gold : BalanceColors.textFaint,
        ),
        if (!unlocked)
          Positioned(
            right: size * 0.06,
            bottom: size * 0.06,
            child: Icon(
              Icons.lock_rounded,
              size: size * 0.24,
              color: BalanceColors.textMuted,
            ),
          ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.definition, required this.award});

  final AchievementDefinition definition;
  final AchievementAward? award;

  @override
  Widget build(BuildContext context) {
    final unlocked = award != null;
    final status = unlocked
        ? 'Unlocked ${DateFormat('d MMM').format(award!.awardedAt.toLocal())}'
        : 'Locked';
    return Semantics(
      button: true,
      label:
          '${definition.practicalName}, ${definition.rpgName}. $status. '
          '${definition.condition}',
      excludeSemantics: true,
      child: Material(
        color: unlocked ? const Color(0xFF1E1C17) : BalanceColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: unlocked
                ? _gold.withValues(alpha: 0.6)
                : BalanceColors.outline,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showDetails(context, definition, award),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
            child: Column(
              children: [
                _Emblem(keyName: definition.key, unlocked: unlocked),
                const SizedBox(height: 10),
                Text(
                  definition.practicalName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.4,
                    color: unlocked
                        ? BalanceColors.text
                        : BalanceColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  definition.rpgName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: unlocked ? _gold : BalanceColors.textFaint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: unlocked
                        ? BalanceColors.calm
                        : BalanceColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showDetails(
  BuildContext context,
  AchievementDefinition definition,
  AchievementAward? award,
) {
  final unlocked = award != null;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Emblem(keyName: definition.key, unlocked: unlocked, size: 84),
            const SizedBox(height: 14),
            Text(
              definition.practicalName,
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            Text(
              definition.rpgName,
              style: TextStyle(
                color: unlocked ? _gold : BalanceColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              unlocked ? 'Earned by' : 'How to unlock',
              style: const TextStyle(
                fontSize: 12,
                color: BalanceColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(definition.condition, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              unlocked
                  ? 'Unlocked on ${DateFormat('d MMMM y').format(award.awardedAt.toLocal())}'
                  : definition.key == 'team_coordination'
                  ? 'Needs shared tasks, which arrive in a later version.'
                  : 'Locked',
              style: TextStyle(
                fontSize: 13,
                color: unlocked ? BalanceColors.calm : BalanceColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Celebrates achievements the user has not seen yet, once each, with an
/// animated badge and the unlock chime. Seen keys are stored per account on
/// the device; if storage is unavailable nothing is shown.
class AchievementUnlockWatcher extends StatefulWidget {
  const AchievementUnlockWatcher({
    super.key,
    required this.definitions,
    required this.awardFor,
    required this.ready,
  });

  final List<AchievementDefinition> definitions;
  final AchievementAward? Function(String key) awardFor;

  /// True once awards have loaded without error.
  final bool ready;

  @override
  State<AchievementUnlockWatcher> createState() =>
      _AchievementUnlockWatcherState();
}

class _AchievementUnlockWatcherState extends State<AchievementUnlockWatcher> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    if (widget.ready && !_checking) {
      _checking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
    return const SizedBox.shrink();
  }

  Future<void> _check() async {
    try {
      final owner = context.read<AuthViewModel>().currentUserId ?? 'local';
      final storeKey = 'balance.seen_achievements.v1.$owner';
      final prefs = SharedPreferencesAsync();
      final seen = (await prefs.getStringList(storeKey) ?? const []).toSet();
      final fresh = [
        for (final d in widget.definitions)
          if (widget.awardFor(d.key) != null && !seen.contains(d.key)) d,
      ];
      if (fresh.isEmpty || !mounted) return;
      await prefs.setStringList(storeKey, [
        ...seen,
        ...fresh.map((d) => d.key),
      ]);
      if (!mounted) return;
      _sound(context)?.playAchievement();
      await showDialog<void>(
        context: context,
        builder: (_) => _UnlockDialog(definitions: fresh),
      );
    } catch (_) {
      // Celebration is optional.
    } finally {
      _checking = false;
    }
  }

  SoundService? _sound(BuildContext context) {
    try {
      return context.read<SoundService>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.definitions});
  final List<AchievementDefinition> definitions;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.definitions.first;
    final more = widget.definitions.length - 1;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final pop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: Curves.elasticOut),
    );
    return Dialog(
      backgroundColor: const Color(0xFF16140F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _gold.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ACHIEVEMENT UNLOCKED',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 2.4,
                color: _gold,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 150,
              height: 150,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: reduceMotion
                      ? null
                      : _RaysPainter(_controller.value),
                  child: Center(
                    child: ScaleTransition(
                      scale: reduceMotion
                          ? const AlwaysStoppedAnimation(1)
                          : pop,
                      child: _Emblem(
                        keyName: first.key,
                        unlocked: true,
                        size: 96,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              first.practicalName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            Text(first.rpgName, style: const TextStyle(color: _gold)),
            const SizedBox(height: 10),
            Text(
              first.condition,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BalanceColors.textMuted),
            ),
            if (more > 0) ...[
              const SizedBox(height: 8),
              Text(
                '+ $more more unlocked',
                style: const TextStyle(color: BalanceColors.calm),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft golden rays that fade in and slowly turn behind the badge.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final opacity = (t < 0.3 ? t / 0.3 : 1.0) * 0.35;
    final paint = Paint()..color = _gold.withValues(alpha: opacity);
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final angle = i * 2 * math.pi / rays + t * 0.6;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(angle - 0.08),
          center.dy + radius * math.sin(angle - 0.08),
        )
        ..lineTo(
          center.dx + radius * math.cos(angle + 0.08),
          center.dy + radius * math.sin(angle + 0.08),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.t != t;
}
