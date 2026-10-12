import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/sound_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/balance_colors.dart';

/// Sanctuary's rest camp: a small night-or-day scene with a tent and a
/// gently flickering campfire whose embers drift up.
///
/// The sky follows the phone's clock (dawn, day, dusk, night). The fire is
/// the only animation in Balance that keeps moving, and only while this
/// scene is on screen; with reduced motion it is a still picture. With
/// [ambience], a soft crackle plays while the scene is shown and background
/// music is on. [flame] scales the fire (used by the breathing exercise).
class CampScene extends StatefulWidget {
  const CampScene({
    super.key,
    this.height = 170,
    this.flame = 1,
    this.ambience = false,
    this.now,
  });

  final double height;
  final double flame;
  final bool ambience;

  /// Clock used for the sky; defaults to the current time.
  final DateTime? now;

  /// Off in widget tests (see test/flutter_test_config.dart), so screens
  /// settle; the picture is otherwise the same.
  static bool loop = true;

  @override
  State<CampScene> createState() => _CampSceneState();
}

class _CampSceneState extends State<CampScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fire = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  SoundService? _sound;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (CampScene.loop && !still) {
      if (!_fire.isAnimating) _fire.repeat();
    } else {
      _fire.stop();
      _fire.value = 0.3;
    }
    if (widget.ambience && _sound == null) {
      try {
        _sound = context.read<SoundService>();
        _sound!.setAtCamp(true);
      } on ProviderNotFoundException {
        _sound = null;
      }
    }
  }

  @override
  void dispose() {
    _sound?.setAtCamp(false);
    _fire.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Rest camp: a tent beside a small campfire',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _fire,
          builder: (context, _) => CustomPaint(
            painter: _CampPainter(
              t: _fire.value,
              hour: (widget.now ?? DateTime.now()).hour,
              flame: widget.flame,
            ),
          ),
        ),
      ),
    ),
  );
}

enum _Sky { dawn, day, dusk, night }

class _CampPainter extends CustomPainter {
  _CampPainter({required this.t, required this.hour, required this.flame});

  final double t;
  final int hour;
  final double flame;

  _Sky get sky => hour >= 5 && hour < 8
      ? _Sky.dawn
      : hour >= 8 && hour < 17
      ? _Sky.day
      : hour >= 17 && hour < 20
      ? _Sky.dusk
      : _Sky.night;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final (top, bottom, ground) = switch (sky) {
      _Sky.dawn => (
        const Color(0xFF2E2A5A),
        const Color(0xFFE8A37C),
        const Color(0xFF2C3324),
      ),
      _Sky.day => (
        const Color(0xFF4A7BC8),
        const Color(0xFFA9D3F0),
        const Color(0xFF3E5232),
      ),
      _Sky.dusk => (
        const Color(0xFF3B2C5C),
        const Color(0xFFE7865B),
        const Color(0xFF262B1E),
      ),
      _Sky.night => (
        const Color(0xFF0B1026),
        const Color(0xFF232B52),
        const Color(0xFF14170F),
      ),
    };
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );

    // Stars (night and dusk), twinkling slowly.
    if (sky == _Sky.night || sky == _Sky.dusk) {
      final rnd = math.Random(7);
      for (var i = 0; i < 28; i++) {
        final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.5);
        final twinkle =
            0.5 + 0.5 * math.sin(2 * math.pi * (t * 2 + rnd.nextDouble()));
        canvas.drawCircle(
          p,
          rnd.nextDouble() * 1.2 + 0.4,
          Paint()
            ..color = Colors.white.withValues(
              alpha: (sky == _Sky.night ? 0.8 : 0.4) * (0.5 + 0.5 * twinkle),
            ),
        );
      }
    }

    // Moon at night, sun otherwise.
    if (sky == _Sky.night) {
      canvas.drawCircle(
        Offset(w * 0.82, h * 0.2),
        13,
        Paint()..color = const Color(0xFFF2E6C4),
      );
      canvas.drawCircle(
        Offset(w * 0.82 + 6, h * 0.2 - 3),
        11,
        Paint()..color = top,
      );
    } else {
      final y = sky == _Sky.day ? h * 0.18 : h * 0.42;
      canvas.drawCircle(
        Offset(w * 0.8, y),
        sky == _Sky.day ? 14 : 18,
        Paint()
          ..color = sky == _Sky.day
              ? const Color(0xFFFFF2C2)
              : const Color(0xFFFFC98A),
      );
    }

    // Two layers of hills.
    final far = Color.lerp(bottom, Colors.black, 0.45)!;
    final near = Color.lerp(bottom, Colors.black, 0.65)!;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.62)
        ..quadraticBezierTo(w * 0.18, h * 0.4, w * 0.36, h * 0.58)
        ..quadraticBezierTo(w * 0.55, h * 0.36, w * 0.75, h * 0.56)
        ..quadraticBezierTo(w * 0.9, h * 0.46, w, h * 0.55)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = far,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.72)
        ..quadraticBezierTo(w * 0.3, h * 0.6, w * 0.6, h * 0.7)
        ..quadraticBezierTo(w * 0.85, h * 0.78, w, h * 0.68)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = near,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.8, w, h * 0.2),
      Paint()..color = ground,
    );

    final fire = Offset(w * 0.55, h * 0.84);

    // Warm glow on the ground around the fire.
    final glowR = 70 * flame * (0.92 + 0.08 * math.sin(2 * math.pi * t * 9));
    canvas.drawCircle(
      fire,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB347).withValues(alpha: 0.45),
            const Color(0xFFFFB347).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: fire, radius: glowR)),
    );

    // Tent.
    final tentX = w * 0.22, tentY = h * 0.84;
    canvas.drawPath(
      Path()
        ..moveTo(tentX - 38, tentY)
        ..lineTo(tentX, tentY - 46)
        ..lineTo(tentX + 38, tentY)
        ..close(),
      Paint()..color = const Color(0xFF4F4396),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tentX - 10, tentY)
        ..lineTo(tentX, tentY - 26)
        ..lineTo(tentX + 10, tentY)
        ..close(),
      Paint()..color = const Color(0xFF1B1733),
    );
    canvas.drawLine(
      Offset(tentX, tentY - 46),
      Offset(tentX, tentY - 54),
      Paint()
        ..color = BalanceColors.gold
        ..strokeWidth = 2,
    );

    // Logs.
    final log = Paint()
      ..color = const Color(0xFF5B3A22)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(fire.translate(-16, 4), fire.translate(16, -2), log)
      ..drawLine(fire.translate(-16, -2), fire.translate(16, 4), log);

    // Flame: three layered tongues that sway and flicker.
    void tongue(double scale, Color color, double phase) {
      final sway = 3 * math.sin(2 * math.pi * (t * 5 + phase));
      final flick = 1 + 0.1 * math.sin(2 * math.pi * (t * 11 + phase));
      final height = 34 * scale * flame * flick;
      final width = 13 * scale * flame;
      final base = fire.translate(0, -2);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - width, base.dy)
          ..quadraticBezierTo(
            base.dx - width * 1.1,
            base.dy - height * 0.55,
            base.dx + sway,
            base.dy - height,
          )
          ..quadraticBezierTo(
            base.dx + width * 1.1,
            base.dy - height * 0.55,
            base.dx + width,
            base.dy,
          )
          ..close(),
        Paint()..color = color,
      );
    }

    tongue(1.0, const Color(0xFFE8622C), 0);
    tongue(0.72, const Color(0xFFFFB347), 0.3);
    tongue(0.42, const Color(0xFFFFF0B3), 0.6);

    // Embers drifting up.
    for (var i = 0; i < 7; i++) {
      final life = (t * 3 + i / 7) % 1;
      final x =
          fire.dx +
          10 * math.sin(2 * math.pi * (life + i * 0.37)) +
          (i - 3) * 2;
      final y = fire.dy - 20 - life * 70 * flame;
      canvas.drawCircle(
        Offset(x, y),
        1.6 * (1 - life),
        Paint()..color = const Color(0xFFFFC266).withValues(alpha: 1 - life),
      );
    }
  }

  @override
  bool shouldRepaint(_CampPainter old) =>
      old.t != t || old.hour != hour || old.flame != flame;
}

