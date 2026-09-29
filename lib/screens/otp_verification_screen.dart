import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/l10n/app_language.dart';
import '../core/theme.dart';
import '../services/otp_simulation_service.dart';
import '../widgets/decorative_leaves.dart';
import '../widgets/gradient_pill_button.dart';

/// Vérification du numéro de téléphone à l'inscription, par code OTP à 6
/// chiffres — **simulée** : aucun SMS n'est réellement envoyé (voir
/// SimulatedOtpService). Le code "reçu" s'affiche en haut de l'écran, dans
/// une carte qui imite une notification SMS et le dit clairement.
///
/// Se ferme avec `true` quand le bon code a été saisi, `false`/`null` si
/// l'utilisateur revient en arrière.
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otp = SimulatedOtpService();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  String? _simulatedSms; // code affiché dans la fausse notification SMS
  String? _error;
  bool _blocked = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sendCode();
    // Rafraîchit le compte à rebours "Renvoyer le code".
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _sendCode() {
    final code = _otp.send();
    setState(() {
      _simulatedSms = code;
      _error = null;
      _blocked = false;
      _codeCtrl.clear();
    });
  }

  void _verify(bool fr) {
    final input = _codeCtrl.text;
    if (input.length != SimulatedOtpService.codeLength) {
      setState(() => _error = fr
          ? "Entrez les 6 chiffres du code."
          : "Enter the 6-digit code.");
      return;
    }
    switch (_otp.verify(input)) {
      case OtpCheck.valid:
        Navigator.of(context).pop(true);
      case OtpCheck.invalid:
        final left = _otp.attemptsLeft;
        setState(() {
          _error = fr
              ? "Code incorrect. $left essai${left > 1 ? 's' : ''} restant${left > 1 ? 's' : ''}."
              : "Wrong code. $left attempt${left > 1 ? 's' : ''} left.";
          _codeCtrl.clear();
        });
      case OtpCheck.expired:
        setState(() => _error = fr
            ? "Ce code a expiré. Demandez-en un nouveau."
            : "This code has expired. Request a new one.");
      case OtpCheck.tooManyAttempts:
        setState(() {
          _blocked = true;
          _error = fr
              ? "Trop d'essais. Demandez un nouveau code."
              : "Too many attempts. Request a new code.";
        });
      case OtpCheck.noCode:
        setState(() => _error = fr
            ? "Demandez un nouveau code."
            : "Request a new code.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        final wait = _otp.resendWait;
        return Scaffold(
          body: Stack(
            children: [
              const DecorativeLeaves(subtle: true),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: Icon(Icons.arrow_back, color: AppColors.heading),
                      ),
                    ),
                    if (_simulatedSms != null) _smsCard(_simulatedSms!, fr),
                    const SizedBox(height: 22),
                    Text(fr ? "Vérifiez votre numéro" : "Verify your number",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText)),
                    const SizedBox(height: 6),
                    Text(
                        fr
                            ? "Entrez le code à 6 chiffres envoyé au ${widget.phoneNumber}."
                            : "Enter the 6-digit code sent to ${widget.phoneNumber}.",
                        style: TextStyle(fontSize: 13, color: AppColors.textGray, height: 1.4)),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _codeCtrl,
                      focusNode: _codeFocus,
                      autofocus: true,
                      enabled: !_blocked,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: SimulatedOtpService.codeLength,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 14,
                          color: AppColors.mainText),
                      decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                      onChanged: (v) {
                        if (_error != null) setState(() => _error = null);
                        if (v.length == SimulatedOtpService.codeLength) _verify(fr);
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 22),
                    GradientPillButton(
                      label: fr ? "Vérifier" : "Verify",
                      onPressed: _blocked ? _sendCode : () => _verify(fr),
                      gradient: AppColors.authButtonGradient,
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: wait == Duration.zero ? _sendCode : null,
                        child: Text(
                          wait == Duration.zero
                              ? (fr ? "Renvoyer le code" : "Resend code")
                              : (fr
                                  ? "Renvoyer le code (${wait.inSeconds + 1} s)"
                                  : "Resend code (${wait.inSeconds + 1}s)"),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: wait == Duration.zero
                                  ? AppColors.greenMid
                                  : AppColors.textGray),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fausse notification SMS : le seul endroit où le code apparaît, avec la
  /// mention explicite qu'il s'agit d'une simulation.
  Widget _smsCard(String code, bool fr) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(code),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -16 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  gradient: AppColors.logoGradient, shape: BoxShape.circle),
              child: const Icon(Icons.sms_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("EcoLindk",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mainText)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(fr ? "SMS simulé" : "Simulated SMS",
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.heading)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13, color: AppColors.mainText, height: 1.35),
                      children: [
                        TextSpan(text: fr ? "Votre code de vérification est " : "Your verification code is "),
                        TextSpan(
                            text: code,
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        TextSpan(text: fr ? ". Il expire dans 5 minutes." : ". It expires in 5 minutes."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      fr
                          ? "Démonstration : aucun SMS réel n'est envoyé pour l'instant."
                          : "Demo: no real SMS is sent yet.",
                      style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
