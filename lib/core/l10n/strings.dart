import 'app_language.dart';

/// Toutes les chaînes de texte de l'application, en français et en anglais.
/// Utilisation : AppStrings.of(appLanguage.value).landingTagline
class AppStrings {
  final AppLanguage lang;
  const AppStrings._(this.lang);

  static AppStrings of(AppLanguage lang) => AppStrings._(lang);

  bool get _fr => lang == AppLanguage.fr;

  // ---- Onboarding ----
  String get onboardingSkip => _fr ? "Passer" : "Skip";
  String get onboardingNext => _fr ? "Suivant" : "Next";
  String get onboardingStart => _fr ? "Commencer" : "Get Started";

  String get slide1Title => _fr ? "Recyclez à votre façon" : "Recycle Your Way";
  String get slide1Subtitle => _fr
      ? "Repérez facilement les points de collecte à proximité ou planifiez un ramassage depuis chez vous."
      : "Easily locate nearby recycling stations or schedule a pickup from your doorstep.";

  String get slide2Title => _fr ? "Pesée et vérification" : "Weigh & Verified";
  String get slide2Subtitle => _fr
      ? "Faites peser vos recyclables et scannez le reçu pour vérifier instantanément votre dépôt."
      : "Get your recyclables weighed and scan the voucher to instantly verify your submission.";

  String get slide3Title =>
      _fr ? "Soyez payé instantanément" : "Get Paid Instantly";
  String get slide3Subtitle => _fr
      ? "Recevez un paiement immédiat en points pour chaque kg de déchets recyclables déposé."
      : "Receive immediate payment in points for every kg of recyclable waste you turn in.";

  String get slide4Title => _fr ? "Utilisez vos fonds" : "Use Your Funds";
  String get slide4Subtitle => _fr
      ? "Retirez directement vers votre portefeuille ou utilisez vos points pour payer factures et services."
      : "Withdraw directly to your wallet or use your points to pay for bills and services effortlessly.";

  String get slide5Title => _fr ? "Configuration rapide" : "Quick setup";
  String get slide5Subtitle => _fr
      ? "Activez les notifications et choisissez votre mode d'affichage."
      : "Turn on notifications and choose your display mode.";
  String get settingNotifications => _fr ? "Notifications" : "Notifications";
  String get settingDarkMode => _fr ? "Mode sombre" : "Dark mode";
  String get settingsNote => _fr
      ? "Vous pourrez modifier ces réglages à tout moment depuis les réglages."
      : "You can change these settings anytime from Settings.";

  // ---- Landing ----
  String get landingTaglineLine1 =>
      _fr ? "Un déchet au bon endroit," : "Waste in the right place,";
  String get landingTaglineLine2 =>
      _fr ? "c'est une ressource pour demain !" : "is tomorrow's resource!";
  String get landingDescription => _fr
      ? "EcoLindk connecte les ménages et les collecteurs pour valoriser les déchets grâce à la technologie et à l'IA."
      : "EcoLindk connects households and collectors to valorize waste through technology and AI.";
  String get alreadyHaveAccount => _fr ? "Connexion" : "Log In";
  String get landingCtaHint =>
      _fr ? "Prêt à faire la différence ?" : "Ready to make a difference?";

  // ---- Login ----
  String get loginTitle => _fr ? "Bienvenue ! 👋" : "Welcome! 👋";
  String get loginSubtitle =>
      _fr ? "Connectez-vous pour continuer." : "Log in to continue.";
  String get emailTab => _fr ? "Email" : "Email";
  String get phoneTab => _fr ? "Téléphone" : "Phone";
  String get continueWith => _fr ? "ou continuer avec" : "or continue with";
  String get phoneLabel => _fr ? "NUMÉRO DE TÉLÉPHONE" : "PHONE NUMBER";
  String get passwordLabel => _fr ? "MOT DE PASSE" : "PASSWORD";
  String get forgotPassword =>
      _fr ? "Mot de passe oublié ?" : "Forgot password?";
  String get resetPasswordEmailHint =>
      _fr ? "Votre email" : "Your email";
  String get sendResetLink => _fr ? "Envoyer le lien" : "Send link";
  String get resetLinkSent => _fr
      ? "Email de réinitialisation envoyé. Vérifiez votre boîte mail."
      : "Password reset email sent. Check your inbox.";
  String get logIn => _fr ? "Se connecter" : "Log In";
  String get or => _fr ? "OU" : "OR";
  String get newToApp =>
      _fr ? "Vous n'avez pas de compte ? " : "Don't have an account? ";
  String get createAccount => _fr ? "S'inscrire" : "Sign up";
  String get signUpAsHousehold => _fr
      ? "S'inscrire comme fournisseur de déchets"
      : "Sign up as waste provider";
  String get signUpAsCollector =>
      _fr ? "S'inscrire comme collecteur" : "Sign up as collector";

