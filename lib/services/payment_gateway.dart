import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Opérateur Mobile Money (Cameroun) — `channel` est la valeur attendue par
/// Notch Pay (voir https://developer.notchpay.co/api-reference/process-a-payment.md).
enum MobileMoneyOperator {
  mtn('cm.mtn', 'MTN Mobile Money'),
  orange('cm.orange', 'Orange Money');

  const MobileMoneyOperator(this.channel, this.label);
  final String channel;
  final String label;
}

/// Issue d'un paiement — reprend les cas des numéros de test Notch Pay
/// (voir https://developer.notchpay.co/get-started/testing.md).
enum PaymentStatus { success, insufficientFunds, failed, timeout, canceled }

class PaymentResult {
  final PaymentStatus status;
  final String reference;
  final String? message;

  const PaymentResult(this.status, this.reference, {this.message});

  bool get isSuccess => status == PaymentStatus.success;
}

/// Encaissement Mobile Money (le payeur valide sur son téléphone).
///
/// Deux implémentations, choisies selon la présence de la clé de test :
/// - clé `NOTCH_API_KEY=pk_test...` dans `.env` (non versionné) et
///   `flutter run --dart-define-from-file=.env` : vrais appels à l'API
///   Notch Pay en mode test (sandbox), sans argent réel ;
/// - pas de clé : simulation locale, aucun appel réseau.
///
/// Dans les deux cas, c'est l'app qui constate le résultat : acceptable pour
/// une démo, PAS pour de l'argent réel (un client modifié pourrait se
/// déclarer payé). La production passera par un webhook Notch Pay vérifié
/// côté serveur (Cloud Function) — voir FIREBASE_SANS_SERVEUR.md.
abstract class PaymentGateway {
  /// Libellé court affiché à l'utilisateur ("Simulation", "Notch Pay test").
  String get modeLabel;

  Future<PaymentResult> collect({
    required int amountFcfa,
    required String phone, // E.164, ex. "+237670000000"
    required MobileMoneyOperator operator,
    required String reference,
    required String description,
  });

  static const _notchPayKey = String.fromEnvironment('NOTCH_API_KEY');

  static PaymentGateway fromEnvironment() => _notchPayKey.isNotEmpty
      ? NotchPaySandboxGateway(publicKey: _notchPayKey)
      : SimulatedPaymentGateway();
}

/// Simulation locale fidèle aux numéros de test Notch Pay : le numéro se
/// terminant par 000001 → fonds insuffisants, 000002 → échec, 000003 →
/// délai dépassé, 000004 → annulé ; tout autre numéro → succès.
class SimulatedPaymentGateway implements PaymentGateway {
  SimulatedPaymentGateway({this.delay = const Duration(seconds: 2)});

  final Duration delay;

  @override
  String get modeLabel => 'Simulation';

  static PaymentStatus outcomeFor(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.endsWith('000001')) return PaymentStatus.insufficientFunds;
    if (digits.endsWith('000002')) return PaymentStatus.failed;
    if (digits.endsWith('000003')) return PaymentStatus.timeout;
    if (digits.endsWith('000004')) return PaymentStatus.canceled;
    return PaymentStatus.success;
  }

  @override
  Future<PaymentResult> collect({
    required int amountFcfa,
    required String phone,
    required MobileMoneyOperator operator,
    required String reference,
    required String description,
  }) async {
    await Future.delayed(delay);
    return PaymentResult(outcomeFor(phone), reference);
  }
}

