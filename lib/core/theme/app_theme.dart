import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'balance_colors.dart';
import 'balance_palette.dart';

/// Balance's RPG themes: the original dark look (default) and a light look.
///
/// Headings and labels use Rajdhani (squared, uppercase-friendly);
/// body text uses Barlow. Both themes are built from the same code by
/// [fromPalette], so the only difference between them is the colour tokens
/// in [BalancePalette].
abstract final class AppTheme {
  static const displayFont = 'Rajdhani';
  static const bodyFont = 'Barlow';

  /// Kept for compatibility with older code that referenced it.
  static Color get surface => BalanceColors.background;

  static ThemeData get dark => fromPalette(BalancePalette.dark);

  static ThemeData get light => fromPalette(BalancePalette.light);

  /// Status and navigation bar colours that match [p].
  static SystemUiOverlayStyle overlayStyle(BalancePalette p) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: p.surfaceSunken,
        systemNavigationBarDividerColor: p.outline,
        systemNavigationBarIconBrightness: p.isDark
            ? Brightness.light
            : Brightness.dark,
      );

  static ThemeData fromPalette(BalancePalette p) {
    // Text and icons placed on the accent colour (filled buttons).
    final onAccent = p.isDark ? p.background : Colors.white;
    final colors = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: onAccent,
      primaryContainer: p.accentDim,
      onPrimaryContainer: p.text,
      secondary: p.calm,
      onSecondary: onAccent,
      secondaryContainer: p.calmBg,
      onSecondaryContainer: p.calm,
      tertiary: p.warning,
      onTertiary: onAccent,
      error: p.danger,
      onError: onAccent,
      errorContainer: p.dangerBg,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surfaceSunken,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceRaised,
      surfaceContainerHighest: p.surfaceRaised,
      outline: p.outline,
      outlineVariant: p.outline,
      inverseSurface: p.text,
      onInverseSurface: p.background,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colors,
      fontFamily: bodyFont,
      extensions: [p],
    );

    final text = base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
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
      labelMedium: display(
        text.labelMedium,
        spacing: 1.6,
      )?.copyWith(color: p.textMuted),
      labelSmall: display(
        text.labelSmall,
        spacing: 1.6,
      )?.copyWith(color: p.textMuted),
      bodySmall: text.bodySmall?.copyWith(color: p.textMuted),
    );

    final buttonText = TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      fontSize: 16,
      letterSpacing: 1.8,
    );
    // Cut (chamfered) corners, like the frames of a game menu.
    final squareShape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(7),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: overlayStyle(p),
      ),
      shadowColor: p.shadow,
      cardTheme: CardThemeData(
        // A soft shadow lifts white cards off the light page; dark mode
        // stays flat (its shadow colour is transparent).
        elevation: p.isDark ? 0 : 1,
        shadowColor: p.shadow,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: p.outlineStrong,
            width: 1.2,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.outline,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: p.accentDim,
          disabledForegroundColor: p.textFaint,
          minimumSize: const Size.fromHeight(52),
          shape: squareShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: p.outlineStrong),
          shape: squareShape,
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentBright,
          minimumSize: const Size(48, 44),
          shape: squareShape,
          textStyle: buttonText.copyWith(fontSize: 14, letterSpacing: 1.2),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.text),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accentDim,
        disabledColor: p.surfaceSunken,
        side: BorderSide(color: p.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.8,
          color: p.text,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
        checkmarkColor: p.accentBright,
        iconTheme: IconThemeData(
          color: p.textMuted,
          size: 16,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceSunken,
        labelStyle: TextStyle(color: p.textMuted),
        hintStyle: TextStyle(color: p.textFaint),
        helperStyle: TextStyle(color: p.textMuted),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.danger),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        subtitleTextStyle: TextStyle(
          fontFamily: bodyFont,
          color: p.textMuted,
          fontSize: 14,
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.accentBright,
        collapsedIconColor: p.textMuted,
        textColor: p.text,
        collapsedTextColor: p.text,
        shape: Border(),
        collapsedShape: Border(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: p.gold.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: p.gold.withValues(alpha: 0.6),
        shape: BeveledRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          side: BorderSide(color: p.gold.withValues(alpha: 0.45)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceRaised,
        contentTextStyle: TextStyle(
          fontFamily: bodyFont,
          color: p.text,
        ),
        actionTextColor: p.accentBright,
        behavior: SnackBarBehavior.floating,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: p.outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: p.outline),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? onAccent
              : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : p.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.outline),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(squareShape),
          side: WidgetStateProperty.all(
            BorderSide(color: p.outline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.accentDim
                : p.surface,
          ),
          foregroundColor: WidgetStateProperty.all(p.text),
          textStyle: WidgetStateProperty.all(
            buttonText.copyWith(fontSize: 14, letterSpacing: 1),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceRaised,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceRaised),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.outline),
        ),
        textStyle: TextStyle(color: p.text),
      ),
    );
  }
}
