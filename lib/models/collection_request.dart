import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

/// Catégories de déchets recyclables reconnues par l'app (déclaration
/// manuelle ou suggestion IA — voir [PostWasteScreen]).
/// Canettes de boisson et métal sont deux catégories distinctes (demande
/// explicite) : barèmes différents.
enum WasteCategory { plastic, paperCardboard, glass, metal, beverageCans }

extension WasteCategoryX on WasteCategory {
  String label(bool fr) => switch (this) {
        WasteCategory.plastic => fr ? "Plastique" : "Plastic",
        WasteCategory.paperCardboard =>
          fr ? "Papier / Carton" : "Paper / Cardboard",
        WasteCategory.glass => fr ? "Verre" : "Glass",
        WasteCategory.metal => fr ? "Métal" : "Metal",
        WasteCategory.beverageCans => fr ? "Canettes de boisson" : "Beverage cans",
      };

  IconData get icon => switch (this) {
        WasteCategory.plastic => Icons.liquor_rounded, // bouteille
        WasteCategory.paperCardboard => RemixIcons.box_3_fill, // carton
        WasteCategory.glass => RemixIcons.goblet_fill,
        WasteCategory.metal => RemixIcons.oil_fill, // bidon, ferraille
        WasteCategory.beverageCans => Icons.sports_bar_rounded, // canette
      };

  /// Exemples courts affichés sous le nom de la catégorie (formulaire de
  /// post) pour aider à choisir.
  String examples(bool fr) => switch (this) {
        WasteCategory.plastic => fr ? "Bouteilles, bidons, emballages" : "Bottles, jugs, packaging",
        WasteCategory.paperCardboard => fr ? "Cartons, journaux, papier" : "Boxes, newspapers, paper",
        WasteCategory.glass => fr ? "Bouteilles, bocaux" : "Bottles, jars",
        WasteCategory.metal => fr ? "Ferraille, boîtes de conserve, fer" : "Scrap metal, food tins, iron",
        WasteCategory.beverageCans => fr ? "Canettes de soda, de bière, de jus" : "Soda, beer and juice cans",
      };

  /// Couleur d'accent propre à chaque catégorie — utilisée partout où une
  /// catégorie est affichée (post d'un déchet, historique, suivi, listes de
  /// prix…) pour que ces écrans ne soient jamais uniformément verts/gris.
  Color get color => switch (this) {
        // Palette vert/or du thème (demande explicite : catégories en
        // couleurs "qui entrent dans le thème de l'app, vert et or") —
        // teintes alternées pour rester distinguables entre elles.
        WasteCategory.plastic => const Color(0xFF3E9E6C), // vert émeraude
        // Papier/carton et métal : même vert feuille que les canettes
        // (demande explicite : plus de pastilles jaunes).
        WasteCategory.paperCardboard => const Color(0xFF86A843), // vert feuille
        WasteCategory.glass => const Color(0xFF2E6E4E), // vert forêt
        WasteCategory.metal => const Color(0xFF86A843), // vert feuille
        WasteCategory.beverageCans => const Color(0xFF86A843), // vert feuille
      };

  /// Dégradé de l'icône de catégorie : de la couleur d'accent vers une
  /// version plus claire, pour des pastilles moins plates.
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.28)!, color],
      );

  static WasteCategory fromName(String? name) => WasteCategory.values
      .firstWhere((c) => c.name == name, orElse: () => WasteCategory.plastic);
  static WasteCategory? tryFromName(String? name) =>
      WasteCategory.values.where((c) => c.name == name).firstOrNull;
}

/// Cycle de vie d'une demande de collecte (voir règle métier : une demande
/// n'est acceptée que par un seul collecteur — voir CollectionService).
///
/// [inProgress] a changé de sens (demande explicite) : ce n'est plus une
/// étape que le collecteur coche manuellement, mais l'état "le collecteur a
/// soumis poids + prix après la rencontre, en attente que le fournisseur
/// scanne le QR et confirme ou refuse" — voir [CollectionRequest.pendingWeightKg]/
/// [CollectionRequest.pendingPriceFcfa] et CollectionService.submitCollectionResult.
enum RequestStatus { pending, accepted, inProgress, completed, cancelled }

extension RequestStatusX on RequestStatus {
  String label(bool fr) => switch (this) {
        RequestStatus.pending => fr ? "En attente" : "Pending",
        RequestStatus.accepted => fr ? "Collecteur assigné" : "Collector assigned",
        RequestStatus.inProgress =>
          fr ? "En attente de confirmation" : "Awaiting confirmation",
        RequestStatus.completed => fr ? "Terminée" : "Completed",
        RequestStatus.cancelled => fr ? "Annulée" : "Cancelled",
      };

  static RequestStatus fromName(String? name) => RequestStatus.values
      .firstWhere((r) => r.name == name, orElse: () => RequestStatus.pending);
}

