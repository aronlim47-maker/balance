import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/app_router.dart';
import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';
import '../auth/auth_view_model.dart';

const _seenKey = 'balance.onboarding.v1';
const _accountKeyPrefix = 'balance.onboarding.v2.';

enum _Art { time, tasks, overload, fix, rest }

class _Step {
  const _Step({
    required this.page,
    required this.title,
    required this.body,
    required this.showMe,
    required this.route,
    required this.art,
  });
  final String page;
  final String title;
  final String body;
  final String showMe;
  final String route;
  final _Art art;
}

const _steps = [
  _Step(
    page: 'Today',
    title: 'Add your free time',
    body:
        'Tell Balance when you are free each day. On Today, tap Add under '
        'Availability.',
    showMe: 'Show me on Today',
    route: AppRoutes.today,
    art: _Art.time,
  ),
  _Step(
    page: 'Quests',
    title: 'Add your tasks',
    body:
        'List what you need to do and when it is due. On Quests, tap Add '
        'task.',
    showMe: 'Show me on Quests',
    route: AppRoutes.quests,
    art: _Art.tasks,
  ),
  _Step(
    page: 'Today',
    title: 'See if your day fits',
    body:
        'If your tasks need more time than you have, Today turns red and '
        'shows how much is over.',
    showMe: 'Show me on Today',
    route: AppRoutes.today,
    art: _Art.overload,
  ),
  _Step(
    page: 'Council',
    title: 'Fix it safely',
    body:
        'Council suggests moving flexible work to a day with room. Nothing '
        'changes until you confirm, and you can undo it.',
    showMe: 'Show me on Council',
    route: AppRoutes.council,
    art: _Art.fix,
  ),
  _Step(
    page: 'Sanctuary · Journey',
    title: 'Rest and look back',
    body:
        'Protect free time for rest in Sanctuary. Journey shows your week and '
        'the badges you earn. No streaks, no pressure.',
    showMe: 'Show me Sanctuary',
    route: AppRoutes.sanctuary,
    art: _Art.rest,
  ),
];

/// Whether to show the beginner guide to this account on this device.
///
/// The guide is shown once per account. A device that already showed it to
/// someone earlier must still show it to a brand-new account, so the old
/// "seen on this device" flag only hides it for accounts that were confirmed
/// more than a day ago (existing users who have already seen it).
bool shouldShowGuide({
  required bool seenByAccount,
  required bool seenOnDevice,
  DateTime? confirmedAt,
  DateTime? now,
}) {
  if (seenByAccount) return false;
  if (!seenOnDevice) return true;
  if (confirmedAt == null) return false;
  return (now ?? DateTime.now()).difference(confirmedAt) <
      const Duration(hours: 24);
}

/// Shows the beginner guide the first time each account opens Today.
/// If device storage is unavailable, it stays hidden rather than nagging.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    try {
      AuthViewModel? auth;
      try {
        auth = context.read<AuthViewModel>();
      } catch (_) {}
      final accountKey = '$_accountKeyPrefix${auth?.currentUserId ?? 'local'}';
      final prefs = SharedPreferencesAsync();
      final show = shouldShowGuide(
        seenByAccount: await prefs.getBool(accountKey) ?? false,
        seenOnDevice: await prefs.getBool(_seenKey) ?? false,
        confirmedAt: auth?.currentUserConfirmedAt,
      );
      if (!mounted) return;
      if (!show) {
        await prefs.setBool(accountKey, true);
        return;
      }
      final route = await showOnboarding(context);
      await prefs.setBool(accountKey, true);
      await prefs.setBool(_seenKey, true);
      if (route != null && mounted) context.go(route);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens the beginner guide; also reachable from Profile.
