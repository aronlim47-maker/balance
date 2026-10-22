import 'package:flutter/material.dart';

import 'one_shot.dart';
import '../l10n/tr.dart';

/// Balance's logo: the gold guild crest (shield with a balance beam on a
/// pivot) on its dark tile, the same artwork as the launcher icon.
///
/// The colours are the brand's and stay the same in the dark and parchment
/// looks, like an app icon does.
class BalanceCrest extends StatelessWidget {
  const BalanceCrest({super.key, this.size = 88, this.shine = false});

  final double size;

  /// Sweeps one band of light across the shield when first shown.
  final bool shine;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Balance logo'.tr,
    child: shine
        ? OneShot(
            duration: const Duration(milliseconds: 1100),
            delay: const Duration(milliseconds: 350),
            builder: (context, t) => CustomPaint(
              size: Size.square(size),
              painter: _CrestPainter(glint: t),
            ),
          )
        : CustomPaint(size: Size.square(size), painter: _CrestPainter()),
  );
}

class _CrestPainter extends CustomPainter {
  _CrestPainter({this.glint = 1});

  /// 0 → 1 position of the light sweep; at 1 it has left the shield.
  final double glint;

  static const _tile = Color(0xFF151820);
  static const _shield = Color(0xFF2A2E4A);
  static const _gold = Color(0xFFE8C46A);

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 100 × 100 grid, matching the icon artwork.
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(22),
      ),
      Paint()..color = _tile,
    );
    final shield = Path()
      ..moveTo(50, 14)
      ..lineTo(80, 24)
      ..lineTo(80, 50)
      ..quadraticBezierTo(80, 74, 50, 88)
      ..quadraticBezierTo(20, 74, 20, 50)
      ..lineTo(20, 24)
      ..close();
    canvas.drawPath(shield, Paint()..color = _shield);
    if (glint > 0 && glint < 1) {
      // A slanted band of light crossing the shield from left to right.
      final x = -30 + 160 * Curves.easeInOut.transform(glint);
      canvas
        ..save()
        ..clipPath(shield)
        ..drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + 14, 0)
            ..lineTo(x - 16, 100)
            ..lineTo(x - 30, 100)
            ..close(),
          Paint()..color = _gold.withValues(alpha: 0.35),
        )
        ..restore();
    }
    canvas.drawPath(
      shield,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      const Offset(34, 42),
      const Offset(66, 42),
      Paint()
        ..color = _gold
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 47)
        ..lineTo(59, 62)
        ..lineTo(41, 62)
        ..close(),
      Paint()..color = _gold,
    );
  }

  @override
  bool shouldRepaint(_CrestPainter oldDelegate) => oldDelegate.glint != glint;
}
