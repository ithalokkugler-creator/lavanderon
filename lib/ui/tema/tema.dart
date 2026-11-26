import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta do Lavanderon. Azul profundo da marca + cores de status fixas
/// (seção 18.2 do plano). Status nunca aparece só por cor: sempre cor + ícone + texto.
abstract final class Cores {
  static const marca = Color(0xFF0D47A1);
  static const marcaClara = Color(0xFF1E88E5);
  static const agua = Color(0xFF00ACC1);
  static const fundo = Color(0xFFF4F7FB);
  static const superficie = Colors.white;
  static const borda = Color(0xFFE3E9F2);
  static const texto = Color(0xFF14213D);
  static const textoSuave = Color(0xFF5B6B85);
  static const textoFraco = Color(0xFF8C9AB0);

  // Status
  static const livre = Color(0xFF2E7D32);
  static const reservada = Color(0xFFB26A00);
  static const emUso = Color(0xFF1E6FD9);
  static const pronta = Color(0xFF00838F);
  static const semRegistro = Color(0xFF6A1B9A);
  static const problema = Color(0xFFC62828);
  static const indisponivel = Color(0xFF616161);

  static Color fundoDe(Color c) => Color.alphaBlend(c.withValues(alpha: 0.10), Colors.white);
}

abstract final class Medidas {
  static const raio = 20.0;
  static const raioPequeno = 12.0;
  static const espaco = 16.0;
  static const larguraMaxConteudo = 1180.0;
  static const breakTablet = 720.0;
  static const breakDesktop = 1100.0;
}

ThemeData temaLavanderon() {
  final base = ColorScheme.fromSeed(
    seedColor: Cores.marca,
    primary: Cores.marca,
    secondary: Cores.agua,
    surface: Cores.superficie,
    error: Cores.problema,
  );
  final texto = GoogleFonts.nunitoTextTheme().apply(
    bodyColor: Cores.texto,
    displayColor: Cores.texto,
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.raioPequeno));

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: Cores.fundo,
    textTheme: texto.copyWith(
      headlineLarge: texto.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: texto.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      headlineSmall: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: texto.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: texto.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: texto.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      bodyMedium: texto.bodyMedium?.copyWith(height: 1.4),
      bodyLarge: texto.bodyLarge?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Cores.fundo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Cores.texto),
      iconTheme: const IconThemeData(color: Cores.texto),
    ),
    cardTheme: CardThemeData(
      color: Cores.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Medidas.raio),
        side: const BorderSide(color: Cores.borda),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: forma,
        textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: forma,
        side: const BorderSide(color: Cores.borda, width: 1.5),
        foregroundColor: Cores.texto,
        textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: forma,
        textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Medidas.raioPequeno), borderSide: const BorderSide(color: Cores.borda)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Medidas.raioPequeno), borderSide: const BorderSide(color: Cores.borda, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Medidas.raioPequeno), borderSide: const BorderSide(color: Cores.marca, width: 2)),
      labelStyle: const TextStyle(color: Cores.textoSuave),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Cores.marca,
      side: const BorderSide(color: Cores.borda),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Cores.texto),
      secondaryLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Cores.fundoDe(Cores.marca),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? Cores.marca : Cores.textoSuave,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Cores.marca : Cores.textoSuave,
          )),
    ),
    dividerTheme: const DividerThemeData(color: Cores.borda, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cores.texto,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}
