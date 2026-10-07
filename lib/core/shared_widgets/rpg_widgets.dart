import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/balance_colors.dart';

/// Short duration text: 45 → "45m", 180 → "3h", 150 → "2h 30m".
String formatShortDuration(int minutes) {
  final safe = minutes < 0 ? 0 : minutes;
  final hours = safe ~/ 60;
  final rest = safe % 60;
  if (hours == 0) return '${rest}m';
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}m';
}

/// Tone for a 0–100 planning-load score (matches World Status labels).
RpgTone toneForScore(int? score) {
  if (score == null) return RpgTone.muted;
  if (score < 25) return RpgTone.calm;
  if (score < 50) return RpgTone.accent;
  if (score < 75) return RpgTone.warning;
  return RpgTone.danger;
}

/// Colour family for panels, tags and labels.
enum RpgTone { neutral, accent, calm, danger, warning, muted }

extension RpgToneColors on RpgTone {
  Color get foreground => switch (this) {
    RpgTone.neutral => BalanceColors.text,
    RpgTone.accent => BalanceColors.accentBright,
    RpgTone.calm => BalanceColors.calm,
    RpgTone.danger => BalanceColors.danger,
    RpgTone.warning => BalanceColors.warning,
    RpgTone.muted => BalanceColors.textMuted,
  };

  Color get border => switch (this) {
    RpgTone.neutral => BalanceColors.outlineStrong,
    RpgTone.accent => BalanceColors.accent,
    RpgTone.calm => BalanceColors.calmBorder,
    RpgTone.danger => BalanceColors.dangerBorder,
    RpgTone.warning => BalanceColors.warningBorder,
    RpgTone.muted => BalanceColors.outline,
  };

  Color get background => switch (this) {
    RpgTone.neutral => BalanceColors.surface,
    RpgTone.accent => BalanceColors.surface,
    RpgTone.calm => BalanceColors.calmBg,
    RpgTone.danger => BalanceColors.dangerBg,
    RpgTone.warning => BalanceColors.warningBg,
    RpgTone.muted => BalanceColors.surface,
  };
}

/// A small rotated square, the app's signature mark.
class DiamondIcon extends StatelessWidget {
  const DiamondIcon({
    super.key,
    this.size = 14,
    this.filled = false,
    this.color,
    this.strokeWidth = 1.4,
    this.semanticLabel,
  });

  final double size;
  final bool filled;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.square(size),
      painter: _DiamondPainter(
        color: color ?? IconTheme.of(context).color ?? BalanceColors.text,
        filled: filled,
        strokeWidth: strokeWidth,
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: paint);
    return Semantics(label: semanticLabel, child: paint);
  }
}

class _DiamondPainter extends CustomPainter {
  _DiamondPainter({
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  final Color color;
  final bool filled;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = filled ? 0.0 : strokeWidth / 2;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    final path = Path()
      ..moveTo(inset + w / 2, inset)
      ..lineTo(inset + w, inset + h / 2)
      ..lineTo(inset + w / 2, inset + h)
      ..lineTo(inset, inset + h / 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.color != color ||
          old.filled != filled ||
          old.strokeWidth != strokeWidth;
}

/// Spaced uppercase label text, e.g. "WHAT CHANGES" or "STATUS".
class RpgLabel extends StatelessWidget {
  const RpgLabel(
      this.text, {
        super.key,
        this.tone = RpgTone.muted,
        this.size = 12,
        this.spacing = 2,
        this.weight = FontWeight.w700,
      });

  final String text;
  final RpgTone tone;
  final double size;
  final double spacing;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: AppTheme.displayFont,
      fontWeight: weight,
      fontSize: size,
      letterSpacing: spacing,
      color: tone.foreground,
      height: 1.2,
    ),
  );
}

/// The diamond + small caps line above each page title.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.tone = RpgTone.accent});

  final String text;
  final RpgTone tone;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DiamondIcon(size: 12, filled: true, color: tone.foreground),
      const SizedBox(width: 8),
      Flexible(child: RpgLabel(text, tone: tone, size: 13, spacing: 2.6)),
    ],
  );
}

/// Big uppercase page headline, e.g. "QUEST LOG".
class RpgHeadline extends StatelessWidget {
  const RpgHeadline(this.text, {super.key, this.size = 30});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: AppTheme.displayFont,
      fontWeight: FontWeight.w700,
      fontSize: size,
      letterSpacing: 0.6,
      height: 1.1,
      color: BalanceColors.text,
    ),
  );
}

/// A bordered panel. Tone changes the border, background and accents.
class RpgPanel extends StatelessWidget {
  const RpgPanel({
    super.key,
    required this.child,
    this.tone = RpgTone.neutral,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.selected = false,
    this.dashed = false,
  });

