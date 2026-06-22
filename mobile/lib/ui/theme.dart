/// Identidade visual — espelha src/ui.py (paleta esmeralda, tipografia, formatação).
library;

import 'package:flutter/material.dart';

/// Paleta (igual às variáveis CSS de src/ui.py).
abstract class AppColors {
  static const bg = Color(0xFFF4F6F4);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7EAE7);
  static const ink = Color(0xFF16201C);
  static const muted = Color(0xFF6E7872);
  static const faint = Color(0xFF9AA39D);
  static const accent = Color(0xFF0F7B66);
  static const accentInk = Color(0xFF0A5848);
  static const accentSoft = Color(0xFFE7F2EE);
}

/// Famílias tipográficas (declaradas no pubspec).
const String kDisplay = 'Space Grotesk'; // números e títulos
const String kBody = 'Inter'; // corpo

/// Converte "#RRGGBB" (com canal alfa opcional "22") numa Color.
Color hexColor(String hex, {int alpha = 0xFF}) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.parse(h, radix: 16);
  return Color(v).withAlpha(alpha);
}

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: kBody,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: kBody),
    dividerColor: AppColors.border,
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
  );
}

/// Estilos reutilizáveis para texto.
TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w600}) =>
    TextStyle(
      fontFamily: kDisplay,
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
      letterSpacing: -0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

const BoxDecoration cardDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.all(Radius.circular(18)),
  border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
  boxShadow: [
    BoxShadow(color: Color(0x0A14201C), blurRadius: 30, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0814201C), blurRadius: 2, offset: Offset(0, 1)),
  ],
);