/// Notch Pay en mode test : initialise le paiement, déclenche la demande
/// Mobile Money sur [MobileMoneyOperator.channel], puis interroge le statut
/// jusqu'à un état final. Refuse toute clé autre que de test (`pk_test_…`
/// ou `pk_test.…`) : le résultat étant constaté par l'app, une clé live ne
/// doit jamais y passer.
///
/// Notch Pay attribue sa propre référence (`trx.test_…`) au paiement : c'est
/// elle, et non la nôtre (gardée comme `merchant_reference`), qu'attendent
/// le déclenchement et le suivi — la nôtre y répond 404.
class NotchPaySandboxGateway implements PaymentGateway {
  NotchPaySandboxGateway({
    required this.publicKey,
    http.Client? client,
    this.pollInterval = const Duration(seconds: 3),
    this.maxWait = const Duration(minutes: 2),
  }) : _client = client ?? http.Client();

  final String publicKey;
  final http.Client _client;
  final Duration pollInterval;
  final Duration maxWait;

  static const _base = 'https://api.notchpay.co';

  @override
  String get modeLabel => 'Notch Pay test';

  Map<String, String> get _headers => {
        'Authorization': publicKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  Future<PaymentResult> collect({
    required int amountFcfa,
    required String phone,
    required MobileMoneyOperator operator,
    required String reference,
    required String description,
  }) async {
    if (!publicKey.startsWith('pk_test')) {
      throw StateError('notchpay-test-key-required');
    }
    final msisdn = phone.replaceAll(RegExp(r'\D'), '');

    final init = await _client.post(Uri.parse('$_base/payments'),
        headers: _headers,
        body: jsonEncode({
          'amount': amountFcfa,
          'currency': 'XAF',
          'phone': msisdn,
          'reference': reference,
          'description': description,
        }));
    if (init.statusCode >= 300) {
      return PaymentResult(PaymentStatus.failed, reference, message: _messageOf(init));
    }
    final notchReference = referenceOf(init.body);
    if (notchReference == null) {
      return PaymentResult(PaymentStatus.failed, reference, message: 'missing transaction reference');
    }

    final charge = await _client.put(Uri.parse('$_base/payments/$notchReference'),
        headers: _headers,
        body: jsonEncode({
          'channel': operator.channel,
          'data': {'phone': msisdn, 'country': 'CM'},
        }));
    if (charge.statusCode >= 300) {
      return PaymentResult(PaymentStatus.failed, reference, message: _messageOf(charge));
    }

    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(pollInterval);
      final res = await _client.get(Uri.parse('$_base/payments/$notchReference'), headers: _headers);
      if (res.statusCode >= 300) continue;
      final status = statusOf(res.body);
      if (status != null) return PaymentResult(status, reference);
    }
    return PaymentResult(PaymentStatus.timeout, reference);
  }

  /// Référence Notch Pay (`transaction.reference`) de la réponse
  /// d'initialisation.
  static String? referenceOf(String body) {
    try {
      final json = jsonDecode(body);
      final tx = json is Map ? json['transaction'] : null;
      final ref = tx is Map ? tx['reference'] : null;
      return ref is String && ref.isNotEmpty ? ref : null;
    } catch (_) {
      return null;
    }
  }

  /// Statut final lu dans la réponse de `GET /payments/{reference}`, ou
  /// `null` tant que le paiement est en attente.
  static PaymentStatus? statusOf(String body) {
    try {
      final json = jsonDecode(body);
      final tx = json is Map ? json['transaction'] : null;
      final raw = (tx is Map ? tx['status'] : null)?.toString().toLowerCase();
      switch (raw) {
        case 'complete':
        case 'completed':
        case 'success':
          return PaymentStatus.success;
        case 'canceled':
        case 'cancelled':
          return PaymentStatus.canceled;
        case 'expired':
          return PaymentStatus.timeout;
        case 'failed':
        case 'rejected':
          return PaymentStatus.failed;
        case 'insufficient_funds':
          return PaymentStatus.insufficientFunds;
        default:
          return null; // pending / processing / inconnu : on attend
      }
    } catch (_) {
      return null;
    }
  }

  static String? _messageOf(http.Response res) {
    try {
      final json = jsonDecode(res.body);
      return json is Map ? json['message']?.toString() : null;
    } catch (_) {
      return null;
    }
  }
}
