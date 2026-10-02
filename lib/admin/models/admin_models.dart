import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/collection_zone.dart';
import '../../models/user_role.dart';
import '../../models/wallet_models.dart';

/// Lecture seule d'une fiche `users/{uid}` (voir AuthService pour les champs
/// écrits à l'inscription) — l'app mobile n'a pas de modèle utilisateur, elle
/// lit la map brute ; le tableau de bord en a besoin pour ses listes.
class AdminUser {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String address;

  /// `null` : inscription jamais terminée (rôle pas encore choisi).
  final UserRole? role;
  final WorkStatus? workStatus;
  final String? companyName;
  final bool phoneVerified;
  final List<CollectionZone> zones;
  final DateTime? createdAt;

  const AdminUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    this.role,
    this.workStatus,
    this.companyName,
    this.phoneVerified = false,
    this.zones = const [],
    this.createdAt,
  });

  String get displayName => fullName.trim().isNotEmpty ? fullName.trim() : (email.isNotEmpty ? email : uid);

  factory AdminUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminUser(
      uid: doc.id,
      fullName: d['fullName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      address: d['address'] as String? ?? '',
      role: UserRole.values.where((r) => r.name == d['role']).firstOrNull,
      workStatus: WorkStatus.values.where((w) => w.name == d['workStatus']).firstOrNull,
      companyName: d['companyName'] as String?,
      phoneVerified: d['phoneVerified'] as bool? ?? false,
      zones: CollectionZone.fromUserData(d),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Une conversion de points (`wallets/{uid}/redemptions/{id}`), avec l'uid
/// du Fournisseur qui l'a faite — absent du document, déduit de son chemin.
class AdminRedemption {
  final String uid;
  final RedemptionRequest request;

  const AdminRedemption(this.uid, this.request);

  factory AdminRedemption.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AdminRedemption(doc.reference.parent.parent?.id ?? '', RedemptionRequest.fromDoc(doc));
}

/// Portefeuille à points d'un Fournisseur (`wallets/{uid}`, voir WalletService).
class WalletSummary {
  final int balance;
  final int lifetimeEarned;

  const WalletSummary({required this.balance, required this.lifetimeEarned});

  static const empty = WalletSummary(balance: 0, lifetimeEarned: 0);

  /// Même repli que WalletService.watchLifetimeEarned pour les anciens
  /// portefeuilles sans `lifetimeEarned`.
  factory WalletSummary.fromData(Map<String, dynamic>? d) {
    final balance = (d?['pointsBalance'] as num?)?.toInt() ?? 0;
    return WalletSummary(balance: balance, lifetimeEarned: (d?['lifetimeEarned'] as num?)?.toInt() ?? balance);
  }
}
