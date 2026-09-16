import 'package:flutter/material.dart';

/// Mode de thème (clair/sombre) actuellement sélectionné, observable dans
/// toute l'application. Changer cette valeur (ex: appThemeMode.value =
/// ThemeMode.dark) met à jour tous les écrans qui écoutent via
/// ValueListenableBuilder, exactement comme [appLanguage] pour la langue.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

/// Petit raccourci pour savoir si le thème actif est sombre, à utiliser dans
/// les widgets déjà reconstruits par un ValueListenableBuilder<ThemeMode>
/// (voir [appThemeMode]).
bool get isDarkMode => appThemeMode.value == ThemeMode.dark;

/// Palette de l'application EcoLindk — couleurs extraites par échantillonnage
/// exact des pixels du logo officiel (assets/images/logo.png), pour garantir
/// que le vert de l'app est rigoureusement identique à celui du logo et des
/// maquettes.
///
/// Ce fichier ne contient QUE des données de thème (couleurs, dégradés,
/// ThemeData) — aucun widget. Les widgets réutilisables vivent dans
/// lib/widgets/ (voir notamment gradient_pill_button.dart).
///
/// Les couleurs de marque (verts, bleu nuit) restent identiques en clair et
/// en sombre. Les couleurs de surface/texte (fond, cartes, gris, bordures,
/// titres) s'adaptent au thème actif via [isDarkMode] : elles ne sont donc
/// plus `const`, ce qui est voulu — elles doivent être relues à chaque
/// reconstruction pour réagir au changement de thème.
class AppColors {
  static const Color navy =
      Color(0xFF013A5E); // bleu nuit du logo (mot "Lindk", arc du bas)
  // Éclairci (demande explicite : "dark mode should not be that dark...
  // strings and all the logos... should still be as visible as when it is
  // light mode") — un vert foncé "confortable", plus le quasi-noir d'avant,
  // qui écrasait le contraste de tout ce qui est dessiné en couleur fixe
  // (logos, icônes, badges) par-dessus.
  static const Color darkBackground =
      Color(0xFF1B2A21); // fond sombre (onboarding + mode sombre)
  static const Color darkSurface =
      Color(0xFF22352A); // cartes/éléments sur fond sombre
  static const Color greenDark =
      Color(0xFF094824); // vert de marque le plus foncé
  static const Color greenDeep = Color(0xFF0B622F); // début dégradé boutons
  static const Color greenMid = Color(0xFF2F7E23); // milieu dégradé / logo
  static const Color greenBright =
      Color(0xFF509919); // vert vif, feuilles, accents

  // ---- Couleurs claires (mode clair) ----
  // `surface` (fond des écrans) volontairement un cran plus soutenu qu'un
  // simple blanc cassé — un blanc pur derrière des cartes blanches rendait
  // les écrans plats ("trop fade"). Les cartes elles-mêmes ([_cardLight])
  // restent blanches pour bien s'en détacher.
  //
  // Encore approfondi une seconde fois (demande explicite : "fonds...
  // plus profonds mais toujours agréables"), puis légèrement redosé vers
  // le blanc (demande explicite suivante : "le fond doit être un peu
  // moins vert"), puis éclairci une nouvelle fois (demande explicite :
  // "the background... should be lighter meaning the green should be
  // lighter"), puis une troisième fois, encore plus proche du blanc
  // (demande explicite : "much more close to white but still
  // differentiated from white"), puis très légèrement redosé vers le vert
  // (demande explicite suivante : "the background of the app should be
  // slightly deeper") — un cran seulement, F5FAF7 étant presque
  // indiscernable du blanc une fois posé derrière les cartes blanches.
  static const Color _backgroundLight = Color(0xFFFFFFFF);
  static const Color _surfaceLight = Color(0xFFECF6F0);
  static const Color _cardLight = Color(0xFFFAFDFB);
  static const Color _textGrayLight = Color(0xFF6B7280);
  static const Color _lineLight = Color(0xFFD6E3DA);
  static const Color _inputFillLight = Color(0xFFECF5EF);

  // ---- Couleurs sombres (mode sombre) ----
  // Toutes éclaircies d'un cran (voir la note sur [darkBackground]) : cartes
  // nettement distinctes du fond au lieu de quasi-noir sur quasi-noir,
  // bordures qui se voient vraiment, gris secondaire plus clair.
  static const Color _cardDark = Color(0xFF2A3F31);
  static const Color _textGrayDark = Color(0xFFB7C0B9);
  static const Color _lineDark = Color(0xFF3D5443);
  static const Color _inputFillDark = Color(0xFF2A3F31);
  static const Color _headingDark = Color(0xFFEAF3EC);

  /// Fond principal des écrans.
  static Color get background => isDarkMode ? darkBackground : _backgroundLight;

  /// Fond secondaire (légèrement teinté), utilisé derrière les cartes.
  static Color get surface => isDarkMode ? darkSurface : _surfaceLight;

  /// Fond des cartes/tuiles.
  static Color get card => isDarkMode ? _cardDark : _cardLight;

