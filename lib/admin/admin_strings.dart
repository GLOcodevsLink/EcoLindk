import '../core/l10n/app_language.dart';

/// Chaînes du tableau de bord administrateur (web), en français et en
/// anglais — séparées de AppStrings pour ne rien ajouter à l'app mobile.
/// Utilisation : AdminStrings.of(appLanguage.value).navOverview
class AdminStrings {
  final AppLanguage lang;
  const AdminStrings._(this.lang);

  static AdminStrings of(AppLanguage lang) => AdminStrings._(lang);

  bool get fr => lang == AppLanguage.fr;

  // ---- Connexion / accès ----
  String get appTitle => "EcoLindk Admin";
  String get signInTitle => fr ? "Espace administrateur" : "Admin console";
  String get signInSubtitle =>
      fr ? "Connectez-vous avec un compte administrateur." : "Sign in with an administrator account.";
  String get email => "Email";
  String get password => fr ? "Mot de passe" : "Password";
  String get signIn => fr ? "Se connecter" : "Sign in";
  String get signOut => fr ? "Se déconnecter" : "Sign out";
  String get badCredentials => fr ? "Email ou mot de passe incorrect." : "Incorrect email or password.";
  String get signInFailed => fr ? "Connexion impossible. Réessayez." : "Could not sign in. Try again.";
  String get notAdminTitle => fr ? "Accès refusé" : "Access denied";
  String notAdminBody(String email) => fr
      ? "Le compte $email n'est pas administrateur. Un administrateur existant doit créer le document admins/<uid> dans la console Firebase."
      : "The account $email is not an administrator. An existing administrator must create the admins/<uid> document in the Firebase console.";
  String get accessCheckFailed => fr
      ? "Impossible de vérifier vos droits. Les règles Firestore sont-elles déployées ?"
      : "Could not check your access. Are the Firestore rules deployed?";
  String get accessCheckTitle => fr ? "Vérification impossible" : "Access check failed";
  String get retry => fr ? "Réessayer" : "Retry";

  // ---- Navigation ----
  String get navOverview => fr ? "Vue d'ensemble" : "Overview";
  String get navProviders => fr ? "Fournisseurs" : "Waste providers";
  String get navCollectors => fr ? "Collecteurs" : "Collectors";
  String get navPosts => fr ? "Posts de déchets" : "Waste posts";
  String get navCollections => fr ? "Collectes" : "Collections";
  String get navPayments => fr ? "Paiements" : "Payments";
  String get darkMode => fr ? "Mode sombre" : "Dark mode";
  String get language => fr ? "English" : "Français";

  // ---- Commun ----
  String get loading => fr ? "Chargement…" : "Loading…";
  String get search => fr ? "Rechercher" : "Search";
  String get all => fr ? "Tous" : "All";
  String get noResults => fr ? "Aucun résultat." : "No results.";
  String get close => fr ? "Fermer" : "Close";
  String get cancel => fr ? "Annuler" : "Cancel";
  String get unknown => fr ? "Inconnu" : "Unknown";
  String get previous => fr ? "Précédent" : "Previous";
  String get next => fr ? "Suivant" : "Next";
  String pageOf(int from, int to, int total) => "$from–$to / $total";
  String loadError(String detail) => fr
      ? "Lecture impossible ($detail). Vérifiez que les règles Firestore sont déployées."
      : "Could not load data ($detail). Check that the Firestore rules are deployed.";

  // ---- Colonnes ----
  String get colName => fr ? "Nom" : "Name";
  String get colContact => "Contact";
  String get colJoined => fr ? "Inscrit le" : "Joined";
  String get colPosts => "Posts";
  String get colCompleted => fr ? "Terminées" : "Completed";
  String get colKg => fr ? "Kg collectés" : "Kg collected";
  String get colPoints => fr ? "Solde (pts)" : "Balance (pts)";
  String get colType => "Type";
  String get colZones => "Zones";
  String get colRating => fr ? "Note" : "Rating";
  String get colOutstanding => fr ? "Commission due" : "Commission due";
  String get colReference => fr ? "Référence" : "Reference";
  String get colProvider => fr ? "Fournisseur" : "Provider";
  String get colCollector => fr ? "Collecteur" : "Collector";
  String get colCategory => fr ? "Catégorie" : "Category";
  String get colStatus => fr ? "Statut" : "Status";
  String get colWeight => fr ? "Poids" : "Weight";
  String get colValue => fr ? "Valeur" : "Value";
  String get colCommission => "Commission";
  String get colDate => "Date";
  String get colAmount => fr ? "Montant" : "Amount";
  String get colOperator => fr ? "Opérateur" : "Operator";
  String get colMode => "Mode";
  String get colMethod => fr ? "Moyen" : "Method";
  String get colPhone => fr ? "Téléphone" : "Phone";
  String get colMessage => "Message";

