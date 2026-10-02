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

/// Normalizes a phone number to E.164 (e.g. "+237690000000"), assuming
/// Cameroon when no country code is given. Returns `null` when the input
/// cannot be a valid number.
///
/// Registration already saves E.164 (see PhoneField / Validators.phone);
/// this guards older or hand-edited values before they reach the dialer.
String? normalizePhoneE164(String? raw) {
  final String value = (raw ?? '').replaceAll(RegExp(r'[\s\-().]'), '');
  if (value.isEmpty) return null;
  String digits;
  if (value.startsWith('+')) {
    digits = value.substring(1);
  } else if (value.startsWith('00')) {
    digits = value.substring(2);
  } else if (RegExp(r'^237[62]\d{8}$').hasMatch(value)) {
    digits = value;
  } else if (RegExp(r'^[62]\d{8}$').hasMatch(value)) {
    digits = '237$value'; // Cameroonian national number without +237
  } else {
    return null;
  }
  if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) return null;
  return '+$digits';
}
