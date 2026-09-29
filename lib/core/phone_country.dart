import 'package:country_picker/country_picker.dart';

/// Pays correspondant à l'indicatif international d'un numéro E.164
/// (ex. "+237650123456" → Cameroun), via `country_picker`, déjà utilisé par
/// PhoneField — aucune liste d'indicatifs maintenue à la main.
///
/// Ne sert qu'à PRÉREMPLIR le pays (zones de collecte) : jamais la ville ni
/// le quartier. `null` si le numéro est vide ou l'indicatif inconnu.
Country? countryFromPhone(String? phone) {
  final value = phone?.trim() ?? '';
  if (!value.startsWith('+')) return null;
  final digits = value.substring(1).replaceAll(RegExp(r'\D'), '');
  // Indicatifs de 1 à 3 chiffres : on cherche le plus long qui correspond,
  // pour qu'un indicatif court ("1") ne masque pas un plus précis ("237").
  for (var len = 3; len >= 1; len--) {
    if (digits.length < len) continue;
    final match = CountryService().findByPhoneCode(digits.substring(0, len));
    if (match != null) return match;
  }
  return null;
}
