import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/theme_provider.dart';

class _Palette {
  const _Palette({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.slate700,
    required this.slate500,
    required this.slate400,
    required this.slate200,
    required this.slate100,
    required this.slate50,
    required this.accent,
    required this.success,
    required this.successLight,
    required this.warning,
    required this.warningLight,
    required this.danger,
    required this.dangerLight,
    required this.onPrimary,
    required this.onSecondary,
    required this.onError,
    required this.cardBg,
    required this.scaffoldBg,
    required this.shadow,
  });

  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondary;
  final Color slate700;
  final Color slate500;
  final Color slate400;
  final Color slate200;
  final Color slate100;
  final Color slate50;
  final Color accent;
  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color danger;
  final Color dangerLight;
  final Color onPrimary;
  final Color onSecondary;
  final Color onError;
  final Color cardBg;
  final Color scaffoldBg;
  final Color shadow;
}

class AppTheme {
  // Light Palette
  static const _Palette _light = _Palette(
    primary: Color(0xFF0E7490), // Deep Cyan / Medical Teal
    primaryLight: Color(0xFFE0F2FE), // Soft sky tint
    primaryDark: Color(0xFF155E75),
    secondary: Color(0xFF0F172A), // Slate 900
    slate700: Color(0xFF334155),
    slate500: Color(0xFF64748B),
    slate400: Color(0xFF94A3B8),
    slate200: Color(0xFFE2E8F0),
    slate100: Color(0xFFF1F5F9),
    slate50: Color(0xFFF8FAFC),
    accent: Color(0xFF2563EB), // Royal Blue
    success: Color(0xFF059669), // Emerald
    successLight: Color(0xFFD1FAE5),
    warning: Color(0xFFD97706), // Amber
    warningLight: Color(0xFFFEF3C7),
    danger: Color(0xFFDC2626), // Red
    dangerLight: Color(0xFFFEE2E2),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onError: Colors.white,
    cardBg: Colors.white,
    scaffoldBg: Color(0xFFF8FAFC),
    shadow: Color(0x0F000000),
  );

  // Dark Palette
  static const _Palette _dark = _Palette(
    primary: Color(0xFF22D3EE), // Bright cyan for contrast on dark bg
    primaryLight: Color(0xFF164E63), // Dark teal selection tint
    primaryDark: Color(0xFF0E7490),
    secondary: Color(0xFFF1F5F9), // Slate 100 as primary text
    slate700: Color(0xFFCBD5E1), // Slate 300 body text
    slate500: Color(0xFF94A3B8), // Slate 400 muted text
    slate400: Color(0xFF64748B), // Slate 500 hints / icons
    slate200: Color(0xFF334155), // Slate 700 borders
    slate100: Color(0xFF16202F), // Subtle hover / fill
    slate50: Color(0xFF1E293B), // Slate 800 sections
    accent: Color(0xFF60A5FA), // Blue 400
    success: Color(0xFF34D399), // Emerald 400
    successLight: Color(0xFF064E3B), // Emerald 950
    warning: Color(0xFFFBBF24), // Amber 400
    warningLight: Color(0xFF451A03), // Amber 950
    danger: Color(0xFFF87171), // Red 400
    dangerLight: Color(0xFF450A0A), // Red 950
    onPrimary: Color(0xFF083344), // Dark text on bright brand surfaces
    onSecondary: Color(0xFF0F172A),
    onError: Color(0xFF450A0A),
    cardBg: Color(0xFF1E293B), // Slate 800
    scaffoldBg: Color(0xFF0F172A), // Slate 900
    shadow: Color(0x1A000000),
  );

  // Theme-aware getters (fall back to light when provider is not ready)
  static bool get _isDark => ThemeProvider.instance?.isDark ?? false;
  static _Palette get _p => _isDark ? _dark : _light;

  static Color get primary => _p.primary;
  static Color get primaryLight => _p.primaryLight;
  static Color get primaryDark => _p.primaryDark;
  static Color get secondary => _p.secondary;
  static Color get slate700 => _p.slate700;
  static Color get slate500 => _p.slate500;
  static Color get slate400 => _p.slate400;
  static Color get slate200 => _p.slate200;
  static Color get slate100 => _p.slate100;
  static Color get slate50 => _p.slate50;
  static Color get accent => _p.accent;
  static Color get indigo => _isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);
  static Color get indigoLight => _isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
  static Color get purple => _isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
  static Color get purpleLight => _isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF);
  static Color get success => _p.success;
  static Color get successLight => _p.successLight;
  static Color get warning => _p.warning;
  static Color get warningLight => _p.warningLight;
  static Color get danger => _p.danger;
  static Color get dangerLight => _p.dangerLight;
  static Color get onPrimary => _p.onPrimary;
  static Color get onSecondary => _p.onSecondary;
  static Color get onError => _p.onError;
  static Color get cardBg => _p.cardBg;
  static Color get scaffoldBg => _p.scaffoldBg;
  static Color get shadow => _p.shadow;

  static ThemeData get lightTheme => _buildTheme(_light);
  static ThemeData get darkTheme => _buildTheme(_dark);

  static ThemeData _buildTheme(_Palette p) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: p == _dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: p.scaffoldBg,
      canvasColor: p.cardBg,
      colorScheme: ColorScheme(
        brightness: p == _dark ? Brightness.dark : Brightness.light,
        primary: p.primary,
        secondary: p.secondary,
        surface: p.cardBg,
        error: p.danger,
        onPrimary: p.onPrimary,
        onSecondary: p.onSecondary,
        onSurface: p.secondary,
        onError: p.onError,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: p.secondary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: p.secondary,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.secondary,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.secondary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.slate700,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: p.secondary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: p.slate700,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: p.secondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.slate200, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: p.slate500, fontSize: 13),
        hintStyle: GoogleFonts.plusJakartaSans(color: p.slate400, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.slate200, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.danger, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.slate700,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: p.slate200, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.slate200,
        thickness: 1,
        space: 1,
      ),
    );
  }
}