  /// Texte secondaire / labels discrets.
  static Color get textGray => isDarkMode ? _textGrayDark : _textGrayLight;

  /// Bordures fines (cartes, séparateurs, champs).
  static Color get line => isDarkMode ? _lineDark : _lineLight;

  /// Fond des champs de formulaire.
  static Color get inputFill => isDarkMode ? _inputFillDark : _inputFillLight;

  /// Couleur des titres et icônes de premier plan : vert foncé de marque en
  /// clair, presque blanc en sombre (pour rester lisible sur fond sombre).
  static Color get heading => isDarkMode ? _headingDark : greenDark;

  static const Color _mainTextLight = Color(0xFF15201A);

  /// Texte "principal" d'un écran — demande explicite : le contenu texte de
  /// (presque) tous les écrans passe du vert de [heading] à du NOIR (quasi
  /// noir, pas #000 pur, pour rester doux), titres du haut ("headings")
  /// compris partout, contenu compris partout SAUF l'accueil (accueil du
  /// Fournisseur = onglet Accueil de [WasteProviderShell], accueil du
  /// Collecteur = tableau de bord de HomeScreen), qui garde son vert
  /// d'origine — seul le titre tout en haut de CES deux accueils rejoint
  /// quand même cette teinte noire, par la règle "tous les titres du haut,
  /// sans exception". En sombre, identique à [heading] (déjà quasi blanc,
  /// donc déjà lisible — rien à changer côté sombre).
  static Color get mainText => isDarkMode ? _headingDark : _mainTextLight;

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [greenDeep, greenMid],
  );

  /// Vert plus clair que [buttonGradient] — réservé aux "logos" (icônes des
  /// petites boîtes : actions rapides, statistiques, réglages, listes…)
  /// dans TOUTE l'app, pour qu'ils restent cohérents entre eux sans jamais
  /// être confondus avec [buttonGradient] (boutons pleins, ET carte "Mes
  /// points" — demande explicite : même vert que "Ajouter au recyclage").
  static const LinearGradient lightIconGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8BC34A), Color(0xFFB6E388)],
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenBright, greenMid],
  );

  /// Dégradé de la carte "Mes points" — redevenu [buttonGradient] (demande
  /// explicite la plus récente : "the mes points box color should be of the
  /// same as ajouter au recyclage"), après un détour sarcelle/teal calqué
  /// sur une maquette qui ne correspond plus à ce qui est demandé aujourd'hui.
  static const LinearGradient pointsCardGradient = buttonGradient;

  /// Cercle plein derrière le trophée du badge "Mes points" — même vert vif
  /// que les icônes de logos partout ailleurs (voir [greenBright]),
  /// cohérent avec [pointsCardGradient] = [buttonGradient].
  static const Color pointsCardBadge = greenBright;

  /// Texte + flèche du bouton "Voir mon profil" (pastille blanche pleine,
  /// pas translucide) — même vert que [buttonGradient].
  static const Color pointsCardButtonText = greenDeep;

  /// Jaune/ambré partagé — SEULE couleur avec le vert autorisée sur "Cette
  /// semaine" (donut) et "Convertir mes points" (demande explicite : plus
  /// de bleu/violet/orange sur ces éléments-là, seulement vert et jaune,
  /// une seule et même teinte de jaune partout).
  static const Color amber = Color(0xFFE0A800);
}

class AppTextStyles {
  static TextStyle get display => TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.heading,
      );
  static TextStyle get body => TextStyle(
        color: AppColors.textGray,
      );
}

InputDecorationTheme _inputDecorationTheme({required bool dark}) =>
    InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors._inputFillDark : AppColors._inputFillLight,
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
      labelStyle: TextStyle(
        color: dark ? AppColors._headingDark : AppColors.greenDark,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    );

/// Thème clair (par défaut). Défini une fois pour toutes — indépendant du
/// thème actif — pour servir de valeur fixe à `MaterialApp.theme`.
final ThemeData ecoLindkTheme = ThemeData(
  brightness: Brightness.light,
  // Vaut pour TOUT écran qui ne fixe pas explicitement son propre
  // `Scaffold.backgroundColor` (Login, Register, choix du rôle…) — sans
  // ça, ces écrans retombaient sur du blanc pur malgré [_surfaceLight]
  // déjà renforcé partout ailleurs. Un seul et même fond, vraiment partout.
  scaffoldBackgroundColor: AppColors._surfaceLight,
  fontFamily: 'Roboto',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.greenMid,
    brightness: Brightness.light,
    primary: AppColors.greenMid,
    secondary: AppColors.greenBright,
    background: AppColors._backgroundLight,
  ),
  inputDecorationTheme: _inputDecorationTheme(dark: false),
);

/// Thème sombre, utilisé pour `MaterialApp.darkTheme`.
final ThemeData ecoLindkDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  fontFamily: 'Roboto',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.greenMid,
    brightness: Brightness.dark,
    primary: AppColors.greenBright,
    secondary: AppColors.greenBright,
    background: AppColors.darkBackground,
  ),
  inputDecorationTheme: _inputDecorationTheme(dark: true),
);
