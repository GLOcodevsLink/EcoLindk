import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/rewards_config.dart';
import '../models/collection_request.dart';
import 'payment_gateway.dart';

/// Un règlement de commission par le Collecteur (`commissionPayments/{id}`).
class CommissionPayment {
  final String id;
  final String collectorUid;
  final int amountFcfa;
  final String phone;
  final String channel;
  final String mode;
  final String status; // 'pending' puis un PaymentStatus.name
  final String? message;
  final DateTime createdAt;

  const CommissionPayment({
    required this.id,
    required this.collectorUid,
    required this.amountFcfa,
    required this.phone,
    required this.channel,
    required this.mode,
    required this.status,
    this.message,
    required this.createdAt,
  });

  bool get isSuccess => status == PaymentStatus.success.name;
  bool get isPending => status == 'pending';

  factory CommissionPayment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CommissionPayment(
      id: doc.id,
      collectorUid: d['collectorUid'] as String? ?? '',
      amountFcfa: (d['amountFcfa'] as num?)?.toInt() ?? 0,
      phone: d['phone'] as String? ?? '',
      channel: d['channel'] as String? ?? '',
      mode: d['mode'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      message: d['message'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Paiement de la commission due par le Collecteur (voir
/// CollectorCommissionScreen). Solde dû = commissions de toutes ses collectes
/// terminées − règlements réussis ; le Collecteur règle tout ou partie du
/// solde par Mobile Money via [PaymentGateway] (simulation ou Notch Pay test).
class CommissionService {
  CommissionService({FirebaseFirestore? firestore, PaymentGateway? gateway})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        gateway = gateway ?? PaymentGateway.fromEnvironment();

  final FirebaseFirestore _firestore;
  final PaymentGateway gateway;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('commissionPayments');

  /// Commission d'une collecte terminée — figée sur la demande à la double
  /// confirmation, recalculée depuis le poids pour les collectes plus
  /// anciennes.
  static double commissionOf(CollectionRequest r) =>
      r.commissionFcfa ?? RewardsConfig.commissionForCollection(r.category, r.weightKg ?? 0);

  /// Solde restant à payer, arrondi au franc (jamais négatif).
  static int outstanding(List<CollectionRequest> history, List<CommissionPayment> payments) {
    final due = history
        .where((r) => r.status == RequestStatus.completed)
        .fold<double>(0, (total, r) => total + commissionOf(r));
    final paid = payments.where((p) => p.isSuccess).fold<int>(0, (total, p) => total + p.amountFcfa);
    final rest = due.round() - paid;
    return rest < 0 ? 0 : rest;
  }

  /// Règlements du Collecteur, du plus récent au plus ancien (tri local :
  /// évite un index composite).
  Stream<List<CommissionPayment>> watchPayments(String collectorUid) => _payments
      .where('collectorUid', isEqualTo: collectorUid)
      .snapshots()
      .map((q) => q.docs.map(CommissionPayment.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// Enregistre le règlement "en attente", lance l'encaissement Mobile Money,
  /// puis note son issue sur le même document.
  Future<PaymentResult> payCommission({
    required String collectorUid,
    required int amountFcfa,
    required String phone,
    required MobileMoneyOperator operator,
  }) async {
    if (amountFcfa <= 0) throw ArgumentError.value(amountFcfa, 'amountFcfa');
    final doc = _payments.doc();
    final reference = 'ecl_com_${doc.id}';
    await doc.set({
      'collectorUid': collectorUid,
      'amountFcfa': amountFcfa,
      'phone': phone,
      'channel': operator.channel,
      'mode': gateway.modeLabel,
      'reference': reference,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    PaymentResult result;
    try {
      result = await gateway.collect(
        amountFcfa: amountFcfa,
        phone: phone,
        operator: operator,
        reference: reference,
        description: 'Commission EcoLindk',
      );
    } catch (e) {
      result = PaymentResult(PaymentStatus.failed, reference, message: e.toString());
    }

    await doc.update({
      'status': result.status.name,
      'message': result.message,
      'completedAt': FieldValue.serverTimestamp(),
    });
    return result;
  }
}
