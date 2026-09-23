import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Catégories de déchets recyclables reconnues par l'app (déclaration
/// manuelle ou suggestion IA — voir [PostWasteScreen]).
enum WasteCategory { plastic, paperCardboard, glass, metal }

extension WasteCategoryX on WasteCategory {
  String label(bool fr) => switch (this) {
        WasteCategory.plastic => fr ? "Plastique" : "Plastic",
        WasteCategory.paperCardboard =>
          fr ? "Papier / Carton" : "Paper / Cardboard",
        WasteCategory.glass => fr ? "Verre" : "Glass",
        WasteCategory.metal => fr ? "Métal (canettes, etc.)" : "Metal (cans, etc.)",
      };

  IconData get icon => switch (this) {
        WasteCategory.plastic => Icons.local_drink_outlined,
        WasteCategory.paperCardboard => Icons.inventory_2_outlined,
        WasteCategory.glass => Icons.wine_bar_outlined,
        WasteCategory.metal => Icons.settings_input_component_outlined,
      };

  /// Couleur d'accent propre à chaque catégorie — utilisée partout où une
  /// catégorie est affichée (post d'un déchet, historique, suivi, listes de
  /// prix…) pour que ces écrans ne soient jamais uniformément verts/gris.
  Color get color => switch (this) {
        WasteCategory.plastic => const Color(0xFF2094C4), // bleu
        WasteCategory.paperCardboard => const Color(0xFFB5792B), // brun chaud
        WasteCategory.glass => const Color(0xFF17A398), // sarcelle
        WasteCategory.metal => const Color(0xFF7C5CBF), // violet acier
      };

  static WasteCategory fromName(String? name) => WasteCategory.values
      .firstWhere((c) => c.name == name, orElse: () => WasteCategory.plastic);
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

/// Bornes (kg) tolérées pour le poids réel saisi par le collecteur en fin de
/// collecte, comparées à ce que le fournisseur a déclaré à la création du
/// post (demande explicite : "the system checks that the weight is in a
/// certain range as compared to what was previously entered by the waste
/// provider"). Une seule source de vérité pour ces bornes — jamais
/// redéfinies ailleurs.
///
/// [PostWasteScreen] ne propose plus de paliers fixes (demande explicite :
/// "ça ne doit pas proposer à l'utilisateur, ça doit... laisser
/// l'utilisateur entrer une approximation ou une quantité exacte") — la
/// quantité est un nombre de kg tapé librement (ex. "3.5 kg"), stocké tel
/// quel. Les bornes deviennent donc une tolérance de ±40 % autour de ce
/// nombre plutôt qu'une fourchette fixe. Les 4 anciens paliers restent
/// reconnus tels quels pour les demandes déjà postées avant ce changement.
extension QuantityRangeBounds on String {
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
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(this);
    final value = match == null ? null : double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null || value <= 0) return (0, double.infinity);
    return (value * 0.6, value * 1.4);
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

  final String address;
  final double latitude;
  final double longitude;

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
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.locationIsApproximate,
    required this.status,
    this.collectorUid,
    this.collectorName,
    this.pendingWeightKg,
    this.pendingPriceFcfa,
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
      address: d['address'] as String? ?? '',
      latitude: (d['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (d['longitude'] as num?)?.toDouble() ?? 0,
      locationIsApproximate: d['locationIsApproximate'] as bool? ?? true,
      status: RequestStatusX.fromName(d['status'] as String?),
      collectorUid: d['collectorUid'] as String?,
      collectorName: d['collectorName'] as String?,
      pendingWeightKg: (d['pendingWeightKg'] as num?)?.toDouble(),
      pendingPriceFcfa: (d['pendingPriceFcfa'] as num?)?.toDouble(),
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
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
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
