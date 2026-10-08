import 'package:flutter/material.dart';

import 'balance_colors.dart';

/// Balance's dark RPG theme.
///
/// Headings and labels use Rajdhani (squared, uppercase-friendly);
/// body text uses Barlow. Colours come from [BalanceColors].
abstract final class AppTheme {
  static const displayFont = 'Rajdhani';
  static const bodyFont = 'Barlow';

  /// Kept for compatibility with older code that referenced it.
  static const surface = BalanceColors.background;

  /// The app now has a single dark theme. `light` is kept as the name
  /// so `app.dart` does not need to change.
  static ThemeData get light => dark;

  static ThemeData get dark {
    const colors = ColorScheme(
      brightness: Brightness.dark,
      primary: BalanceColors.accent,
      onPrimary: BalanceColors.background,
      primaryContainer: BalanceColors.accentDim,
      onPrimaryContainer: BalanceColors.text,
      secondary: BalanceColors.calm,
      onSecondary: BalanceColors.background,
      secondaryContainer: BalanceColors.calmBg,
      onSecondaryContainer: BalanceColors.calm,
      tertiary: BalanceColors.warning,
      onTertiary: BalanceColors.background,
      error: BalanceColors.danger,
      onError: BalanceColors.background,
      errorContainer: BalanceColors.dangerBg,
      onErrorContainer: BalanceColors.danger,
      surface: BalanceColors.surface,
      onSurface: BalanceColors.text,
      onSurfaceVariant: BalanceColors.textMuted,
      surfaceContainerLowest: BalanceColors.background,
      surfaceContainerLow: BalanceColors.surfaceSunken,
      surfaceContainer: BalanceColors.surface,
      surfaceContainerHigh: BalanceColors.surfaceRaised,
      surfaceContainerHighest: BalanceColors.surfaceRaised,
      outline: BalanceColors.outline,
      outlineVariant: BalanceColors.outline,
      inverseSurface: BalanceColors.text,
      onInverseSurface: BalanceColors.background,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      fontFamily: bodyFont,
    );

    final text = base.textTheme.apply(
      bodyColor: BalanceColors.text,
      displayColor: BalanceColors.text,
    );

    TextStyle? display(TextStyle? style, {double spacing = 0.5}) =>
        style?.copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          letterSpacing: spacing,
        );

    final textTheme = text.copyWith(
      displayLarge: display(text.displayLarge),
      displayMedium: display(text.displayMedium),
      displaySmall: display(text.displaySmall),
      headlineLarge: display(text.headlineLarge),
      headlineMedium: display(text.headlineMedium),
      headlineSmall: display(text.headlineSmall),
      titleLarge: display(text.titleLarge, spacing: 0.8),
      titleMedium: display(text.titleMedium, spacing: 0.8),
      titleSmall: display(text.titleSmall, spacing: 1.2),
      labelLarge: display(text.labelLarge, spacing: 1.6),
      labelMedium: display(text.labelMedium, spacing: 1.6)?.copyWith(
        color: BalanceColors.textMuted,
      ),
      labelSmall: display(text.labelSmall, spacing: 1.6)?.copyWith(
        color: BalanceColors.textMuted,
      ),
      bodySmall: text.bodySmall?.copyWith(color: BalanceColors.textMuted),
    );

    final buttonText = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 16,
      letterSpacing: 1.8,
    );
    final squareShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: BalanceColors.background,
      canvasColor: BalanceColors.background,
      dividerColor: BalanceColors.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: BalanceColors.background,
        foregroundColor: BalanceColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: BalanceColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: BalanceColors.outlineStrong, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BalanceColors.outline,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BalanceColors.accent,
          foregroundColor: BalanceColors.background,
          disabledBackgroundColor: BalanceColors.accentDim,
          disabledForegroundColor: BalanceColors.textFaint,
          minimumSize: const Size.fromHeight(52),
          shape: squareShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BalanceColors.text,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: BalanceColors.outlineStrong),
          shape: squareShape,
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BalanceColors.accentBright,
          minimumSize: const Size(48, 44),
          shape: squareShape,
          textStyle: buttonText.copyWith(fontSize: 14, letterSpacing: 1.2),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: BalanceColors.text),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BalanceColors.surface,
        selectedColor: BalanceColors.accentDim,
        disabledColor: BalanceColors.surfaceSunken,
        side: const BorderSide(color: BalanceColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.8,
          color: BalanceColors.text,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          color: BalanceColors.text,
        ),
        checkmarkColor: BalanceColors.accentBright,
        iconTheme: const IconThemeData(
          color: BalanceColors.textMuted,
          size: 16,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BalanceColors.surfaceSunken,
        labelStyle: const TextStyle(color: BalanceColors.textMuted),
        hintStyle: const TextStyle(color: BalanceColors.textFaint),
        helperStyle: const TextStyle(color: BalanceColors.textMuted),
        prefixIconColor: BalanceColors.textMuted,
        suffixIconColor: BalanceColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: BalanceColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: BalanceColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: BalanceColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: BalanceColors.danger),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BalanceColors.textMuted,
        textColor: BalanceColors.text,
        subtitleTextStyle: TextStyle(
          fontFamily: bodyFont,
          color: BalanceColors.textMuted,
          fontSize: 14,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: BalanceColors.accentBright,
        collapsedIconColor: BalanceColors.textMuted,
        textColor: BalanceColors.text,
        collapsedTextColor: BalanceColors.text,
        shape: Border(),
        collapsedShape: Border(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BalanceColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: BalanceColors.outlineStrong),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BalanceColors.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: BalanceColors.outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(color: BalanceColors.outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BalanceColors.surfaceRaised,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFont,
          color: BalanceColors.text,
        ),
        actionTextColor: BalanceColors.accentBright,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: BalanceColors.outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: BalanceColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: BalanceColors.outline),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BalanceColors.background
              : BalanceColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BalanceColors.accent
              : BalanceColors.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.all(BalanceColors.outline),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(squareShape),
          side: WidgetStateProperty.all(
            const BorderSide(color: BalanceColors.outline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? BalanceColors.accentDim
                : BalanceColors.surface,
          ),
          foregroundColor: WidgetStateProperty.all(BalanceColors.text),
          textStyle: WidgetStateProperty.all(
            buttonText.copyWith(fontSize: 14, letterSpacing: 1),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BalanceColors.accent,
        linearTrackColor: BalanceColors.surfaceRaised,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: BalanceColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: BalanceColors.surface,
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(BalanceColors.surfaceRaised),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: BalanceColors.surfaceRaised,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: BalanceColors.outline),
        ),
        textStyle: const TextStyle(color: BalanceColors.text),
      ),
    );
  }
}
