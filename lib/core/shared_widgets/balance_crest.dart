import 'package:flutter/material.dart';

/// Balance's logo: the gold guild crest (shield with a balance beam on a
/// pivot) on its dark tile, the same artwork as the launcher icon.
///
/// The colours are the brand's and stay the same in the dark and parchment
/// looks, like an app icon does.
class BalanceCrest extends StatelessWidget {
  const BalanceCrest({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Balance logo',
    child: CustomPaint(size: Size.square(size), painter: _CrestPainter()),
  );
}

class _CrestPainter extends CustomPainter {
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
  bool shouldRepaint(_CrestPainter oldDelegate) => false;
}
