import 'package:flutter/material.dart';

/// Every colour token Balance uses, in one place, for both looks.
///
/// [BalancePalette.dark] is the original RPG look and stays the default.
/// [BalancePalette.light] keeps the same brand colours (periwinkle accent,
/// calm green, warning amber, danger red, ornament gold) but darkens them
/// where needed so text still meets WCAG AA (4.5:1) on light surfaces.
///
/// The palette is registered as a [ThemeExtension], so new code can read it
/// with `context.palette`. Older code reads the active palette through
/// `BalanceColors`, which is kept in step by `ThemeController`.
@immutable
class BalancePalette extends ThemeExtension<BalancePalette> {
  const BalancePalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.outlineStrong,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentBright,
    required this.accentDim,
    required this.danger,
    required this.dangerFill,
    required this.dangerBg,
    required this.dangerBorder,
    required this.warning,
    required this.warningBg,
    required this.warningBorder,
    required this.calm,
    required this.calmFill,
    required this.calmBg,
    required this.calmBorder,
    required this.gold,
    required this.goldSurface,
    required this.goldGlow,
    required this.goldDialog,
    required this.shadow,
  });

  final Brightness brightness;

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;

  // Lines
  /// Strong outline used on primary panels.
  final Color outlineStrong;

  /// Dim outline for inner rows, tags and inputs.
  final Color outline;

  // Text
  final Color text;
  final Color textMuted;

  /// Lightest grey that still meets WCAG AA (4.5:1) for small text.
  final Color textFaint;

  // Accent (periwinkle): buttons, meters, selected states.
  final Color accent;

  /// Accent used for text, links and selected icons.
  final Color accentBright;

  /// Soft accent fill for selected rows and the nav indicator.
  final Color accentDim;

  // Danger: over capacity, errors.
  final Color danger;
  final Color dangerFill;
  final Color dangerBg;
  final Color dangerBorder;

  // Warning: "building up".
  final Color warning;
  final Color warningBg;
  final Color warningBorder;

  // Calm green: protected time, Sanctuary, success.
  final Color calm;
  final Color calmFill;
  final Color calmBg;
  final Color calmBorder;

  // Ornament gold: headline flourishes, panel corners and earned badges.
  final Color gold;

  /// Background of an earned badge tile.
  final Color goldSurface;

  /// Inner glow of an earned badge emblem.
  final Color goldGlow;

  /// Background of the "Achievement unlocked" dialog.
  final Color goldDialog;

  /// Shadow colour for raised panels (transparent in dark mode).
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  /// The original dark RPG look (unchanged values).
  static const dark = BalancePalette(
    brightness: Brightness.dark,
    background: Color(0xFF0E1014),
    surface: Color(0xFF151820),
    surfaceRaised: Color(0xFF1B1F29),
    surfaceSunken: Color(0xFF11141A),
    outlineStrong: Color(0xFFC9CCE0),
    outline: Color(0xFF343A4A),
    text: Color(0xFFEDEEF4),
    textMuted: Color(0xFF9CA2B6),
    textFaint: Color(0xFF7C8297),
    accent: Color(0xFF7B83D4),
    accentBright: Color(0xFFA3A9EE),
    accentDim: Color(0xFF2A2E4A),
    danger: Color(0xFFE47F72),
    dangerFill: Color(0xFF9C4E4B),
    dangerBg: Color(0xFF261618),
    dangerBorder: Color(0xFFD07A72),
    warning: Color(0xFFE59A57),
    warningBg: Color(0xFF2A1D13),
    warningBorder: Color(0xFF8A5A35),
    calm: Color(0xFF80D3A2),
    calmFill: Color(0xFF3F8A60),
    calmBg: Color(0xFF12211A),
    calmBorder: Color(0xFF4E9A70),
    gold: Color(0xFFE8C46A),
    goldSurface: Color(0xFF1E1C17),
    goldGlow: Color(0xFF3A3220),
    goldDialog: Color(0xFF16140F),
    shadow: Color(0x00000000),
  );

  /// Light look: warm parchment pages, cream cards and dark ink-brown text,
  /// like an RPG quest scroll. Softer on the eyes than pure white; every
  /// text colour keeps at least 5:1 on the surfaces it sits on.
  static const light = BalancePalette(
    brightness: Brightness.light,
    background: Color(0xFFF2E8D0),
    surface: Color(0xFFFAF4E4),
    surfaceRaised: Color(0xFFE9DDC0),
    surfaceSunken: Color(0xFFEEE3C8),
    outlineStrong: Color(0xFF9C8760),
    outline: Color(0xFFD6C59E),
    text: Color(0xFF2B2114), // 13.0:1 on background
    textMuted: Color(0xFF574629), // 6.7:1 on raised
    textFaint: Color(0xFF5E4C2F), // 6.0:1 on selected rows
    accent: Color(0xFF574B9E), // 7.2:1 with white text on it
    accentBright: Color(0xFF483D8C), // 6.6:1 as text on selected rows
    accentDim: Color(0xFFE2D9EC),
    danger: Color(0xFF9E3127), // 5.5:1 on its background
    dangerFill: Color(0xFFC9604F),
    dangerBg: Color(0xFFF5DDD2),
    dangerBorder: Color(0xFFC98676),
    warning: Color(0xFF7E4A0C), // 5.9:1
    warningBg: Color(0xFFF6E4C8),
    warningBorder: Color(0xFFC99A5E),
    calm: Color(0xFF275F3D), // 6.0:1
    calmFill: Color(0xFF4E9369),
    calmBg: Color(0xFFDEEAD3),
    calmBorder: Color(0xFF79A786),
    gold: Color(0xFF735610), // 5.1:1 even on raised parchment
    goldSurface: Color(0xFFF6EBCD),
    goldGlow: Color(0xFFEBD49A),
    goldDialog: Color(0xFFFBF3DF),
    shadow: Color(0x1F3A2A10),
  );

  static BalancePalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  BalancePalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? outlineStrong,
    Color? outline,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? accent,
    Color? accentBright,
    Color? accentDim,
    Color? danger,
    Color? dangerFill,
    Color? dangerBg,
    Color? dangerBorder,
    Color? warning,
    Color? warningBg,
    Color? warningBorder,
    Color? calm,
    Color? calmFill,
    Color? calmBg,
    Color? calmBorder,
    Color? gold,
    Color? goldSurface,
    Color? goldGlow,
    Color? goldDialog,
    Color? shadow,
  }) => BalancePalette(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceSunken: surfaceSunken ?? this.surfaceSunken,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    outline: outline ?? this.outline,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    textFaint: textFaint ?? this.textFaint,
    accent: accent ?? this.accent,
    accentBright: accentBright ?? this.accentBright,
    accentDim: accentDim ?? this.accentDim,
    danger: danger ?? this.danger,
    dangerFill: dangerFill ?? this.dangerFill,
    dangerBg: dangerBg ?? this.dangerBg,
    dangerBorder: dangerBorder ?? this.dangerBorder,
    warning: warning ?? this.warning,
    warningBg: warningBg ?? this.warningBg,
    warningBorder: warningBorder ?? this.warningBorder,
    calm: calm ?? this.calm,
    calmFill: calmFill ?? this.calmFill,
    calmBg: calmBg ?? this.calmBg,
    calmBorder: calmBorder ?? this.calmBorder,
    gold: gold ?? this.gold,
    goldSurface: goldSurface ?? this.goldSurface,
    goldGlow: goldGlow ?? this.goldGlow,
    goldDialog: goldDialog ?? this.goldDialog,
    shadow: shadow ?? this.shadow,
  );

  @override
  BalancePalette lerp(covariant BalancePalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BalancePalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      outlineStrong: c(outlineStrong, other.outlineStrong),
      outline: c(outline, other.outline),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      textFaint: c(textFaint, other.textFaint),
      accent: c(accent, other.accent),
      accentBright: c(accentBright, other.accentBright),
      accentDim: c(accentDim, other.accentDim),
      danger: c(danger, other.danger),
      dangerFill: c(dangerFill, other.dangerFill),
      dangerBg: c(dangerBg, other.dangerBg),
      dangerBorder: c(dangerBorder, other.dangerBorder),
      warning: c(warning, other.warning),
      warningBg: c(warningBg, other.warningBg),
      warningBorder: c(warningBorder, other.warningBorder),
      calm: c(calm, other.calm),
      calmFill: c(calmFill, other.calmFill),
      calmBg: c(calmBg, other.calmBg),
      calmBorder: c(calmBorder, other.calmBorder),
      gold: c(gold, other.gold),
      goldSurface: c(goldSurface, other.goldSurface),
      goldGlow: c(goldGlow, other.goldGlow),
      goldDialog: c(goldDialog, other.goldDialog),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// `context.palette` returns the palette of the current theme.
extension BalancePaletteContext on BuildContext {
  BalancePalette get palette =>
      Theme.of(this).extension<BalancePalette>() ?? BalancePalette.dark;
}
