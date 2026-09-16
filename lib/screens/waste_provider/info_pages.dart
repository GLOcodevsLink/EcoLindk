import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';

/// Trois pages d'information statiques pour le Fournisseur de déchets,
/// regroupées ici car courtes et sans état : Comment ça marche, Taux de
/// conversion, Liste des prix de référence. Toutes les trois lisent
/// [RewardsConfig] — le même barème unique que Wallet/Redeem/CollectionService,
/// jamais un chiffre recalculé indépendamment ici.

class _InfoScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const DecorativeLeaves(subtle: true),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.arrow_back, color: AppColors.heading),
                        ),
                      ),
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.heading)),
                      ),
                    ],
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Décrit globalement le parcours du Fournisseur de déchets dans l'app —
/// ouverte depuis l'accueil et depuis Réglages > Profil.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        // `image` : illustration recadrée directement depuis la capture de
        // référence fournie par l'utilisateur (assets/images/howitworks_*),
        // réutilisée telle quelle plutôt que redessinée — demande
        // explicite ("use the exact same images"). Seules 3 des 6 étapes
        // ont un équivalent net dans cette capture (Poster/Collecteur/
        // Points) ; les 3 autres gardent une icône, mais posée sur le même
        // type de panneau pour rester dans le même style visuel.
        final steps = <({IconData icon, String title, String desc, String? image})>[
          (
            icon: Icons.photo_camera_outlined,
            title: fr ? "1. Postez votre déchet" : "1. Post your waste",
            desc: fr
                ? "Prenez une photo, décrivez-le, choisissez une catégorie et une quantité approximative."
                : "Take a photo, describe it, choose a category and an approximate quantity.",
            image: 'assets/images/howitworks_post.png',
          ),
          (
            icon: Icons.smart_toy_outlined,
            title: fr ? "2. Analyse IA (optionnelle)" : "2. AI analysis (optional)",
            desc: fr
                ? "L'IA peut suggérer la catégorie de déchet — vous restez toujours libre de la confirmer ou de la corriger."
                : "AI can suggest the waste category — you can always confirm or correct it.",
            image: null,
          ),
          (
            icon: Icons.location_on_outlined,
            title: fr ? "3. Indiquez l'adresse" : "3. Set the address",
            desc: fr
                ? "Utilisez le GPS de votre appareil ou tapez une adresse — un pin est placé sur la carte."
                : "Use your device's GPS or type an address — a pin is placed on the map.",
            image: null,
          ),
          (
            icon: Icons.local_shipping_outlined,
            title: fr ? "4. Un collecteur accepte" : "4. A collector accepts",
            desc: fr
                ? "Votre demande devient visible aux collecteurs de la zone ; dès que l'un l'accepte, vous êtes notifié."
                : "Your request becomes visible to nearby collectors; you're notified as soon as one accepts.",
            image: 'assets/images/howitworks_collector.png',
          ),
          (
            icon: Icons.qr_code_2_outlined,
            title: fr ? "5. Collecte et vérification" : "5. Collection and verification",
            desc: fr
                ? "Le collecteur passe récupérer le déchet ; un QR code permet de vérifier la transaction."
                : "The collector picks up the waste; a QR code lets you both verify the transaction.",
            image: null,
          ),
          (
            icon: Icons.emoji_events_outlined,
            title: fr ? "6. Points et valeur" : "6. Points and value",
            desc: fr
                ? "Une fois pesé, vous recevez des points selon le poids et la catégorie — convertibles en crédit, forfait ou retrait."
                : "Once weighed, you earn points based on weight and category — convertible into airtime, data or a withdrawal.",
            image: 'assets/images/howitworks_points.png',
          ),
        ];
        return _InfoScaffold(
          title: fr ? "Comment ça marche" : "How it works",
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            itemCount: steps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final step = steps[i];
              // Chaque étape est maintenant sa propre carte blanche (fond +
              // ombre + coins arrondis) — comme sur la maquette de
              // référence, pas juste une icône posée dans une simple Row.
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Fond de carte adapté au thème (pas de blanc en dur,
                  // demande explicite : visible aussi en mode sombre) — la
                  // vignette d'illustration ci-dessous reste blanche, elle,
                  // exprès (lisibilité de l'image, pas du texte).
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line, width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Illustration (étapes 1/4/6) : fond BLANC (pas le vert
                    // pâle de [AppColors.surface] utilisé avant) pour que le
                    // dessin — assez clair lui-même — se détache nettement
                    // au lieu de se fondre dans un carré verdâtre lavé
                    // (demande explicite : "logos... more visible").
                    // Icône (étapes 2/3/5) : même traitement que TOUT logo
                    // de l'app ([BoxLogo], voir wp_common.dart) — boîte
                    // blanche + icône verte — au lieu de la précédente
                    // pastille multicolore (demande explicite : "in green
                    // and the background white").
                    step.image != null
                        ? Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(19.2),
                              border: Border.all(color: AppColors.line, width: 1),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18.2),
                              child: Image.asset(step.image!, fit: BoxFit.contain),
                            ),
                          )
                        : BoxLogo(step.icon, size: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title,
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                          const SizedBox(height: 3),
                          Text(step.desc,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
      },
    );
  }
}

