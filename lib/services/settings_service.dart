import 'package:shared_preferences/shared_preferences.dart';

/// Persiste les réglages "rapides" proposés sur la dernière slide de
/// l'onboarding (et modifiables ensuite depuis les réglages) : mode sombre,
/// notifications. Stockés localement (SharedPreferences) — ce sont des
/// préférences d'appareil, pas des données de compte.
class SettingsService {
  static const _kDarkMode = 'settings.darkMode';
  static const _kNotifications = 'settings.notifications';
  static const _kLastLoginMethod = 'login.lastMethod'; // 'email' | 'phone'
  static const _kLastPhone = 'login.lastPhone'; // E.164, ex: "+237650123456"
  static const _kRecentEmails = 'login.recentEmails'; // plus récent d'abord

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// `null` si jamais réglé (première ouverture) : l'appelant garde alors le
  /// thème par défaut plutôt que de forcer une valeur.
  Future<bool?> loadDarkMode() async => (await _prefs).getBool(_kDarkMode);

  Future<void> saveDarkMode(bool value) async =>
      (await _prefs).setBool(_kDarkMode, value);

  Future<bool> loadNotifications() async =>
      (await _prefs).getBool(_kNotifications) ?? true;

  Future<void> saveNotifications(bool value) async =>
      (await _prefs).setBool(_kNotifications, value);

  // -------------------------------------------------------------------
  // Connexion — jamais le mot de passe :
  // - Téléphone : dernier numéro utilisé, pré-rempli à l'ouverture (avec
  //   l'onglet Téléphone présélectionné) — voir LoginScreen._loadRememberedLogin.
  // - Email : PAS de pré-remplissage automatique. On garde un petit
  //   historique (5 max, plus récent en premier) que LoginScreen propose en
  //   suggestions au fur et à mesure que l'utilisateur tape (RawAutocomplete),
  //   jamais rempli tout seul à l'ouverture de l'écran.
  // -------------------------------------------------------------------

  static const _maxRecentEmails = 5;

  Future<String?> loadLastLoginMethod() async =>
      (await _prefs).getString(_kLastLoginMethod);

  Future<String?> loadLastPhone() async =>
      (await _prefs).getString(_kLastPhone);

  Future<List<String>> loadRecentEmails() async =>
      (await _prefs).getStringList(_kRecentEmails) ?? const [];

  Future<void> rememberEmailLogin(String email) async {
    final prefs = await _prefs;
    await prefs.setString(_kLastLoginMethod, 'email');
    final normalized = email.trim();
    if (normalized.isEmpty) return;
    final current = prefs.getStringList(_kRecentEmails) ?? <String>[];
    current.removeWhere((e) => e.toLowerCase() == normalized.toLowerCase());
    current.insert(0, normalized);
    if (current.length > _maxRecentEmails) {
      current.removeRange(_maxRecentEmails, current.length);
    }
    await prefs.setStringList(_kRecentEmails, current);
  }

  Future<void> rememberPhoneLogin(String phone) async {
    final prefs = await _prefs;
    await prefs.setString(_kLastLoginMethod, 'phone');
    await prefs.setString(_kLastPhone, phone);
  }
}
