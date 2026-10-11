import 'package:flutter/material.dart';

import 'balance_palette.dart';

/// Colour tokens for Balance, for whichever look (dark or light) is active.
///
/// Use these instead of hard-coded colours so every screen stays consistent.
/// The values live in [BalancePalette]; `ThemeController` switches
/// [active] and rebuilds the app, so these getters always return the colour
/// for the current look. Because they can change, they cannot be used inside
/// `const` expressions.
abstract final class BalanceColors {
  static BalancePalette _active = BalancePalette.dark;

  /// The palette every getter below reads from.
  static BalancePalette get active => _active;

  /// Called by `ThemeController` only.
  static void use(BalancePalette palette) => _active = palette;

  static bool get isDark => _active.isDark;

  // Surfaces
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get surfaceRaised => _active.surfaceRaised;
  static Color get surfaceSunken => _active.surfaceSunken;

  // Lines
  /// Strong outline used on primary panels.
  static Color get outlineStrong => _active.outlineStrong;

  /// Dim outline for inner rows, tags and inputs.
  static Color get outline => _active.outline;

  // Text
  static Color get text => _active.text;
  static Color get textMuted => _active.textMuted;

  /// Lightest grey that still meets WCAG AA (4.5:1) for small text.
  static Color get textFaint => _active.textFaint;

  // Accent (periwinkle): buttons, meters, selected states
  static Color get accent => _active.accent;
  static Color get accentBright => _active.accentBright;
  static Color get accentDim => _active.accentDim;

  // Danger: over capacity
  static Color get danger => _active.danger;
  static Color get dangerFill => _active.dangerFill;
  static Color get dangerBg => _active.dangerBg;
  static Color get dangerBorder => _active.dangerBorder;

  // Warning: "building up"
  static Color get warning => _active.warning;
  static Color get warningBg => _active.warningBg;
  static Color get warningBorder => _active.warningBorder;

  // Calm green: protected time, Sanctuary
  static Color get calm => _active.calm;
  static Color get calmFill => _active.calmFill;
  static Color get calmBg => _active.calmBg;
  static Color get calmBorder => _active.calmBorder;

  // Ornament gold: headline flourishes, panel corners and earned badges.
  static Color get gold => _active.gold;
  static Color get goldSurface => _active.goldSurface;
  static Color get goldGlow => _active.goldGlow;
  static Color get goldDialog => _active.goldDialog;

  /// Shadow for raised panels (transparent in dark mode).
  static Color get shadow => _active.shadow;
}
