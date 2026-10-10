import 'package:flutter/material.dart';

/// Colour tokens for Balance's dark RPG look.
///
/// Use these instead of hard-coded colours so every screen stays consistent.
abstract final class BalanceColors {
  // Surfaces
  static const background = Color(0xFF0E1014);
  static const surface = Color(0xFF151820);
  static const surfaceRaised = Color(0xFF1B1F29);
  static const surfaceSunken = Color(0xFF11141A);

  // Lines
  /// Bright outline used on primary panels (the white-ish card borders).
  static const outlineStrong = Color(0xFFC9CCE0);

  /// Dim outline for inner rows, tags and inputs.
  static const outline = Color(0xFF343A4A);

  // Text
  static const text = Color(0xFFEDEEF4);
  static const textMuted = Color(0xFF9CA2B6);
  // Lightest grey that still meets WCAG AA (4.5:1) for small text on surface.
  static const textFaint = Color(0xFF7C8297);

  // Accent (periwinkle) — buttons, meters, selected states
  static const accent = Color(0xFF7B83D4);
  static const accentBright = Color(0xFFA3A9EE);
  static const accentDim = Color(0xFF2A2E4A);

  // Danger — over capacity
  static const danger = Color(0xFFE47F72);
  static const dangerFill = Color(0xFF9C4E4B);
  static const dangerBg = Color(0xFF261618);
  static const dangerBorder = Color(0xFFD07A72);

  // Warning — "building up"
  static const warning = Color(0xFFE59A57);
  static const warningBg = Color(0xFF2A1D13);
  static const warningBorder = Color(0xFF8A5A35);

  // Calm green — protected time, Sanctuary
  static const calm = Color(0xFF80D3A2);
  static const calmFill = Color(0xFF3F8A60);
  static const calmBg = Color(0xFF12211A);
  static const calmBorder = Color(0xFF4E9A70);

  // Ornament gold: headline flourishes, panel corners and earned badges.
  static const gold = Color(0xFFE8C46A);
}