  String get noAccountForPhone => _fr
      ? "Aucun compte ne correspond à ce numéro."
      : "No account found for this phone number.";

  // ---- Register ----
  String get registerTitle => _fr ? "Créer un compte" : "Create an account";
  String get registerSubtitle => _fr
      ? "Rejoignez EcoLindk et faites partie du changement ! 🌱"
      : "Join EcoLindk and be part of the change! 🌱";
  String get signUpAs => _fr ? "SIGN UP AS" : "SIGN UP AS";
  String get roleHousehold => _fr ? "Fournisseur de déchets" : "Waste Provider";
  String get roleCollector => _fr ? "Collecteur" : "Collector";

  String get workStatusQuestion => _fr
      ? "Êtes-vous un collecteur indépendant ou travaillez-vous pour une entreprise ?"
      : "Are you an independent collector, or do you work for a company?";
  String get workStatusIndependent => _fr ? "Indépendant" : "Independent";
  String get workStatusCompany =>
      _fr ? "Je travaille pour une entreprise" : "I work for a company";
  String get companyNameOptional =>
      _fr ? "NOM DE L'ENTREPRISE (optionnel)" : "COMPANY NAME (optional)";
  String get companyNameHint => _fr
      ? "Utile uniquement à des fins statistiques"
      : "Used for analytics purposes only";

  String get fullName => _fr ? "NOM COMPLET" : "FULL NAME";
  String get firstName => _fr ? "PRÉNOM" : "FIRST NAME";
  String get lastName => _fr ? "NOM" : "LAST NAME";
  String get sex => _fr ? "SEXE" : "SEX";
  String get sexMale => _fr ? "Homme" : "Male";
  String get sexFemale => _fr ? "Femme" : "Female";
  String get dateOfBirth => _fr ? "DATE DE NAISSANCE" : "DATE OF BIRTH";
  String get dateOfBirthHint => _fr ? "JJ/MM/AAAA" : "DD/MM/YYYY";
  String get email => _fr ? "EMAIL" : "EMAIL";
  String get address => _fr ? "ADRESSE" : "ADDRESS";
  String get collectionZone => _fr ? "ZONE DE COLLECTE" : "COLLECTION ZONE";
  String get confirmPassword =>
      _fr ? "CONFIRMER LE MOT DE PASSE" : "CONFIRM PASSWORD";
  String get createMyAccount => _fr ? "S'inscrire" : "Sign up";
  String get alreadyAccount =>
      _fr ? "Vous avez déjà un compte ? " : "Already have an account? ";
  String get acceptTerms => _fr
      ? "J'accepte les Conditions d'utilisation et la Politique de confidentialité."
      : "I accept the Terms of Use and Privacy Policy.";

  String get collectorPendingNote => _fr
      ? "Après soumission, votre compte passe en statut « en attente ». L'administrateur vérifie votre demande avant activation."
      : "After submission, your account status becomes \"pending\". The administrator reviews your request before activation.";

  // ---- Register — formulaire en étapes ----
  String stepOf(int step, int total) =>
      _fr ? "Étape $step sur $total" : "Step $step of $total";
  String get next => _fr ? "Suivant" : "Next";
  String get back => _fr ? "Retour" : "Back";

  String get addressStepTitle =>
      _fr ? "Où habitez-vous ?" : "Where do you live?";
  String get addressStepSubtitle => _fr
      ? "Cette adresse nous aide à vous proposer les services les plus proches."
      : "This address helps us show you the services nearest to you.";

  String get phoneStepTitle =>
      _fr ? "Votre numéro de téléphone" : "Your phone number";
  String get phoneStepSubtitle => _fr
      ? "Optionnel — il nous sert à vous contacter au sujet de vos collectes."
      : "Optional — we'll use it to reach you about your pickups.";

  // ---- Choix du rôle (après création du compte) ----
  String get chooseRoleTitle => _fr
      ? "Comment allez-vous utiliser EcoLindk ?"
      : "How will you use EcoLindk?";
  String get chooseRoleSubtitle => _fr
      ? "Choisissez votre profil pour continuer."
      : "Choose your profile to continue.";

  // ---- Finalisation Collecteur ----
  String get collectorSetupTitle =>
      _fr ? "Informations Collecteur" : "Collector information";
  String get collectorSetupSubtitle => _fr
      ? "Encore une étape avant de commencer."
      : "One more step before you start.";
  String get finish => _fr ? "Terminer" : "Finish";

