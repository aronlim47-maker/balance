import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/sound_service.dart';
import '../theme/balance_colors.dart';

/// Gold music button in the page header: one tap turns the background music
/// on or off.
///
/// It stands out on purpose (gold ring and glow while music plays) so a
/// student who did not expect sound can find it at once. Switching plays a
/// short pop-and-ripple animation, skipped when the phone asks for reduced
/// motion. Shows nothing when no [SoundService] is provided (single-screen
/// tests).
class SoundToggleButton extends StatefulWidget {
  const SoundToggleButton({super.key});

  static const turnOffLabel = 'Turn background music off';
  static const turnOnLabel = 'Turn background music on';

  @override
  State<SoundToggleButton> createState() => _SoundToggleButtonState();
}

class _SoundToggleButtonState extends State<SoundToggleButton>
    with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  SoundService? _service(BuildContext context) {
    try {
      return context.watch<SoundService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _toggle(SoundService sound) {
    sound.setMusic(!sound.musicOn);
    if (!MediaQuery.of(context).disableAnimations) {
      _ripple.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sound = _service(context);
    if (sound == null) return const SizedBox.shrink();
    final on = sound.musicOn;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final ring = on ? BalanceColors.gold : BalanceColors.outline;
    return IconButton(
      tooltip: on
          ? SoundToggleButton.turnOffLabel
          : SoundToggleButton.turnOnLabel,
      onPressed: () => _toggle(sound),
      icon: SizedBox(
        width: 34,
        height: 34,
        child: AnimatedBuilder(
          animation: _ripple,
          builder: (context, child) {
            final t = _ripple.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Ripple that spreads out once after each tap.
                if (t > 0 && t < 1)
                  Container(
                    width: 34 + 22 * t,
                    height: 34 + 22 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ring.withValues(alpha: 0.7 * (1 - t)),
                        width: 2,
                      ),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 250),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? BalanceColors.goldSurface : Colors.transparent,
              border: Border.all(color: ring, width: 1.6),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: BalanceColors.gold.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : const [],
            ),
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: RotationTransition(
                  turns: Tween<double>(begin: -0.15, end: 0).animate(animation),
                  child: child,
                ),
              ),
              child: Icon(
                on ? Icons.music_note_rounded : Icons.music_off_rounded,
                key: ValueKey(on),
                size: 19,
                color: on ? BalanceColors.gold : BalanceColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
