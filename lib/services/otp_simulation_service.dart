import 'dart:math';

/// Résultat de la saisie d'un code OTP (voir [SimulatedOtpService.verify]).
enum OtpCheck { valid, invalid, expired, tooManyAttempts, noCode }

/// **Simulation** de vérification du téléphone par SMS, à l'inscription.
///
/// Un vrai envoi de SMS passe par Firebase Phone Auth ou un fournisseur
/// (Twilio, Orange SMS API…), donc par un service payant : pas encore
/// branché. En attendant, le code est généré ici, sur l'appareil, et affiché
/// à l'écran comme un faux SMS (voir OtpVerificationScreen). Tout le reste
/// se comporte comme un vrai OTP : 6 chiffres, expiration, nombre d'essais
/// limité, délai avant de redemander un code. Pour passer au vrai SMS, seul
/// [send] change.
class SimulatedOtpService {
  SimulatedOtpService({Random? random, DateTime Function()? now})
      : _random = random ?? Random.secure(),
        _now = now ?? DateTime.now;

  static const codeLength = 6;
  static const validity = Duration(minutes: 5);
  static const resendCooldown = Duration(seconds: 30);
  static const maxAttempts = 5;

  final Random _random;
  final DateTime Function() _now;

  String? _code;
  DateTime? _sentAt;
  int _attempts = 0;

  /// "Envoie" un nouveau code (l'ancien devient invalide) et le renvoie,
  /// pour l'afficher comme un SMS reçu.
  String send() {
    _code = List.generate(codeLength, (_) => _random.nextInt(10)).join();
    _sentAt = _now();
    _attempts = 0;
    return _code!;
  }

  /// Temps restant avant de pouvoir redemander un code ([Duration.zero] si
  /// c'est déjà possible).
  Duration get resendWait {
    final sentAt = _sentAt;
    if (sentAt == null) return Duration.zero;
    final left = resendCooldown - _now().difference(sentAt);
    return left.isNegative ? Duration.zero : left;
  }

  int get attemptsLeft => maxAttempts - _attempts;

  OtpCheck verify(String input) {
    final code = _code;
    final sentAt = _sentAt;
    if (code == null || sentAt == null) return OtpCheck.noCode;
    if (_attempts >= maxAttempts) return OtpCheck.tooManyAttempts;
    if (_now().difference(sentAt) > validity) return OtpCheck.expired;
    _attempts++;
    if (input.trim() != code) {
      return _attempts >= maxAttempts ? OtpCheck.tooManyAttempts : OtpCheck.invalid;
    }
    // Un code ne sert qu'une fois.
    _code = null;
    return OtpCheck.valid;
  }
}
