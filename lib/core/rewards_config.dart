import 'package:flutter/material.dart';
import '../models/collection_request.dart';

/// Barème unique de points/prix/conversion pour toute l'application —
/// aucune logique de récompense ne doit exister ailleurs (Wallet, Redeem,
/// PriceList, ConversionRates et CollectionService lisent tous ces mêmes
/// constantes, jamais des valeurs recalculées indépendamment).
///
/// Chiffres provisoires pour la démonstration : à remplacer par un barème
/// métier réel si besoin, mais toujours en un seul endroit (ici).
class RewardsConfig {
  const RewardsConfig._();

  /// Points gagnés par kg collecté, selon la catégorie de déchet.
  static const Map<WasteCategory, double> pointsPerKg = {
    WasteCategory.plastic: 10,
    WasteCategory.paperCardboard: 6,
    WasteCategory.glass: 8,
    WasteCategory.metal: 15,
  };

  /// Prix de référence (FCFA/kg) affiché sur la page "Liste des prix" —
  /// basés sur la grille tarifaire officielle publiée par ECOCOLLECT SARL
  /// pour Douala et Yaoundé (14 février 2026) : plastiques 75 FCFA/kg,
  /// verre et papiers/cartons 50 FCFA/kg, aluminium/canettes 200 FCFA/kg
  /// (la ferraille, elle, se négocie autour de 100 FCFA/kg — non distinguée
  /// ici, notre catégorie "métal" couvrant les deux). Source :
  /// https://vitrineducameroun.com/2026/02/15/valorisation-des-dechets-une-grille-de-prix-pour-doper-la-pre-collecte/
  static const Map<WasteCategory, double> pricePerKgFcfa = {
    WasteCategory.plastic: 75,
    WasteCategory.paperCardboard: 50,
    WasteCategory.glass: 50,
    WasteCategory.metal: 200,
  };

  /// Taux de conversion points -> FCFA : [conversionThresholdPoints] points
  /// valent [conversionValueFcfa] FCFA — taux actuel communiqué par
  /// l'utilisateur : 15 points = 500 FCFA.
  static const int conversionThresholdPoints = 15;
  static const int conversionValueFcfa = 500;

  /// Barème de référence détaillé (8 matières), affiché sur "Taux de
  /// conversion" et "Liste des prix" — plus fin que les 4 catégories de
  /// [WasteCategory] utilisées pour déclarer un déchet (PostWasteScreen) :
  /// demande explicite de l'utilisateur pour CES DEUX PAGES uniquement, pas
  /// encore répercuté sur le flux de déclaration réel. Le prix FCFA de la
  /// Liste des prix est dérivé de ces mêmes points via le taux ci-dessus —
  /// jamais un second barème indépendant (voir [fcfaForPoints]).
  static const List<ReferenceMaterial> referenceMaterials = [
    ReferenceMaterial("Bouteilles plastique", "Plastic bottles", Icons.local_drink_outlined, 3),
    ReferenceMaterial("Carton", "Carton", Icons.inventory_2_outlined, 2),
    ReferenceMaterial("Plastique dur", "Hard plastic", Icons.category_outlined, 2),
    ReferenceMaterial("Papier", "Paper", Icons.description_outlined, 1),
    ReferenceMaterial(
        "Plastique à usage unique", "Single-use plastic", Icons.local_cafe_outlined, 4),
    ReferenceMaterial("Mixte", "Mixed", Icons.layers_outlined, 2),
    ReferenceMaterial("Métal", "Metal", Icons.settings_input_component_outlined, 6),
    ReferenceMaterial("Verre", "Glass", Icons.wine_bar_outlined, 0.5),
  ];

  /// Points offerts au parrain lorsque le filleul complète sa première
  /// collecte qualifiante (voir ReferralService).
  static const int referralPoints = 50;

  /// Poids minimum (kg) pour qu'une collecte compte comme "qualifiante" pour
  /// le parrainage.
  static const double qualifyingCollectionMinKg = 1.0;

  static double fcfaForPoints(num points) =>
      points / conversionThresholdPoints * conversionValueFcfa;

  static double pointsForCollection(WasteCategory category, double weightKg) =>
      (pointsPerKg[category] ?? 0) * weightKg;

  static double valueForCollection(WasteCategory category, double weightKg) =>
      (pricePerKgFcfa[category] ?? 0) * weightKg;
}

/// Une ligne du barème de référence détaillé (voir [RewardsConfig.referenceMaterials]).
class ReferenceMaterial {
  final String labelFr;
  final String labelEn;
  final IconData icon;
  final double pointsPerKg;
  const ReferenceMaterial(this.labelFr, this.labelEn, this.icon, this.pointsPerKg);

  String label(bool fr) => fr ? labelFr : labelEn;
  double fcfaPerKg() => RewardsConfig.fcfaForPoints(pointsPerKg);
}