/// Opens "Breathe with the fire": one minute of slow breathing (in 4 s,
/// hold 4 s, out 4 s) while the fire grows and settles with each breath.
/// Optional, never recorded or scored; Stop works at any time.
Future<void> showBreathing(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const BreathingScreen(),
  ),
);

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  static const cycles = 5;
  static const phaseSeconds = 4;

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  static const _cycle = BreathingScreen.phaseSeconds * 3;
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _cycle * BreathingScreen.cycles),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: BalanceColors.background,
      appBar: AppBar(
        title: const Text('Breathe with the fire'),
        backgroundColor: BalanceColors.background,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final elapsed = _clock.value * _cycle * BreathingScreen.cycles;
            final done = _clock.isCompleted;
            final inCycle = elapsed % _cycle;
            final phase = (inCycle ~/ BreathingScreen.phaseSeconds).clamp(0, 2);
            final within =
                (inCycle - phase * BreathingScreen.phaseSeconds) /
                BreathingScreen.phaseSeconds;
            final count = BreathingScreen.phaseSeconds - within.floor();
            final eased = Curves.easeInOut.transform(within.clamp(0.0, 1.0));
            final size = switch (phase) {
              0 => 0.75 + 0.5 * eased,
              1 => 1.25,
              _ => 1.25 - 0.5 * eased,
            };
            final label = done
                ? 'Well done'
                : switch (phase) {
                    0 => 'Breathe in',
                    1 => 'Hold',
                    _ => 'Breathe out',
                  };
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                CampScene(height: 260, flame: still || done ? 1 : size),
                const SizedBox(height: 28),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  done
                      ? 'One minute of slow breathing. Come back any time.'
                      : '$count · breath ${(elapsed ~/ _cycle) + 1} of '
                            '${BreathingScreen.cycles}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: BalanceColors.textMuted,
                  ),
                ),
                const SizedBox(height: 28),
                if (done) ...[
                  FilledButton(
                    onPressed: () => _clock.forward(from: 0),
                    child: const Text('Again'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(done ? 'Back to camp' : 'Stop'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Optional and private. Nothing is recorded or scored.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: BalanceColors.textMuted,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
