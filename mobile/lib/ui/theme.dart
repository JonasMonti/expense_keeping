/// Identidade visual — espelha src/ui.py (paleta esmeralda, tipografia, formatação).
///
/// Suporta tema **claro** e **escuro**. A paleta [AppColors] é comutável em
/// runtime: [AppColors.apply] troca os valores conforme o brilho ativo e é
/// chamada num único sítio (`MaterialApp.builder`), antes de as páginas
/// construírem. Os widgets continuam a ler `AppColors.x` como antes.
library;

import 'package:flutter/material.dart';

/// Conjunto de cores de um tema (claro ou escuro). Imutável.
class AppPalette {
  final Color bg, surface, border, ink, muted, faint;
  final Color accent, accentInk, accentSoft, shadow;
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.border,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.shadow,
  });
}

/// Tema claro (paleta original — igual às variáveis CSS de src/ui.py).
const AppPalette kLightPalette = AppPalette(
  bg: Color(0xFFF4F6F4),
  surface: Color(0xFFFFFFFF),
  border: Color(0xFFE7EAE7),
  ink: Color(0xFF16201C),
  muted: Color(0xFF6E7872),
  faint: Color(0xFF9AA39D),
  accent: Color(0xFF0F7B66),
  accentInk: Color(0xFF0A5848),
  accentSoft: Color(0xFFE7F2EE),
  shadow: Color(0x0A14201C),
);

/// Tema escuro — mantém a identidade esmeralda, com acento mais claro para
/// contrastar sobre fundos escuros.
const AppPalette kDarkPalette = AppPalette(
  bg: Color(0xFF0F1613),
  surface: Color(0xFF19211D),
  border: Color(0xFF2A332E),
  ink: Color(0xFFE9EEEB),
  muted: Color(0xFF9AA49E),
  faint: Color(0xFF6B756F),
  accent: Color(0xFF2BA890),
  accentInk: Color(0xFF6FD3BC),
  accentSoft: Color(0xFF15302A),
  shadow: Color(0x00000000), // sem sombra no escuro (a borda já separa)
);

/// Paleta ativa — campos mutáveis lidos por todo o UI. Arranca no tema claro
/// e é trocada por [apply] consoante o brilho resolvido.
abstract class AppColors {
  static Color bg = kLightPalette.bg;
  static Color surface = kLightPalette.surface;
  static Color border = kLightPalette.border;
  static Color ink = kLightPalette.ink;
  static Color muted = kLightPalette.muted;
  static Color faint = kLightPalette.faint;
  static Color accent = kLightPalette.accent;
  static Color accentInk = kLightPalette.accentInk;
  static Color accentSoft = kLightPalette.accentSoft;
  static Color shadow = kLightPalette.shadow;

  /// Troca a paleta ativa para o brilho dado (chamado no `MaterialApp.builder`).
  static void apply(Brightness brightness) {
    final p = brightness == Brightness.dark ? kDarkPalette : kLightPalette;
    bg = p.bg;
    surface = p.surface;
    border = p.border;
    ink = p.ink;
    muted = p.muted;
    faint = p.faint;
    accent = p.accent;
    accentInk = p.accentInk;
    accentSoft = p.accentSoft;
    shadow = p.shadow;
  }
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

ThemeData buildTheme(AppPalette p, Brightness brightness) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: base.colorScheme.copyWith(
      brightness: brightness,
      primary: p.accent,
      surface: p.surface,
      onSurface: p.ink,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: kBody,
      bodyColor: p.ink,
      displayColor: p.ink,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: kBody),
    dividerColor: p.border,
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
    ),
  );
}

ThemeData buildLightTheme() => buildTheme(kLightPalette, Brightness.light);
ThemeData buildDarkTheme() => buildTheme(kDarkPalette, Brightness.dark);

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

/// Decoração do cartão (lê a paleta ativa — por isso é um getter, não const).
BoxDecoration get cardDecoration => BoxDecoration(
      color: AppColors.surface,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 30, offset: const Offset(0, 10)),
      ],
    );
