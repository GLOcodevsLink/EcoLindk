/// Règles de validation des champs saisis par l'utilisateur, partagées par
/// tous les formulaires (et revérifiées côté service pour les données qui
/// comptent : quantité d'un post, poids et prix d'une collecte). Chaque
/// fonction renvoie le message d'erreur à afficher, ou `null` si la valeur
/// est acceptable.
class Validators {
  const Validators._();

  /// Quantité minimale d'un post : en dessous, une collecte n'en vaut pas le
  /// déplacement.
  static const double minPostWeightKg = 1;

  /// Quantité maximale d'un post (au-delà, saisie manifestement erronée).
  static const double maxPostWeightKg = 500;

  /// Prix maximal payé pour une collecte, en FCFA.
  static const double maxCollectionPriceFcfa = 1000000;

  static final _letters = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ]");
  static final _nameChars = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");
  static final _email = RegExp(r"^[^\s@]+@[^\s@]+\.[A-Za-z]{2,}$");

  /// Prénom ou nom : 2 à 40 caractères, lettres, espaces, apostrophes et
  /// tirets uniquement.
  static String? personName(String? value, {required bool fr}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return fr ? "Champ requis" : "Required field";
    if (v.length < 2) return fr ? "Au moins 2 lettres" : "At least 2 letters";
    if (v.length > 40) return fr ? "40 caractères maximum" : "40 characters maximum";
    if (!_nameChars.hasMatch(v)) {
      return fr ? "Lettres uniquement (pas de chiffres ni de symboles)" : "Letters only (no numbers or symbols)";
    }
    return null;
  }

  /// Adresse email au bon format.
  static String? email(String? value, {required bool fr}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return fr ? "Champ requis" : "Required field";
    if (v.length > 100 || !_email.hasMatch(v)) {
      return fr ? "Adresse email invalide" : "Invalid email address";
    }
    return null;
  }

  /// Numéro complet (E.164, ex. +237650123456). Cameroun : 9 chiffres
  /// commençant par 6 ou 2 ; autres pays : 7 à 12 chiffres.
  static String? phone(String? fullNumber, {required bool fr}) {
    final v = fullNumber?.replaceAll(RegExp(r'\s'), '') ?? '';
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(v)) {
      return fr ? "Entrez un numéro de téléphone valide." : "Enter a valid phone number.";
    }
    if (v.startsWith('+237')) {
      final national = v.substring(4);
      if (!RegExp(r'^[62]\d{8}$').hasMatch(national)) {
        return fr
            ? "Numéro camerounais invalide : 9 chiffres, commençant par 6 ou 2."
            : "Invalid Cameroonian number: 9 digits, starting with 6 or 2.";
      }
    }
    return null;
  }

  /// Nom d'entreprise (facultatif) : vide, ou 2 à 60 caractères contenant
  /// au moins une lettre.
  static String? companyName(String? value, {required bool fr}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < 2 || v.length > 60 || !_letters.hasMatch(v)) {
      return fr ? "Nom d'entreprise invalide (2 à 60 caractères)" : "Invalid company name (2 to 60 characters)";
    }
    return null;
  }

  /// Description d'un déchet : 10 à 300 caractères, avec de vrais mots.
  static String? wasteDescription(String? value, {required bool fr}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return fr ? "La description est obligatoire." : "A description is required.";
    if (v.length < 10 || _letters.allMatches(v).length < 5) {
      return fr
          ? "Décrivez le déchet en quelques mots (10 caractères minimum)."
          : "Describe the waste in a few words (10 characters minimum).";
    }
    if (v.length > 300) return fr ? "300 caractères maximum." : "300 characters maximum.";
    return null;
  }

  /// Quantité d'un post, en kg : entre [minPostWeightKg] et
  /// [maxPostWeightKg].
  static String? postQuantity(double? kg, {required bool fr}) {
    if (kg == null || kg <= 0) return fr ? "Indiquez la quantité, en kg." : "Enter the quantity, in kg.";
    if (kg < minPostWeightKg) {
      return fr
          ? "Quantité insuffisante : ${minPostWeightKg.toStringAsFixed(0)} kg minimum pour une collecte."
          : "Quantity too small: ${minPostWeightKg.toStringAsFixed(0)} kg minimum for a pickup.";
    }
    if (kg > maxPostWeightKg) {
      return fr
          ? "Quantité trop élevée : ${maxPostWeightKg.toStringAsFixed(0)} kg maximum par post."
          : "Quantity too large: ${maxPostWeightKg.toStringAsFixed(0)} kg maximum per post.";
    }
    return null;
  }

  /// Prix payé au fournisseur pour une collecte, en FCFA.
  static String? collectionPrice(double? fcfa, {required bool fr}) {
    if (fcfa == null || fcfa <= 0) return fr ? "Entrez un prix valide, en FCFA." : "Enter a valid price, in FCFA.";
    if (fcfa > maxCollectionPriceFcfa) {
      return fr ? "Prix trop élevé pour une collecte." : "Price too high for a pickup.";
    }
    return null;
  }
}
