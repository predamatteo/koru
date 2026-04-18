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
        backgroundColor: KoruColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: KoruColors.primary.withValues(alpha: 0.22),
        // Cerchio con raggio maggiore del default Material 3 NavigationIndicator
        // (che è 32x56). Usiamo una shape custom che "infla" il rect prima di
        // disegnare l'oval, così il fill cresce oltre il bounds assegnato.
        indicatorShape: const _InflatedCircleBorder(inflation: 8),
        height: 64,
        elevation: 0,
        // Icon-only floating nav bar, cerchio tondo come indicator.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
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

/// OutlinedBorder a forma di cerchio "inflato" — il path viene disegnato
/// espandendo il rect di [inflation] px su ogni lato, così il pill indicator
/// del NavigationBar cresce oltre il default 32x56 senza dover aumentare
/// l'altezza della nav bar.
class _InflatedCircleBorder extends OutlinedBorder {
  const _InflatedCircleBorder({this.inflation = 0, super.side = BorderSide.none});

  final double inflation;

  Rect _inflated(Rect rect) => rect.inflate(inflation);

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      _InflatedCircleBorder(inflation: inflation, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  ShapeBorder scale(double t) =>
      _InflatedCircleBorder(inflation: inflation * t, side: side.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addOval(_inflated(rect).deflate(side.strokeInset));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addOval(_inflated(rect));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.solid) {
      canvas.drawPath(getOuterPath(rect), side.toPaint());
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _InflatedCircleBorder &&
          other.side == side &&
          other.inflation == inflation);

  @override
  int get hashCode => Object.hash(side, inflation);
}