class ConversionRatesScreen extends StatelessWidget {
  const ConversionRatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        return _InfoScaffold(
          title: fr ? "Taux de conversion" : "Conversion rates",
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            children: [
              // Bandeau d'information — explique le mécanisme avant la
              // liste, comme demandé, plutôt qu'une simple carte de seuil.
              // Fond JAUNE (demande explicite), pas le vert utilisé partout
              // ailleurs sur cette page (barème, exemple...).
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.amber.withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fr
                            ? "Pour chaque kilogramme de matière recyclable que vous soumettez, EcoLindk calcule les points (P) selon le taux de la matière (Points par Kg). Votre total de points est ensuite converti en Francs CFA au taux actuel de ${RewardsConfig.conversionThresholdPoints}P = ${RewardsConfig.conversionValueFcfa} FCFA."
                            : "For every kilogram of recyclable material you submit, EcoLindk calculates the points (P) based on the material's rate (Points per Kg). Your total points is then converted to Francs CFA using the current rate of ${RewardsConfig.conversionThresholdPoints}P = ${RewardsConfig.conversionValueFcfa} FCFA.",
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mainText,
                            height: 1.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "${RewardsConfig.conversionThresholdPoints}P = ${RewardsConfig.conversionValueFcfa} FCFA",
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
                ),
              ),
              const SizedBox(height: 18),
              _conversionExample(fr),
              const SizedBox(height: 20),
              ...RewardsConfig.referenceMaterials.map((m) => _materialRow(m, fr)),
            ],
          ),
        );
      },
    );
  }

  /// "Comment fonctionne la conversion" — exemple chiffré concret, avant la
  /// liste des matières (même structure que la maquette de référence :
  /// bandeau d'explication générale, puis un exemple calculé, puis la
  /// liste). Basé sur la première matière du barème pour rester 100%
  /// dérivé de [RewardsConfig], jamais un second calcul indépendant.
  Widget _conversionExample(bool fr) {
    final example = RewardsConfig.referenceMaterials.first;
    final ratePerPoint = RewardsConfig.conversionValueFcfa / RewardsConfig.conversionThresholdPoints;
    final exampleFcfa = RewardsConfig.fcfaForPoints(example.pointsPerKg);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fr ? "Comment fonctionne la conversion" : "How conversion works",
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
          const SizedBox(height: 10),
          Text(
            "♻️ 1 kg → 🔘 ${_fmtPts(example.pointsPerKg)} P × 💰 ${ratePerPoint.toStringAsFixed(2)} FCFA "
            "= ${exampleFcfa.toStringAsFixed(0)} FCFA",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText),
          ),
          const SizedBox(height: 6),
          Text(
            fr
                ? "(Donc si vous recyclez 1 kg de ${example.labelFr.toLowerCase()} valant ${_fmtPts(example.pointsPerKg)} P, vous gagnez ${exampleFcfa.toStringAsFixed(0)} FCFA.)"
                : "(So if you recycle 1 kg of ${example.labelEn.toLowerCase()} worth ${_fmtPts(example.pointsPerKg)} P, you earn ${exampleFcfa.toStringAsFixed(0)} FCFA.)",
            style: TextStyle(fontSize: 11.5, color: AppColors.textGray, fontWeight: FontWeight.w700, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Titre en vert, uniquement "Points par Kg" — pas de colonne
  /// gains/FCFA ni de point de dépôt sur cette page (demande explicite).
  Widget _materialRow(ReferenceMaterial m, bool fr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          BoxLogo(m.icon, size: 36),
          const SizedBox(width: 12),
          Expanded(
              child: Text(m.label(fr),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep))),
          Text(
              fr
                  ? "${_fmtPts(m.pointsPerKg)} P/Kg"
                  : "${_fmtPts(m.pointsPerKg)} P/Kg",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
        ],
      ),
    );
  }

  String _fmtPts(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
}

class PriceListScreen extends StatelessWidget {
  const PriceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        return _InfoScaffold(
          title: fr ? "Liste des prix de référence" : "Reference price list",
          // Même structure que "Taux de conversion" (carte par matière,
          // titre en vert), mais seulement ce qui concerne cette page-ci :
          // le prix FCFA, pas de bandeau d'explication des points — celui-là
          // reste propre à la page des taux.
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            children: RewardsConfig.referenceMaterials
                .map((m) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          BoxLogo(m.icon, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(m.label(fr),
                                style: TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
                          ),
                          Text("${m.fcfaPerKg().toStringAsFixed(0)} FCFA/Kg",
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}