///
/// Returns the route of the page the student asked to see with "Show me",
/// or null when the guide was finished or skipped.
Future<String?> showOnboarding(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => const OnboardingScreen(),
      ),
    );

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _steps.length - 1;
    return Scaffold(
      backgroundColor: BalanceColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 4, 0),
              child: Row(
                children: [
                  const Expanded(child: Eyebrow('Beginner guide')),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    _StepPage(step: _steps[i], number: i + 1),
                ],
              ),
            ),
            Semantics(
              label: 'Step ${_index + 1} of ${_steps.length}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? BalanceColors.accentBright
                            : BalanceColors.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  // The app's buttons fill their width, so both sit in
                  // Expanded inside this Row.
                  if (_index > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: last
                          ? () => Navigator.of(context).pop()
                          : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                      child: Text(last ? 'Get started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step: a short animation, one sentence, and a "Show me" shortcut.
/// The animation plays once when the step appears; tap it to replay.
class _StepPage extends StatefulWidget {
  const _StepPage({required this.step, required this.number});
  final _Step step;
  final int number;

  @override
  State<_StepPage> createState() => _StepPageState();
}

class _StepPageState extends State<_StepPage>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _replay() {
    if (MediaQuery.of(context).disableAnimations) return;
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Replay animation',
            onTap: _replay,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _replay,
              child: ExcludeSemantics(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 360),
                  height: 230,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BalanceColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BalanceColors.outline),
                  ),
                  // Decorative drawing at a fixed design size, scaled to fit.
                  // The text below carries the meaning and follows the
                  // phone's font size.
                  child: FittedBox(
                    child: MediaQuery.withNoTextScaling(
                      child: SizedBox(
                        width: 328,
                        height: 158,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) =>
                              _StepArt(art: step.art, t: _animation.value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Eyebrow('Step ${widget.number} of ${_steps.length} · ${step.page}'),
          const SizedBox(height: 10),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 26,
              height: 1.2,
              color: BalanceColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: BalanceColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(step.route),
            icon: const Icon(Icons.arrow_forward),
            label: Text(step.showMe),
          ),
        ],
      ),
    );
  }
}

/// Progress (0–1) of [t] within the [begin]–[end] part of the animation.
double _part(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeOut,
]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

class _StepArt extends StatelessWidget {
  const _StepArt({required this.art, required this.t});
  final _Art art;
  final double t;

  @override
  Widget build(BuildContext context) => switch (art) {
    _Art.time => _TimeArt(t),
    _Art.tasks => _TasksArt(t),
    _Art.overload => _OverloadArt(t),
    _Art.fix => _FixArt(t),
    _Art.rest => _RestArt(t),
  };
}

TextStyle get _small => TextStyle(fontSize: 13, color: BalanceColors.textMuted);

/// A rounded bar: blue up to [blue], red from [blue] to [red] (fractions).
class _Bar extends StatelessWidget {
  const _Bar({required this.blue, this.red = 0, this.marker});
  final double blue;
  final double red;
  final double? marker;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      return SizedBox(
        height: 18,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: BalanceColors.surfaceRaised,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: w * blue,
              decoration: BoxDecoration(
                color: BalanceColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (red > blue)
              Positioned(
                left: w * blue,
                width: w * (red - blue),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: BalanceColors.dangerFill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            if (marker != null)
              Positioned(
                left: w * marker! - 1,
                top: -2,
                bottom: -2,
                child: Container(width: 2, color: BalanceColors.text),
              ),
          ],
        ),
      );
    },
  );
}

class _TaskChip extends StatelessWidget {
  const _TaskChip(this.label, {this.tone = RpgTone.muted});
  final String label;
  final RpgTone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: BalanceColors.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: tone == RpgTone.muted ? BalanceColors.outline : tone.border,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DiamondIcon(size: 12, color: BalanceColors.accentBright),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: BalanceColors.text,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TimeArt extends StatelessWidget {
  const _TimeArt(this.t);
  final double t;

  @override
  Widget build(BuildContext context) {
    final fill = _part(t, 0.1, 0.8);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_available, color: BalanceColors.calm),
            const SizedBox(width: 8),
            Expanded(child: Text('Availability', style: _small)),
            Text(
              '${(3 * fill).round()}h free',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: BalanceColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Bar(blue: fill),
        const SizedBox(height: 14),
        Opacity(
          opacity: _part(t, 0.7, 1),
          child: Text('9:00 AM – 12:00 PM', style: _small),
        ),
      ],
    );
  }
}

