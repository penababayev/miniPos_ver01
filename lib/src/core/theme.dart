import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final _radius = BorderRadius.circular(16);

  static ThemeData light = _baseTheme(Brightness.light);
  static ThemeData dark = _baseTheme(Brightness.dark);

  static ThemeData _baseTheme(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF10B981), // emerald
      brightness: b,
    );

    final text = GoogleFonts.interTextTheme(
      b == Brightness.light
          ? Typography.blackMountainView
          : Typography.whiteMountainView,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: b == Brightness.light
          ? const Color(0xFFF7F7F8)
          : const Color(0xFF0E1113),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: _radius),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: b == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 1,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelTextStyle: WidgetStatePropertyAll(
            text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
