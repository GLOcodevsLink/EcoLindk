/// Résultat de la saisie d'un code OTP (voir [SimulatedOtpService.verify]).
enum OtpCheck { valid, invalid, expired, tooManyAttempts, noCode }

/// **Simulation** de vérification du téléphone par SMS, à l'inscription.
///
/// Un vrai envoi de SMS passe par Firebase Phone Auth ou un fournisseur
/// (Twilio, Orange SMS API…), donc par un service payant : pas encore
/// branché. En attendant, le code attendu est FIXE ([verificationCode],
/// comme les "numéros de test" de Firebase) et n'est jamais affiché à
/// l'utilisateur. Tout le reste se comporte comme un vrai OTP : expiration,
/// nombre d'essais limité, délai avant de redemander un code. Pour passer au
/// vrai SMS, seul [send] change.
class SimulatedOtpService {
  SimulatedOtpService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Code à saisir pour valider le numéro.
  static const verificationCode = '123456';

  static const codeLength = 6;
  static const validity = Duration(minutes: 5);
  static const resendCooldown = Duration(seconds: 30);
  static const maxAttempts = 5;

  final DateTime Function() _now;

  String? _code;
  DateTime? _sentAt;
  int _attempts = 0;

  /// "Envoie" le code (délai et essais remis à zéro) et le renvoie.
  String send() {
    _code = verificationCode;
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
