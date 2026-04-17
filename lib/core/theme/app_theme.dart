import 'package:flutter/material.dart';
import 'package:koru/core/constants/koru_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData dark({String? fontFamily}) {
    final base = ThemeData.dark(useMaterial3: true);
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: KoruColors.primary,
      onPrimary: KoruColors.textPrimary,
      primaryContainer: KoruColors.primaryContainer,
      onPrimaryContainer: KoruColors.textPrimary,
      secondary: KoruColors.secondary,
      onSecondary: KoruColors.textPrimary,
      secondaryContainer: KoruColors.secondaryContainer,
      onSecondaryContainer: KoruColors.textPrimary,
      surface: KoruColors.surface,
      onSurface: KoruColors.textPrimary,
      surfaceContainerHighest: KoruColors.surfaceElevated,
      error: KoruColors.danger,
      onError: KoruColors.textPrimary,
      errorContainer: KoruColors.dangerContainer,
      onErrorContainer: KoruColors.textPrimary,
      outline: KoruColors.textSecondary,
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
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: KoruColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KoruColors.surface,
        indicatorColor: KoruColors.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? KoruColors.primary
                : KoruColors.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
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
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: KoruColors.textSecondary,
        textColor: KoruColors.textPrimary,
      ),
      dividerColor: const Color(0x1FE8E6E1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KoruColors.primary
              : KoruColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KoruColors.primary.withValues(alpha: 0.4)
              : KoruColors.surface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KoruColors.primary,
          foregroundColor: KoruColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KoruColors.textPrimary,
          side: const BorderSide(color: KoruColors.textSecondary, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: KoruColors.primary),
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
