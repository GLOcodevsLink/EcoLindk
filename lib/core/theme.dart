import 'package:flutter/material.dart';

/// Palette de l'application EcoLindk — couleurs extraites par échantillonnage
/// exact des pixels du logo officiel (assets/images/logo.png), pour garantir
/// que le vert de l'app est rigoureusement identique à celui du logo et des
/// maquettes.
///
/// Ce fichier ne contient QUE des données de thème (couleurs, dégradés,
/// ThemeData) — aucun widget. Les widgets réutilisables vivent dans
/// lib/widgets/ (voir notamment gradient_pill_button.dart).
class AppColors {
  static const Color navy = Color(0xFF013A5E); // bleu nuit du logo (mot "Lindk", arc du bas)
  static const Color darkBackground = Color(0xFF0E1912); // fond sombre pour l'onboarding
  static const Color darkSurface = Color(0xFF17261C); // cartes/éléments sur fond sombre
  static const Color greenDark = Color(0xFF094824); // titres, texte fort
  static const Color greenDeep = Color(0xFF0B622F); // début dégradé boutons
  static const Color greenMid = Color(0xFF2F7E23); // milieu dégradé / logo
  static const Color greenBright = Color(0xFF509919); // vert vif, feuilles, accents
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF6FAF7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF6B7280);
  static const Color line = Color(0xFFE3E8E4);
  static const Color inputFill = Color(0xFFF4F7F5);

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [greenDeep, greenMid],
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenBright, greenMid],
  );
}

class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontWeight: FontWeight.w800,
    color: AppColors.greenDark,
  );
  static const TextStyle body = TextStyle(
    color: AppColors.textGray,
  );
}

final ThemeData ecoLindkTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: 'Roboto',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.greenMid,
    primary: AppColors.greenMid,
    secondary: AppColors.greenBright,
    background: AppColors.background,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.greenMid, width: 1.6),
    ),
    labelStyle: const TextStyle(
      color: AppColors.greenDark,
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
    ),
  ),
);