/// Écart maximal (kg) toléré entre le poids pesé par le collecteur en fin de
/// collecte et le poids retenu au moment du post (demande explicite : "ça
/// doit être dans un intervalle de 5, sinon le formulaire renvoie une erreur
/// demandant au collecteur d'entrer le poids correct"). Bornes incluses :
/// pour un post de 6 kg, tout poids entre 1 et 11 kg est accepté. Une seule
/// source de vérité, utilisée par l'UI ET par
/// CollectionService.submitCollectionResult. Les 4 anciens paliers restent
/// reconnus tels quels pour les demandes postées avant la saisie libre.
const double maxWeightDeviationKg = 5;

extension QuantityRangeBounds on String {
  /// Poids déclaré au post (kg), `null` pour un ancien palier ou un texte
  /// illisible.
  double? get declaredWeightKg {
    if (const ['< 1 kg', '1 - 5 kg', '5 - 10 kg', '10+ kg'].contains(this)) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(this);
    final value = match == null ? null : double.tryParse(match.group(1)!.replaceAll(',', '.'));
    return (value == null || value <= 0) ? null : value;
  }

  /// Seule règle de validation du poids pesé par le collecteur — utilisée
  /// par l'UI (CollectionConfirmationScreen) ET par
  /// CollectionService.submitCollectionResult.
  bool acceptsCollectedWeight(double weightKg) {
    if (weightKg <= 0) return false;
    final declared = declaredWeightKg;
    // Petite marge pour les arrondis décimaux (6 - 1.0 ≠ 5 exactement).
    if (declared != null) return (weightKg - declared).abs() <= maxWeightDeviationKg + 1e-9;
    final (min, max) = weightBoundsKg;
    return weightKg >= min && weightKg <= max;
  }

  (double min, double max) get weightBoundsKg {
    switch (this) {
      case '< 1 kg':
        return (0, 1);
      case '1 - 5 kg':
        return (1, 5);
      case '5 - 10 kg':
        return (5, 10);
      case '10+ kg':
        return (10, double.infinity);
    }
    final value = declaredWeightKg;
    if (value == null) return (0, double.infinity);
    return (
      (value - maxWeightDeviationKg).clamp(0, double.infinity).toDouble(),
      value + maxWeightDeviationKg
    );
  }
}

/// Une demande de collecte postée par un Fournisseur de déchets. Stockée
/// dans `collectionRequests/{id}` (voir firestore.rules pour les
/// permissions : le fournisseur ne voit que les siennes, un collecteur peut
/// lire les demandes `pending` et en accepter une via une transaction qui
/// échoue si `collectorUid` n'est déjà plus `null`).
class CollectionRequest {
  final String id;
  final String householdUid;
  final String householdName;

  final String imageUrl;
  final String description;
  final WasteCategory category;
  final String quantityRange; // ex. "1-5 kg"

  /// `true` si l'analyse IA a été demandée à la création. [aiSuggestedCategory]
  /// et [aiConfidence] restent `null` si l'utilisateur a désactivé l'IA — dans
  /// ce cas [category] est la catégorie choisie manuellement.
  final bool aiRequested;
  final WasteCategory? aiSuggestedCategory;
  final double? aiConfidence;

  /// Poids estimé par l'IA (kg), `null` si elle n'a pas pu l'estimer.
  final double? aiEstimatedWeightKg;

  /// Choix de l'utilisateur face au résultat de l'IA : `accepted` (les
  /// valeurs de l'IA sont devenues celles du post), `refused` (il les a
  /// corrigées) ou `unavailable` (analyse impossible, valeurs saisies à la
  /// main). `null` pour les posts antérieurs à ce choix.
  final String? aiDecision;

  final String address;
  final double latitude;
  final double longitude;

  /// Quartier et ville du post, déduits de ses coordonnées par géocodage
  /// inverse OpenStreetMap à la publication (voir CollectionService) —
  /// affichés dans la notification des collecteurs et comparés à leurs
  /// zones de collecte. `null` si inconnus.
  final String? neighborhood;
  final String? city;

  /// `true` si les coordonnées viennent du géocodage d'une adresse tapée
  /// (voir GeocodingService) plutôt que du GPS de l'appareil — affiché
  /// honnêtement dans l'UI comme "approximatif" (moins précis qu'un point
  /// GPS direct).
  final bool locationIsApproximate;

  final RequestStatus status;
  final String? collectorUid;
  final String? collectorName;

  /// Poids/prix soumis par le collecteur après la rencontre, EN ATTENTE de
  /// la confirmation du fournisseur (statut [RequestStatus.inProgress]) —
  /// jamais définitifs tant que le fournisseur n'a pas scanné le QR et
  /// accepté (voir CollectionService.confirmCollectionResult). `null` une
  /// fois la collecte confirmée ou si elle a été refusée (voir
  /// [rejectCollectionResult]).
  final double? pendingWeightKg;
  final double? pendingPriceFcfa;

  /// `true` quand le Fournisseur vient de refuser le formulaire soumis —
  /// l'écran Collecte du collecteur affiche alors une erreur l'invitant à le
  /// remplir de nouveau. Remis à `false` à la soumission suivante.
  final bool resultRejected;

