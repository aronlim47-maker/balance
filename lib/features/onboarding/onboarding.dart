import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/shared_widgets/rpg_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';

const _seenKey = 'balance.onboarding.v1';

class _Page {
  const _Page(this.icon, this.eyebrow, this.title, this.body);
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
}

const _pages = [
  _Page(
    Icons.hourglass_bottom_rounded,
    'Detect · Today',
    'See when your day does not fit',
    'Add your free time and your tasks. Balance compares planned work with '
        'available time and shows five workload signals. Missing data says '
        'Unknown, never zero.',
  ),
  _Page(
    Icons.balance_outlined,
    'Decide · War Council',
    'Choose a safe trade-off',
    'Council suggests moving flexible work to days with room. Protected '
        'commitments like shifts, family and sleep never move. Nothing changes '
        'until you confirm, and every plan can be undone.',
  ),
  _Page(
    Icons.bedtime_outlined,
    'Recover and reflect',
    'Protect rest, without pressure',
    'Sanctuary keeps freed time for rest; skipping has no penalty. Journey '
        'shows your week privately and unlocks achievements for safe planning. '
        'No streaks, no rankings.',
  ),
];

/// Shows the three-page introduction the first time on this device.
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
      final prefs = SharedPreferencesAsync();
      if (await prefs.getBool(_seenKey) ?? false) return;
      if (!mounted) return;
      await showOnboarding(context);
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens the introduction; also reachable from Profile.
Future<void> showOnboarding(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
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
    final last = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: BalanceColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [for (final page in _pages) _PageView(page: page)],
              ),
            ),
            Semantics(
              label: 'Page ${_index + 1} of ${_pages.length}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});
  final _Page page;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    child: Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BalanceColors.accentDim,
            border: Border.all(color: BalanceColors.accent, width: 2),
          ),
          child: Icon(page.icon, size: 56, color: BalanceColors.accentBright),
        ),
        const SizedBox(height: 32),
        Eyebrow(page.eyebrow),
        const SizedBox(height: 10),
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w700,
            fontSize: 26,
            height: 1.2,
            color: BalanceColors.text,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          page.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 1.45,
            color: BalanceColors.textMuted,
          ),
        ),
      ],
    ),
  );
}