class _TasksArt extends StatelessWidget {
  const _TasksArt(this.t);
  final double t;

  @override
  Widget build(BuildContext context) {
    Widget slide(String label, double begin) {
      final p = _part(t, begin, begin + 0.45, Curves.easeOutBack);
      return Opacity(
        opacity: _part(t, begin, begin + 0.2),
        child: Transform.translate(
          offset: Offset((1 - p) * 220, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _TaskChip(label),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        slide('Report · 3h', 0),
        const SizedBox(height: 12),
        slide('Deadline work · 2h', 0.25),
        const SizedBox(height: 12),
        Opacity(
          opacity: _part(t, 0.75, 1),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('5h of work planned', style: _small),
          ),
        ),
      ],
    );
  }
}

class _OverloadArt extends StatelessWidget {
  const _OverloadArt(this.t);
  final double t;

  @override
  Widget build(BuildContext context) {
    final blue = 0.6 * _part(t, 0, 0.45);
    final red = blue + 0.4 * _part(t, 0.45, 0.8);
    final tag = _part(t, 0.8, 1, Curves.elasticOut);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Planned 5h  ·  Free 3h', style: _small)),
            Transform.scale(
              scale: tag,
              child: const RpgTag('2h over', tone: RpgTone.danger),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Bar(blue: blue, red: red, marker: 0.6),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(flex: 6, child: Text('Fits', style: _small)),
            Expanded(
              flex: 4,
              child: Text(
                'Too much',
                style: TextStyle(fontSize: 13, color: BalanceColors.danger),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FixArt extends StatelessWidget {
  const _FixArt(this.t);
  final double t;

  @override
  Widget build(BuildContext context) {
    final move = _part(t, 0.15, 0.7, Curves.easeInOut);
    final fixed = t >= 0.7;
    Widget day(String name, Widget tag) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BalanceColors.surfaceSunken,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BalanceColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: _small),
            const SizedBox(height: 6),
            tag,
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        // Each column is half the width minus the gap.
        final column = (box.maxWidth - 12) / 2;
        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                day(
                  'Today',
                  fixed
                      ? const RpgTag('Fits', tone: RpgTone.calm)
                      : const RpgTag('2h over', tone: RpgTone.danger),
                ),
                const SizedBox(width: 12),
                day('Tomorrow', const RpgTag('Room', tone: RpgTone.calm)),
              ],
            ),
            Positioned(
              left: 10 + move * (column + 12),
              bottom: 12,
              width: column - 20,
              child: _TaskChip(
                'Report · 2h',
                tone: fixed ? RpgTone.calm : RpgTone.accent,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RestArt extends StatelessWidget {
  const _RestArt(this.t);
  final double t;

  @override
  Widget build(BuildContext context) {
    final fire = _part(t, 0, 0.5);
    final badge = _part(t, 0.45, 1, Curves.elasticOut);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BalanceColors.warningBg,
                boxShadow: [
                  BoxShadow(
                    color: BalanceColors.warning.withValues(alpha: 0.45 * fire),
                    blurRadius: 24 * fire,
                  ),
                ],
              ),
              child: Transform.scale(
                scale: 0.6 + 0.4 * fire,
                child: Icon(
                  Icons.local_fire_department,
                  size: 44,
                  color: BalanceColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Rest time', style: _small),
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: badge,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BalanceColors.surfaceRaised,
                  border: Border.all(color: BalanceColors.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: BalanceColors.gold.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium,
                  size: 40,
                  color: BalanceColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: _part(t, 0.6, 1),
              child: Text('Badge earned', style: _small),
            ),
          ],
        ),
      ],
    );
  }
}