  // ---- Vue d'ensemble ----
  String get overviewSubtitle =>
      fr ? "Activité de la plateforme, en temps réel." : "Platform activity, live.";
  String get kpiProviders => fr ? "Fournisseurs" : "Waste providers";
  String get kpiCollectors => fr ? "Collecteurs" : "Collectors";
  String get kpiOpenPosts => fr ? "Posts en attente" : "Open posts";
  String get kpiCompleted => fr ? "Collectes terminées" : "Completed collections";
  String get kpiKg => fr ? "Déchets collectés" : "Waste collected";
  String get kpiValue => fr ? "Valeur des collectes" : "Collection value";
  String get kpiOutstanding => fr ? "Commissions à encaisser" : "Commission outstanding";
  String get kpiPoints => fr ? "Points distribués" : "Points awarded";
  String incompleteAccounts(int n) =>
      fr ? "+ $n compte(s) sans rôle" : "+ $n account(s) without a role";
  String completionRate(int pct) => fr ? "$pct % des posts aboutissent" : "$pct% of posts completed";
  String paidOf(String paid) => fr ? "$paid déjà payés" : "$paid already paid";
  String get chartPostsPerDay => fr ? "Posts publiés — 14 derniers jours" : "Posts published — last 14 days";
  String get chartKgByCategory => fr ? "Kg collectés par catégorie" : "Kg collected by category";
  String get statusBreakdown => fr ? "Posts par statut" : "Posts by status";
  String get recentPosts => fr ? "Derniers posts" : "Latest posts";
  String get noCollectedYet => fr ? "Aucune collecte terminée pour l'instant." : "No completed collection yet.";
  String postsOnDay(int n, String day) => fr ? "$n post(s) le $day" : "$n post(s) on $day";
  String get showTable => fr ? "Voir le tableau" : "Show table";
  String get showChart => fr ? "Voir le graphique" : "Show chart";

  // ---- Utilisateurs ----
  String get providersSubtitle =>
      fr ? "Ménages et entreprises qui publient des déchets." : "Households and businesses posting waste.";
  String get collectorsSubtitle =>
      fr ? "Collecteurs indépendants et d'entreprise." : "Independent and company collectors.";
  String get independent => fr ? "Indépendant" : "Independent";
  String get company => fr ? "Entreprise" : "Company";
  String get phoneVerified => fr ? "Téléphone vérifié" : "Phone verified";
  String get address => fr ? "Adresse" : "Address";
  String get zonesTitle => fr ? "Zones de collecte" : "Collection zones";
  String get noZones => fr ? "Aucune zone enregistrée." : "No zone saved.";
  String get historyTitle => fr ? "Historique" : "History";
  String get paymentsTitle => fr ? "Règlements de commission" : "Commission payments";
  String get noPayments => fr ? "Aucun règlement." : "No payment.";
  String get lifetimePoints => fr ? "Points gagnés au total" : "Lifetime points";
  String ratingOf(String avg, int n) => fr ? "$avg/5 ($n avis)" : "$avg/5 ($n reviews)";
  String get noRating => fr ? "Pas encore noté" : "Not rated yet";

  // ---- Posts ----
  String get postsSubtitle =>
      fr ? "Toutes les demandes de collecte publiées." : "Every collection request posted.";
  String get allCategories => fr ? "Toutes catégories" : "All categories";
  String get aiSuggested => fr ? "IA" : "AI";
  String aiConfidence(int pct) => fr ? "confiance $pct %" : "$pct% confidence";
  String get approxLocation => fr ? "position approximative" : "approximate location";
  String get removePost => fr ? "Retirer le post" : "Remove post";
  String get removePostTitle => fr ? "Retirer ce post ?" : "Remove this post?";
  String get removePostBody => fr
      ? "Le post passera au statut « Annulée » : il ne sera plus proposé aux collecteurs. Le Fournisseur le verra comme annulé."
      : "The post will be set to “Cancelled” and no longer offered to collectors. The provider will see it as cancelled.";
  String get removed => fr ? "Post retiré." : "Post removed.";
  String get removeFailed =>
      fr ? "Impossible de retirer ce post (il a peut-être déjà été accepté)." : "Could not remove this post (it may have just been accepted).";

  // ---- Collectes ----
  String get collectionsSubtitle =>
      fr ? "Demandes prises en charge par un collecteur." : "Requests taken by a collector.";
  String get awaitingWeight => fr ? "Poids soumis, en attente" : "Weight submitted, pending";

  // ---- Paiements ----
  String get paymentsSubtitle => fr
      ? "Commissions réglées par les collecteurs et conversions de points des fournisseurs."
      : "Commissions paid by collectors and points converted by providers.";
  String get tabCommissions => fr ? "Commissions" : "Commissions";
  String get tabRedemptions => fr ? "Conversions de points" : "Points conversions";
  String get testModeNote => fr
      ? "Mode test : simulation ou Notch Pay sandbox, aucun argent réel. Le statut est constaté par l'app."
      : "Test mode: simulation or Notch Pay sandbox, no real money. Status is recorded by the app.";
  String get totalPaid => fr ? "Total encaissé" : "Total collected";
  String get totalFailed => fr ? "Paiements échoués" : "Failed payments";
  String get totalPending => fr ? "En attente" : "Pending";
  String get totalRedeemed => fr ? "Total converti" : "Total converted";
  String paymentStatus(String status) => switch (status) {
        'success' => fr ? "Réussi" : "Success",
        'pending' => fr ? "En attente" : "Pending",
        'insufficientFunds' => fr ? "Fonds insuffisants" : "Insufficient funds",
        'timeout' => fr ? "Délai dépassé" : "Timed out",
        'canceled' => fr ? "Annulé" : "Canceled",
        'failed' => fr ? "Échoué" : "Failed",
        'completed' => fr ? "Effectué" : "Completed",
        _ => status,
      };
  String redemptionMethod(String method) => switch (method) {
        'airtime' => fr ? "Crédit d'appel" : "Airtime",
        'mobileData' => fr ? "Forfait internet" : "Mobile data",
        'withdrawal' => fr ? "Retrait" : "Withdrawal",
        'sendToRelative' => fr ? "Envoi à un proche" : "Sent to relative",
        _ => method,
      };
}