  /// Code aléatoire régénéré à chaque formulaire soumis par le collecteur et
  /// inclus dans le QR code qu'il affiche (voir [qrPayload]). Le Fournisseur
  /// n'accède au formulaire à accepter/refuser qu'en scannant ce QR (voir
  /// ScanScreen) : impossible de confirmer à distance, sans la rencontre.
  final String? scanCode;

  /// Contenu du QR code affiché par le collecteur une fois son formulaire
  /// soumis.
  String get qrPayload => 'ecolindk:collection:$id:${scanCode ?? ''}';

  /// Moment où le collecteur a tapé "Démarrer la collecte" (voir
  /// CollectorCollectionScreen) — déclenche la demande de partage de
  /// position au Fournisseur pour le suivi en temps réel.
  final DateTime? collectionStartedAt;

  /// Commission due par le collecteur pour cette collecte : poids confirmé ×
  /// tarif de sa catégorie (voir RewardsConfig.commissionPerKgFcfa), figée
  /// au moment de la double confirmation.
  final double? commissionFcfa;

  /// Définitifs, écrits uniquement quand le fournisseur confirme — jamais
  /// par le collecteur directement (voir firestore.rules).
  final double? weightKg;
  final double? valueFcfa;
  final int? pointsEarned;

  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  const CollectionRequest({
    required this.id,
    required this.householdUid,
    required this.householdName,
    required this.imageUrl,
    required this.description,
    required this.category,
    required this.quantityRange,
    required this.aiRequested,
    this.aiSuggestedCategory,
    this.aiConfidence,
    this.aiEstimatedWeightKg,
    this.aiDecision,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.neighborhood,
    this.city,
    required this.locationIsApproximate,
    required this.status,
    this.collectorUid,
    this.collectorName,
    this.pendingWeightKg,
    this.pendingPriceFcfa,
    this.resultRejected = false,
    this.scanCode,
    this.collectionStartedAt,
    this.commissionFcfa,
    this.weightKg,
    this.valueFcfa,
    this.pointsEarned,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  /// Référence courte et lisible affichée à l'utilisateur (QR, historique,
  /// traçabilité) plutôt que l'identifiant Firestore brut.
  String get reference => 'ECL-${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';

  factory CollectionRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime? ts(String key) => (d[key] as Timestamp?)?.toDate();
    return CollectionRequest(
      id: doc.id,
      householdUid: d['householdUid'] as String? ?? '',
      householdName: d['householdName'] as String? ?? '',
      imageUrl: d['imageUrl'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: WasteCategoryX.fromName(d['category'] as String?),
      quantityRange: d['quantityRange'] as String? ?? '',
      aiRequested: d['aiRequested'] as bool? ?? false,
      aiSuggestedCategory: d['aiSuggestedCategory'] == null
          ? null
          : WasteCategoryX.fromName(d['aiSuggestedCategory'] as String?),
      aiConfidence: (d['aiConfidence'] as num?)?.toDouble(),
      aiEstimatedWeightKg: (d['aiEstimatedWeightKg'] as num?)?.toDouble(),
      aiDecision: d['aiDecision'] as String?,
      address: d['address'] as String? ?? '',
      latitude: (d['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (d['longitude'] as num?)?.toDouble() ?? 0,
      neighborhood: d['neighborhood'] as String?,
      city: d['city'] as String?,
      locationIsApproximate: d['locationIsApproximate'] as bool? ?? true,
      status: RequestStatusX.fromName(d['status'] as String?),
      collectorUid: d['collectorUid'] as String?,
      collectorName: d['collectorName'] as String?,
      pendingWeightKg: (d['pendingWeightKg'] as num?)?.toDouble(),
      pendingPriceFcfa: (d['pendingPriceFcfa'] as num?)?.toDouble(),
      resultRejected: d['resultRejected'] as bool? ?? false,
      scanCode: d['scanCode'] as String?,
      collectionStartedAt: ts('collectionStartedAt'),
      commissionFcfa: (d['commissionFcfa'] as num?)?.toDouble(),
      weightKg: (d['weightKg'] as num?)?.toDouble(),
      valueFcfa: (d['valueFcfa'] as num?)?.toDouble(),
      pointsEarned: (d['pointsEarned'] as num?)?.toInt(),
      createdAt: ts('createdAt') ?? DateTime.now(),
      acceptedAt: ts('acceptedAt'),
      completedAt: ts('completedAt'),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'householdUid': householdUid,
        'householdName': householdName,
        'imageUrl': imageUrl,
        'description': description,
        'category': category.name,
        'quantityRange': quantityRange,
        'aiRequested': aiRequested,
        'aiSuggestedCategory': aiSuggestedCategory?.name,
        'aiConfidence': aiConfidence,
        'aiEstimatedWeightKg': aiEstimatedWeightKg,
        'aiDecision': aiDecision,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'neighborhood': neighborhood,
        'city': city,
        'locationIsApproximate': locationIsApproximate,
        'status': RequestStatus.pending.name,
        'collectorUid': null,
        'collectorName': null,
        'weightKg': null,
        'valueFcfa': null,
        'pointsEarned': null,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'completedAt': null,
      };
}
