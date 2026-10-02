import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/commission_service.dart';
import '../../services/payment_gateway.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/phone_field.dart';

/// Règlement de la commission due par Mobile Money (voir CommissionService).
/// Le Collecteur choisit son opérateur et son numéro, puis valide la demande
/// sur son téléphone — en mode test Notch Pay, ce sont les numéros de test
/// qui décident de l'issue (rappelés dans l'encadré).
class CommissionPaymentSheet extends StatefulWidget {
  final String collectorUid;
  final int amountFcfa;
  final bool fr;

  const CommissionPaymentSheet({
    super.key,
    required this.collectorUid,
    required this.amountFcfa,
    required this.fr,
  });

  static Future<PaymentResult?> show(BuildContext context,
          {required String collectorUid, required int amountFcfa, required bool fr}) =>
      showModalBottomSheet<PaymentResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => CommissionPaymentSheet(
            collectorUid: collectorUid, amountFcfa: amountFcfa, fr: fr),
      );

  @override
  State<CommissionPaymentSheet> createState() => _CommissionPaymentSheetState();
}

class _CommissionPaymentSheetState extends State<CommissionPaymentSheet> {
  final _service = CommissionService();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  /// Aucun opérateur présélectionné : le Collecteur doit choisir lui-même
  /// MTN ou Orange avant de payer.
  MobileMoneyOperator? _operator;
  bool _operatorMissing = false;
  String? _initialPhone;
  String _phone = '';
  bool _loadingProfile = true;
  bool _paying = false;
  PaymentResult? _result;

  bool get fr => widget.fr;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      final doc = await AuthService().fetchUserDocument(widget.collectorUid);
      final phone = doc.data()?['phone'] as String?;
      if (phone != null && phone.startsWith('+')) {
        _initialPhone = phone;
        _phone = phone;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingProfile = false);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_paying) return;
    final operator = _operator;
    final phoneOk = _formKey.currentState?.validate() ?? false;
    setState(() => _operatorMissing = operator == null);
    if (operator == null || !phoneOk) return;
    setState(() {
      _paying = true;
      _result = null;
    });
    final result = await _service.payCommission(
      collectorUid: widget.collectorUid,
      amountFcfa: widget.amountFcfa,
      phone: _phone,
      operator: operator,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _paying = false;
        _result = result;
      });
    }
  }

  String _failureText(PaymentResult r) {
    final base = switch (r.status) {
      PaymentStatus.insufficientFunds =>
        fr ? "Solde Mobile Money insuffisant." : "Insufficient Mobile Money balance.",
      PaymentStatus.timeout => fr
          ? "Pas de validation à temps sur le téléphone."
          : "The payment was not approved on the phone in time.",
      PaymentStatus.canceled => fr ? "Paiement annulé." : "Payment canceled.",
      _ => fr ? "Le paiement a échoué." : "The payment failed.",
    };
    return r.message == null ? base : "$base (${r.message})";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Text(fr ? "Payer la commission" : "Pay the commission",
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
            const SizedBox(height: 4),
            Text("${widget.amountFcfa} FCFA",
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.mainText)),
            const SizedBox(height: 12),
            _modeBanner(),
            const SizedBox(height: 16),
            Text(fr ? "OPÉRATEUR" : "OPERATOR",
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final op in MobileMoneyOperator.values)
                  ChoiceChip(
                    label: Text(op.label),
                    selected: _operator == op,
                    onSelected: _paying
                        ? null
                        : (_) => setState(() {
                              _operator = op;
                              _operatorMissing = false;
                            }),
                  ),
              ],
            ),
            if (_operatorMissing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    fr ? "Choisissez MTN ou Orange pour payer." : "Choose MTN or Orange to pay.",
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 14),
            if (_loadingProfile)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4),
              ))
            else
              PhoneField(
                controller: _phoneController,
                initialValue: _initialPhone,
                onChanged: (v) => _phone = v,
              ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(_failureText(_result!),
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            if (_paying)
              Row(
                children: [
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        fr
                            ? "Validez le paiement sur votre téléphone…"
                            : "Approve the payment on your phone…",
                        style: TextStyle(fontSize: 13, color: AppColors.mainText)),
                  ),
                ],
              )
            else
              GradientPillButton(
                label: fr ? "Payer ${widget.amountFcfa} FCFA" : "Pay ${widget.amountFcfa} FCFA",
                trailingIcon: Icons.lock_outline,
                onPressed: _pay,
              ),
          ],
        ),
      ),
    );
  }

  /// Rappelle qu'aucun argent réel ne circule, et les numéros de test qui
  /// décident de l'issue (voir SimulatedPaymentGateway / doc Notch Pay).
  Widget _modeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 18, color: AppColors.greenDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fr
                  ? "Mode test (${_service.gateway.modeLabel}) : aucun argent réel. "
                      "Numéros de test (MTN 670…, Orange 690…) : …000000 = succès, "
                      "…000002 = échec, …000004 = annulé."
                  : "Test mode (${_service.gateway.modeLabel}): no real money. "
                      "Test numbers (MTN 670…, Orange 690…): …000000 = success, "
                      "…000002 = failure, …000004 = canceled.",
              style: TextStyle(fontSize: 11.5, color: AppColors.mainText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
