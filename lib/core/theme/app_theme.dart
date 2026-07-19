import 'package:flutter/material.dart';
import 'package:koru/core/constants/koru_colors.dart';

/// Koru theme — **Material 3 Expressive · "Sage Tonal"** (dark only).
///
/// Tonal layered surfaces, extra-large rounded shapes, expressive pill nav bar,
/// a single bright sage primary + warm sand accent. See [KoruColors] for the
/// token palette. The bright primary/error means filled surfaces carry a **dark**
/// on-color — the [FilledButtonTheme] foreground is [KoruColors.onPrimary].
class AppTheme {
  const AppTheme._();

  static ThemeData dark({String? fontFamily}) {
    final base = ThemeData.dark(useMaterial3: true);
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: KoruColors.primary,
      onPrimary: KoruColors.onPrimary,
      primaryContainer: KoruColors.primaryContainer,
      onPrimaryContainer: KoruColors.onPrimaryContainer,
      secondary: KoruColors.secondary,
      onSecondary: KoruColors.onSecondary,
      secondaryContainer: KoruColors.secondaryContainer,
      onSecondaryContainer: KoruColors.onSecondaryContainer,
      tertiary: KoruColors.tertiary,
      onTertiary: KoruColors.onTertiary,
      tertiaryContainer: KoruColors.tertiaryContainer,
      onTertiaryContainer: KoruColors.onTertiaryContainer,
      surface: KoruColors.surface,
      onSurface: KoruColors.textPrimary,
      onSurfaceVariant: KoruColors.textSecondary,
      surfaceContainerLowest: KoruColors.backgroundBase,
      surfaceContainerLow: KoruColors.surface,
      surfaceContainer: KoruColors.surfaceContainer,
      surfaceContainerHigh: KoruColors.surfaceElevated,
      surfaceContainerHighest: KoruColors.surfaceElevated,
      error: KoruColors.danger,
      onError: KoruColors.onDanger,
      errorContainer: KoruColors.dangerContainer,
      onErrorContainer: KoruColors.onDangerContainer,
      outline: KoruColors.outline,
      outlineVariant: KoruColors.surfaceElevated,
      surfaceTint: Colors.transparent,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: KoruColors.backgroundBase,
      canvasColor: KoruColors.backgroundBase,
      textTheme: base.textTheme.apply(
        bodyColor: KoruColors.textPrimary,
        displayColor: KoruColors.textPrimary,
        fontFamily: fontFamily,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: KoruColors.backgroundBase,
        foregroundColor: KoruColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: KoruColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontFamily: fontFamily,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KoruColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: KoruColors.primary,
        // Solid sage pill hugging the active icon (M3 Expressive stadium).
        indicatorShape: const StadiumBorder(),
        height: 70,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? KoruColors.onPrimary
                : KoruColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontFamily: fontFamily,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? KoruColors.primary
                : KoruColors.textSecondary,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: KoruColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: KoruColors.textSecondary,
        textColor: KoruColors.textPrimary,
      ),
      dividerColor: KoruColors.outline,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KoruColors.onPrimary
              : KoruColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KoruColors.primary
              : KoruColors.surfaceElevated,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : KoruColors.outline,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KoruColors.primary,
          foregroundColor: KoruColors.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KoruColors.textPrimary,
          side: const BorderSide(color: KoruColors.outline, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KoruColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        KoruSemanticColors(
          danger: KoruColors.danger,
          success: KoruColors.success,
          textSecondary: KoruColors.textSecondary,
        ),
      ],
    );
  }
}

class KoruSemanticColors extends ThemeExtension<KoruSemanticColors> {
  const KoruSemanticColors({
    required this.danger,
    required this.success,
    required this.textSecondary,
  });

  final Color danger;
  final Color success;
  final Color textSecondary;

  @override
  KoruSemanticColors copyWith({Color? danger, Color? success, Color? textSecondary}) {
    return KoruSemanticColors(
      danger: danger ?? this.danger,
      success: success ?? this.success,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  KoruSemanticColors lerp(ThemeExtension<KoruSemanticColors>? other, double t) {
    if (other is! KoruSemanticColors) return this;
    return KoruSemanticColors(
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}