  // ---- Language picker ----
  String get chooseLanguage => _fr ? "Choisir la langue" : "Choose language";
  String get french => "Français";
  String get english => "English";

  // ---- Validation ----
  String get requiredField => _fr ? "Champ requis" : "Required field";
  String get passwordTooShort =>
      _fr ? "8 caractères minimum" : "Minimum 8 characters";
  String get passwordNeedsDigit => _fr
      ? "Le mot de passe doit contenir au moins un chiffre"
      : "Password must contain at least one number";
  String get confirmationRequired =>
      _fr ? "Confirmation requise" : "Confirmation required";

  // ---- Firebase Auth ----
  String get phoneLoginUnavailable => _fr
      ? "La connexion par téléphone n'est pas encore disponible. Utilisez l'onglet Email."
      : "Phone login isn't available yet. Please use the Email tab.";

  /// Traduit un code d'erreur FirebaseAuthException en message lisible.
  String authError(String code) {
    switch (code) {
      case 'user-not-found':
        return _fr
            ? "Aucun compte ne correspond à cet email."
            : "No account found for this email.";
      case 'wrong-password':
      case 'invalid-credential':
        return _fr
            ? "Email ou mot de passe incorrect."
            : "Incorrect email or password.";
      case 'invalid-email':
        return _fr ? "Adresse email invalide." : "Invalid email address.";
      case 'email-already-in-use':
        return _fr
            ? "Un compte existe déjà avec cet email."
            : "An account already exists with this email.";
      case 'weak-password':
        return _fr
            ? "Mot de passe trop faible (8 caractères minimum, avec au moins un chiffre)."
            : "Password is too weak (8 characters minimum, with at least one number).";
      case 'network-request-failed':
        return _fr
            ? "Problème de connexion réseau. Vérifiez votre connexion."
            : "Network error. Please check your connection.";
      case 'too-many-requests':
        return _fr
            ? "Trop de tentatives. Réessayez plus tard."
            : "Too many attempts. Please try again later.";
      case 'user-disabled':
        return _fr
            ? "Ce compte a été désactivé."
            : "This account has been disabled.";
      case 'operation-not-allowed':
        return _fr
            ? "La connexion par email/mot de passe n'est pas activée pour ce projet Firebase."
            : "Email/password sign-in isn't enabled for this Firebase project.";
      case 'requires-recent-login':
        return _fr
            ? "Reconnectez-vous puis réessayez."
            : "Please sign in again and retry.";
      default:
        return _fr
            ? "Une erreur est survenue. Réessayez."
            : "Something went wrong. Please try again.";
    }
  }

  // ---- Home Page ----
  String get greeting => _fr ? "Bonjour" : "Hello";
  String get homeSubtitle => _fr
      ? "Ensemble pour un monde plus propre."
      : "Together for a cleaner world.";
  String get homeSubtitleCollector => _fr
      ? "Gérez vos collectes et votre zone."
      : "Manage your pickups and your zone.";
  String get collectorTasksLabel => _fr ? "Collectes à faire" : "Pickups to do";
  String get collectorHistoryLabel => _fr ? "Historique" : "History";
  String get accountPendingBanner => _fr
      ? "Votre compte est en attente de vérification par un administrateur."
      : "Your account is pending verification by an administrator.";
  String get myPoints => _fr ? "Mes points" : "My points";
  String get viewProfile => _fr ? "Voir mon profil" : "View my profile";
  String get quickActions => _fr ? "Actions rapides" : "Quick actions";
  String get declareWaste => _fr ? "Déclarer un déchet" : "Declare waste";
  String get myPickups => _fr ? "Mes collectes" : "My pickups";
  String get recyclablesMarket =>
      _fr ? "Marché des recyclables" : "Recyclables market";
  String get recyclingCenters =>
      _fr ? "Centres de recyclage" : "Recycling centers";
  String get aiAssistant => _fr ? "Assistant IA" : "AI Assistant";
  String get aiAssistantDesc => _fr
      ? "Posez vos questions sur le recyclage et la valorisation."
      : "Ask your questions about recycling and valorisation.";
  String get myImpact => _fr ? "Mon impact" : "My impact";
  String get pickups => _fr ? "Collectes" : "Pickups";
  String get wasteValorised => _fr ? "Déchets valorisés" : "Waste valorised";
  String get treesSaved => _fr ? "Arbres sauvés" : "Trees saved";
  // ---- Profil / Compte ----
  String get workStatusLabel => _fr ? "STATUT" : "STATUS";
  String get statusVerified => _fr ? "Vérifié" : "Verified";
  String get statusPending => _fr ? "En attente" : "Pending";
  String get logout => _fr ? "Se déconnecter" : "Log out";
  String get logoutConfirmTitle => _fr ? "Se déconnecter ?" : "Log out?";
  String get logoutConfirmMessage => _fr
      ? "Vous devrez vous reconnecter pour accéder à votre compte."
      : "You'll need to sign in again to access your account.";
  String get cancel => _fr ? "Annuler" : "Cancel";

