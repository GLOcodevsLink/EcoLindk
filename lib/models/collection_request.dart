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
enum RequestStatus { pending, accepted, inProgress, completed, cancelled }

extension RequestStatusX on RequestStatus {
  String label(bool fr) => switch (this) {
        RequestStatus.pending => fr ? "En attente" : "Pending",
        RequestStatus.accepted => fr ? "Collecteur assigné" : "Collector assigned",
        RequestStatus.inProgress => fr ? "Collecte en cours" : "Collection in progress",
        RequestStatus.completed => fr ? "Terminée" : "Completed",
        RequestStatus.cancelled => fr ? "Annulée" : "Cancelled",
      };

  static RequestStatus fromName(String? name) => RequestStatus.values
      .firstWhere((r) => r.name == name, orElse: () => RequestStatus.pending);
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

  /// `true` si les coordonnées viennent d'une adresse tapée (géocodage
  /// simulé en attendant l'intégration d'une vraie API de cartes) plutôt que
  /// du GPS de l'appareil — affiché honnêtement dans l'UI comme "approximatif".
  final bool locationIsApproximate;

  final RequestStatus status;
  final String? collectorUid;
  final String? collectorName;

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