  final Widget child;
  final RpgTone tone;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool selected;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? BalanceColors.accentBright : tone.border;
    final radius = BorderRadius.circular(8);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: radius, child: content);
    }
    final box = dashed
        ? CustomPaint(
      painter: _DashedBorderPainter(color: borderColor),
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    )
        : Material(
      color: selected ? BalanceColors.accentDim : tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor, width: selected ? 1.6 : 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    return Padding(padding: margin, child: box);
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    ).deflate(0.6);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 5, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// Panel title row: "STATUS ............ Thursday, 10 September".
class PanelHeader extends StatelessWidget {
  const PanelHeader(
      this.title, {
        super.key,
        this.trailing,
        this.tone = RpgTone.neutral,
        this.divider = false,
      });

  final String title;
  final Widget? trailing;
  final RpgTone tone;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: RpgLabel(title, tone: tone, size: 14, spacing: 2.4)),
          if (trailing != null) trailing!,
        ],
      ),
      if (divider) ...[
        const SizedBox(height: 10),
        const Divider(height: 1),
      ],
    ],
  );
}

/// Outlined square tag, e.g. "PROTECTED", "FIXED", "2H OVER".
class RpgTag extends StatelessWidget {
  const RpgTag(
      this.label, {
        super.key,
        this.tone = RpgTone.muted,
        this.icon,
        this.filled = false,
      });

  final String label;
  final RpgTone tone;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = tone == RpgTone.muted ? BalanceColors.text : tone.foreground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? tone.background : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: tone == RpgTone.muted ? BalanceColors.outline : tone.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented bar meter used for loads and capacity.
///
/// [filled] segments use [color]; [over] extra segments use the danger fill.
class SegmentMeter extends StatelessWidget {
  const SegmentMeter({
    super.key,
    required this.filled,
    this.total = 5,
    this.over = 0,
    this.color = BalanceColors.accent,
    this.height = 8,
    this.gap = 4,
    this.semanticsLabel,
  });

  /// Builds a meter from a 0–100 score.
  factory SegmentMeter.fromScore(
      int score, {
        Key? key,
        int total = 5,
        String? semanticsLabel,
      }) {
    final clamped = score < 0 ? 0 : (score > 100 ? 100 : score);
    final raw = (clamped / 100 * total).ceil();
    final segments = raw > total ? total : raw;
    final isOver = clamped >= 75;
    return SegmentMeter(
      key: key,
      total: total,
      filled: isOver ? total - 1 : segments,
      over: isOver ? 1 : 0,
      semanticsLabel: semanticsLabel,
    );
  }

  final int filled;
  final int total;
  final int over;
  final Color color;
  final double height;
  final double gap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < total; i++) {
      final segmentColor = i < filled
          ? color
          : i < filled + over
          ? BalanceColors.dangerFill
          : BalanceColors.surfaceRaised;
      children.add(
        Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : gap),
            color: segmentColor,
          ),
        ),
      );
    }
    final row = Row(children: children);
    if (semanticsLabel == null) return ExcludeSemantics(child: row);
    return Semantics(label: semanticsLabel, child: row);
  }
}

/// Section divider label: "SACRED CONTRACTS ——————".
class SectionRule extends StatelessWidget {
  const SectionRule(
      this.label, {
        super.key,
        this.subtitle,
        this.tone = RpgTone.accent,
        this.trailing,
      });

  final String label;
  final String? subtitle;
  final RpgTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          RpgLabel(label, tone: tone, size: 13, spacing: 2.4),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          style: const TextStyle(fontSize: 12, color: BalanceColors.textMuted),
        ),
      ],
    ],
  );
}

/// One selectable row with a diamond, title, subtitle and trailing widget.
/// Used for Daily Review energy choices and Sanctuary activity choices.
class DiamondOptionRow extends StatelessWidget {
  const DiamondOptionRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.dashed = false,
    this.tone = RpgTone.accent,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;
  final RpgTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: RpgPanel(
      tone: RpgTone.muted,
      selected: selected,
      dashed: dashed,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          DiamondIcon(
            size: 16,
            filled: selected,
            color: selected ? tone.foreground : BalanceColors.textFaint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 1,
                    color: dashed && !selected
                        ? BalanceColors.textMuted
                        : BalanceColors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: BalanceColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
  );
}

/// Square icon button with an outline, like the "+" on Quest Log.
class RpgSquareButton extends StatelessWidget {
  const RpgSquareButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      backgroundColor: filled ? BalanceColors.accent : BalanceColors.surface,
      foregroundColor: filled ? BalanceColors.background : BalanceColors.text,
      disabledBackgroundColor: BalanceColors.surfaceSunken,
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: filled ? BalanceColors.accent : BalanceColors.outline,
        ),
      ),
    ),
  );
}
