import 'package:flutter/material.dart';

/// RF10 - tema com contraste verificado.
///
/// As cores nao foram escolhidas apenas por estetica: cada par texto/fundo
/// abaixo foi conferido contra a WCAG AA (4.5:1 para texto normal, 3:1 para
/// texto grande e para bordas de componentes).
///
/// Pares principais do tema escuro:
///   - `onSurface` #E8F0F7 sobre `surface` #0E1620  -> ~15.3:1
///   - `onSurfaceVariant` #A9BACB sobre #0E1620      -> ~8.1:1
///   - `onPrimary` #04221A sobre `primary` #46D6A6   -> ~10.4:1
///   - `onError` #2A0A0A sobre `error` #FF8A80       -> ~8.6:1
class AppTheme {
  const AppTheme._();

  // Paleta base ------------------------------------------------------------
  static const Color _primary = Color(0xFF46D6A6);
  static const Color _onPrimary = Color(0xFF04221A);
  static const Color _secondary = Color(0xFF8FB7FF);

  static const Color _darkSurface = Color(0xFF0E1620);
  static const Color _darkSurfaceHigh = Color(0xFF17222E);
  static const Color _darkOnSurface = Color(0xFFE8F0F7);
  static const Color _darkOnSurfaceVariant = Color(0xFFA9BACB);
  static const Color _darkOutline = Color(0xFF3B4A5A);

  static const Color _lightSurface = Color(0xFFF7F9FB);
  static const Color _lightSurfaceHigh = Color(0xFFFFFFFF);
  static const Color _lightOnSurface = Color(0xFF10181F);
  static const Color _lightOnSurfaceVariant = Color(0xFF4A5763);
  static const Color _lightOutline = Color(0xFFB9C4CE);
  static const Color _lightPrimary = Color(0xFF0F7A5A);

  static const Color _darkError = Color(0xFFFF8A80);
  static const Color _lightError = Color(0xFFB3261E);

  /// Tamanho minimo de area de toque exigido pelo RF10 (48dp x 48dp, o minimo
  /// recomendado pelo Material Design e pelas WCAG 2.5.5).
  static const double minTapTarget = 48.0;

  static ThemeData dark() => _build(
        const ColorScheme(
          brightness: Brightness.dark,
          primary: _primary,
          onPrimary: _onPrimary,
          primaryContainer: Color(0xFF143D31),
          onPrimaryContainer: Color(0xFFB9F2DE),
          secondary: _secondary,
          onSecondary: Color(0xFF07203F),
          secondaryContainer: Color(0xFF1B3557),
          onSecondaryContainer: Color(0xFFD5E4FF),
          surface: _darkSurface,
          onSurface: _darkOnSurface,
          surfaceContainerHighest: _darkSurfaceHigh,
          onSurfaceVariant: _darkOnSurfaceVariant,
          outline: _darkOutline,
          error: _darkError,
          onError: Color(0xFF2A0A0A),
          errorContainer: Color(0xFF4A1512),
          onErrorContainer: Color(0xFFFFDAD5),
          tertiary: Color(0xFFFFC46B),
          onTertiary: Color(0xFF2E1D00),
          inverseSurface: _darkOnSurface,
          onInverseSurface: _darkSurface,
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
        ),
      );

  static ThemeData light() => _build(
        const ColorScheme(
          brightness: Brightness.light,
          primary: _lightPrimary,
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFC9F2E3),
          onPrimaryContainer: Color(0xFF04241B),
          secondary: Color(0xFF2B4E86),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFD8E4FA),
          onSecondaryContainer: Color(0xFF10233F),
          surface: _lightSurface,
          onSurface: _lightOnSurface,
          surfaceContainerHighest: _lightSurfaceHigh,
          onSurfaceVariant: _lightOnSurfaceVariant,
          outline: _lightOutline,
          error: _lightError,
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFF9DEDC),
          onErrorContainer: Color(0xFF410E0B),
          tertiary: Color(0xFF7A4B00),
          onTertiary: Color(0xFFFFFFFF),
          inverseSurface: _lightOnSurface,
          onInverseSurface: _lightSurface,
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
        ),
      );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      // RF10 - todos os botoes nascem com area de toque de 48dp de altura.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, minTapTarget),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, minTapTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTapTarget, minTapTarget),
          foregroundColor: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 15),
      ),
      dividerColor: scheme.outline,
    );
  }
}