  String get navHome => _fr ? "Accueil" : "Home";
  String get navPickups => _fr ? "Collectes" : "Pickups";
  String get navMessages => _fr ? "Messages" : "Messages";
  String get navSettings => _fr ? "Réglages" : "Settings";
  String get navNotifications => _fr ? "Notifications" : "Notifications";
  String get navWallet => _fr ? "Portefeuille" : "Wallet";

  // ---- Réglages (hub) ----
  String get settingsTitle => _fr ? "Réglages" : "Settings";
  String get settingsRowSecurity => _fr ? "Sécurité" : "Security";
  String get settingsRowSecuritySubtitle =>
      _fr ? "Mot de passe" : "Password";
  String get settingsRowNotifications => _fr ? "Notifications" : "Notifications";
  String get settingsRowNotificationsSubtitle =>
      _fr ? "Autorisations de notification" : "Notification permissions";
  String get settingsRowAppearance =>
      _fr ? "Mode d'affichage" : "Appearance mode";
  String get settingsRowAppearanceSubtitle =>
      _fr ? "Thème clair ou sombre" : "Light or dark theme";
  String get settingsRowAccount => _fr ? "Compte" : "Account";
  String get settingsRowAccountSubtitle => _fr
      ? "Infos, déconnexion, suppression"
      : "Info, logout, deletion";

  // ---- Réglages — Sécurité ----
  String get securityTitle => _fr ? "Sécurité" : "Security";
  String get securityChangePassword =>
      _fr ? "Changer le mot de passe" : "Change password";
  String get currentPasswordLabel =>
      _fr ? "MOT DE PASSE ACTUEL" : "CURRENT PASSWORD";
  String get newPasswordLabel =>
      _fr ? "NOUVEAU MOT DE PASSE" : "NEW PASSWORD";
  String get confirmNewPasswordLabel =>
      _fr ? "CONFIRMER LE NOUVEAU MOT DE PASSE" : "CONFIRM NEW PASSWORD";
  String get passwordsDontMatch => _fr
      ? "Les mots de passe ne correspondent pas."
      : "Passwords don't match.";
  String get passwordChanged =>
      _fr ? "Mot de passe mis à jour." : "Password updated.";

  // ---- Réglages — Notifications ----
  String get notificationsTitle => _fr ? "Notifications" : "Notifications";
  String get notificationsDesc => _fr
      ? "Recevez des alertes pour vos collectes et le statut de votre compte."
      : "Get alerts about your pickups and your account status.";

  // ---- Réglages — Apparence ----
  String get appearanceTitle => _fr ? "Mode d'affichage" : "Appearance mode";
  String get appearanceDesc => _fr
      ? "Choisissez comment EcoLindk s'affiche sur cet appareil."
      : "Choose how EcoLindk looks on this device.";

  // ---- Réglages — Compte ----
  String get accountTitle => _fr ? "Compte" : "Account";
  String get dangerZone => _fr ? "ZONE DE DANGER" : "DANGER ZONE";
  String get deleteAccount => _fr ? "Supprimer le compte" : "Delete account";
  String get deleteAccountWarning => _fr
      ? "Cette action est définitive : votre compte et toutes vos données seront supprimés."
      : "This is permanent: your account and all your data will be deleted.";
  String get deleteAccountConfirmTitle =>
      _fr ? "Supprimer votre compte ?" : "Delete your account?";
  String get enterPasswordToConfirm => _fr
      ? "Entrez votre mot de passe pour confirmer."
      : "Enter your password to confirm.";
  String get confirmWithGoogleToDelete => _fr
      ? "Vous êtes connecté avec Google — confirmez avec Google pour supprimer votre compte."
      : "You're signed in with Google — confirm with Google to delete your account.";
  String get deleteAccountAction =>
      _fr ? "Supprimer définitivement" : "Delete permanently";

  // ---- Modifier le profil ----
  String get editProfileTitle => _fr ? "Modifier le profil" : "Edit profile";
  String get profileUpdated =>
      _fr ? "Profil mis à jour." : "Profile updated.";
  String get saveChanges => _fr ? "Enregistrer" : "Save";
}
