import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/wp_common.dart';
import 'chat_screen.dart';
import 'rating_screen.dart';

/// Suivi d'une demande de collecte : chronologie de statut, informations du
/// partenaire (collecteur pour le Fournisseur, Fournisseur pour le
/// Collecteur), QR code de vérification, puis poids/valeur une fois
/// terminée. Écoute Firestore en temps réel
/// (StreamBuilder) — pas de suivi GPS en direct du collecteur pour l'instant
/// (non implémenté : voir la doc du module, on ne prétend jamais qu'un tel
/// suivi existe).
///
/// Écran PARTAGÉ par les deux rôles (demande explicite : le Collecteur doit
/// pouvoir faire avancer SA collecte depuis ce même écran) — le rôle du
/// spectateur est déduit en comparant son uid à [CollectionRequest.householdUid]/
/// [CollectionRequest.collectorUid], jamais un paramètre séparé qui pourrait
/// désynchroniser de la réalité Firestore.
class RequestStatusScreen extends StatelessWidget {
  final String requestId;
  const RequestStatusScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    final service = CollectionService();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
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
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Text(fr ? "Suivi de la collecte" : "Collection tracking",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                      Expanded(
                        child: StreamBuilder<CollectionRequest?>(
                          stream: service.watchRequest(requestId),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4));
                            }
                            if (snap.hasError) {
                              return Center(
                                child: InlineErrorBanner(
                                  message: fr
                                      ? "Impossible de charger cette demande."
                                      : "Couldn't load this request.",
                                ),
                              );
                            }
                            final request = snap.data;
                            if (request == null) {
                              return EmptyState(
                                icon: Icons.search_off_rounded,
                                color: const Color(0xFF2094C4),
                                title: fr ? "Demande introuvable" : "Request not found",
                                message: fr
                                    ? "Cette demande n'existe plus."
                                    : "This request no longer exists.",
                              );
                            }
                            return _content(context, request, fr, service);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
      },
    );
  }

  Widget _content(BuildContext context, CollectionRequest r, bool fr, CollectionService service) {
    // Réclame les points/parrainage du Fournisseur pour SA PROPRE demande —
    // sans effet si déjà réclamé (idempotent, voir CollectionService).
    settleCompletedRequest(r);

    final myUid = AuthService().currentUser?.uid;
    final isCollectorView = r.collectorUid != null && r.collectorUid == myUid;
    final isHouseholdView = r.householdUid == myUid;

    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 20),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: r.imageUrl.isEmpty
                  ? Container(
                      width: 64,
                      height: 64,
                      color: AppColors.inputFill,
                      child: Icon(r.category.icon, color: AppColors.greenMid))
                  : Image.network(r.imageUrl, width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.category.label(fr),
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  Text(r.reference, style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                ],
              ),
            ),
            RequestStatusBadge(status: r.status, fr: fr),
          ],
        ),
        const SizedBox(height: 22),
        _timeline(r, fr),
        const SizedBox(height: 20),

        if (r.status == RequestStatus.accepted || r.status == RequestStatus.inProgress) ...[
          isCollectorView
              ? _householdCard(context, r, fr)
              : _collectorCard(context, r, fr),
          const SizedBox(height: 18),
        ],

        // Étape "rencontre confirmée, poids/prix soumis" — demande
        // explicite : plus de QR à l'arrivée, un seul QR généré APRÈS ce
        // formulaire, affiché par le Collecteur et scanné par le
        // Fournisseur pour accepter/refuser.
        if (r.status == RequestStatus.accepted && isCollectorView)
          GradientPillButton(
            label: fr ? "Confirmer la rencontre" : "Confirm the meeting",
            onPressed: () => _submitWeightAndPrice(context, r, fr, service),
          ),
        if (r.status == RequestStatus.accepted && isHouseholdView)
          _waitingNote(
              fr
                  ? "En attente que le collecteur confirme la rencontre."
                  : "Waiting for the collector to confirm the meeting.",
              fr),

        if (r.status == RequestStatus.inProgress && isCollectorView)
          _collectorPendingCard(r, fr),
        if (r.status == RequestStatus.inProgress && isHouseholdView)
          _householdPendingCard(context, r, fr, service),

        if (r.status == RequestStatus.completed) ...[
          _successBanner(fr),
          const SizedBox(height: 14),
          _completionCard(context, r, fr, showRatingAndPoints: !isCollectorView),
        ],

        if (r.status == RequestStatus.pending && isHouseholdView) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _confirmCancel(context, r, fr, service),
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
            label: Text(fr ? "Annuler la demande" : "Cancel request",
                style: const TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
          ),
        ],
      ],
    );
  }

  Widget _waitingNote(String message, bool fr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 18, color: AppColors.greenMid),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray, height: 1.4)),
          ),
        ],
      ),
    );
  }

  /// Bandeau de succès (demande explicite : "the system displays a success
  /// message to both") — visible par les DEUX rôles dès que la collecte est
  /// `completed` ; le Collecteur reçoit en plus une notification persistée
  /// (voir CollectionService.confirmCollectionResult) pour le cas où il
  /// n'est pas en train de regarder cet écran au moment de la confirmation.
  Widget _successBanner(bool fr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenBright.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greenMid.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.greenDeep, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                fr
                    ? "Transaction terminée avec succès !"
                    : "Transaction completed successfully!",
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
          ),
        ],
      ),
    );
  }

  /// Formulaire poids + prix soumis par le Collecteur après la rencontre —
  /// le poids doit rester dans la fourchette choisie par le Fournisseur à la
  /// création du post (demande explicite), vérifié ici ET côté serveur (voir
  /// CollectionService.submitCollectionResult).
  Future<void> _submitWeightAndPrice(
      BuildContext context, CollectionRequest r, bool fr, CollectionService service) async {
    final weightCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final (min, max) = r.quantityRange.weightBoundsKg;
    final rangeLabel = max.isInfinite
        ? (fr ? "≥ ${min.toStringAsFixed(0)} kg" : "≥ ${min.toStringAsFixed(0)} kg")
        : "${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)} kg";

    final result = await showDialog<(double, double)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(fr ? "Résultat de la collecte" : "Collection result"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  fr
                      ? "Quantité annoncée par le fournisseur : $rangeLabel"
                      : "Provider's declared quantity: $rangeLabel",
                  style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
              const SizedBox(height: 12),
              TextFormField(
                controller: weightCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    hintText: fr ? "Ex. 3.5" : "E.g. 3.5", suffixText: "kg"),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return fr ? "Entrez un poids valide." : "Enter a valid weight.";
                  }
                  if (parsed < min || parsed > max) {
                    return fr
                        ? "Doit rester dans la fourchette : $rangeLabel"
                        : "Must stay within: $rangeLabel";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    hintText: fr ? "Ex. 1500" : "E.g. 1500", suffixText: "FCFA"),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return fr ? "Entrez un prix valide." : "Enter a valid price.";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(fr ? "Annuler" : "Cancel")),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop((
                  double.parse(weightCtrl.text.replaceAll(',', '.')),
                  double.parse(priceCtrl.text.replaceAll(',', '.')),
                ));
              }
            },
            child: Text(fr ? "Confirmer" : "Confirm",
                style: const TextStyle(color: AppColors.greenMid, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null) return;
    final (weight, price) = result;
    try {
      await service.submitCollectionResult(r.id, weightKg: weight, priceFcfa: price);
    } catch (_) {
      // Le formulaire valide déjà la fourchette côté client — ce contrôle
      // serveur ne devrait donc (presque) jamais se déclencher, mais ne
      // doit jamais planter silencieusement s'il le fait.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(fr
              ? "Poids hors fourchette ou envoi impossible. Réessayez."
              : "Weight out of range or couldn't submit. Try again.")));
    }
  }

  /// Vue Collecteur pendant [RequestStatus.inProgress] : rappel de ce qui a
  /// été soumis + le QR à montrer au fournisseur pour qu'il le scanne.
  Widget _collectorPendingCard(CollectionRequest r, bool fr) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: _pendingMetric(
                    fr ? "Poids soumis" : "Submitted weight",
                    "${(r.pendingWeightKg ?? 0).toStringAsFixed(1)} kg"),
              ),
              Expanded(
                child: _pendingMetric(fr ? "Prix soumis" : "Submitted price",
                    "${(r.pendingPriceFcfa ?? 0).toStringAsFixed(0)} FCFA"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _qrCard(r, fr),
        const SizedBox(height: 14),
        _waitingNote(
            fr
                ? "En attente que le fournisseur scanne ce code et confirme."
                : "Waiting for the provider to scan this code and confirm.",
            fr),
      ],
    );
  }

  Widget _pendingMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.mainText)),
      ],
    );
  }

  /// Vue Fournisseur pendant [RequestStatus.inProgress] : ce que le
  /// collecteur a soumis, avec Accepter/Refuser — atteinte soit en scannant
  /// le QR du collecteur, soit directement depuis "Mes collectes" (la
  /// donnée est la même dans les deux cas, voir doc de la classe).
  Widget _householdPendingCard(
      BuildContext context, CollectionRequest r, bool fr, CollectionService service) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration:
              BoxDecoration(gradient: AppColors.buttonGradient, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fr ? "Poids proposé" : "Proposed weight",
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text("${(r.pendingWeightKg ?? 0).toStringAsFixed(1)} kg",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fr ? "Prix proposé" : "Proposed price",
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text("${(r.pendingPriceFcfa ?? 0).toStringAsFixed(0)} FCFA",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rejectPending(context, r, fr, service),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                child: Text(fr ? "Refuser" : "Reject",
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientPillButton(
                label: fr ? "Accepter" : "Accept",
                onPressed: () => service.confirmCollectionResult(r.id),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _rejectPending(
      BuildContext context, CollectionRequest r, bool fr, CollectionService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(fr ? "Refuser ce poids/prix ?" : "Reject this weight/price?"),
        content: Text(fr
            ? "Le collecteur sera prévenu et pourra renvoyer un nouveau formulaire."
            : "The collector will be notified and can resubmit the form."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(fr ? "Retour" : "Back")),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(fr ? "Refuser" : "Reject",
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) await service.rejectCollectionResult(r.id);
  }

  Widget _timeline(CollectionRequest r, bool fr) {
    final steps = [
      (fr ? "Demande envoyée" : "Request submitted", true),
      (fr ? "Collecteur assigné" : "Collector assigned",
          [RequestStatus.accepted, RequestStatus.inProgress, RequestStatus.completed].contains(r.status)),
      (fr ? "En attente de confirmation" : "Awaiting confirmation",
          [RequestStatus.inProgress, RequestStatus.completed].contains(r.status)),
      (fr ? "Collecte terminée" : "Collection completed", r.status == RequestStatus.completed),
    ];
    if (r.status == RequestStatus.cancelled) {
      return InlineErrorBanner(message: fr ? "Cette demande a été annulée." : "This request was cancelled.");
    }
    return Column(
      children: List.generate(steps.length, (i) {
        final (label, done) = steps[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20, color: done ? AppColors.greenMid : AppColors.line),
                if (i != steps.length - 1)
                  Container(width: 2, height: 30, color: done ? AppColors.greenMid : AppColors.line),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                      color: done ? AppColors.mainText : AppColors.textGray)),
            ),
          ],
        );
      }),
    );
  }

  Widget _collectorCard(BuildContext context, CollectionRequest r, bool fr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: AppColors.line, child: Icon(Icons.person, color: AppColors.textGray)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fr ? "Votre collecteur" : "Your collector",
                    style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                Text(r.collectorName ?? '—',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.mainText)),
              ],
            ),
          ),
          if (r.collectorUid != null)
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  meUid: r.householdUid,
                  meName: r.householdName,
                  otherUid: r.collectorUid!,
                  otherName: r.collectorName ?? '',
                ),
              )),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  /// Symétrique de [_collectorCard], vue Collecteur : infos du Fournisseur
  /// (nom + adresse) plutôt que du collecteur, chat avec les uids inversés.
  Widget _householdCard(BuildContext context, CollectionRequest r, bool fr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: AppColors.line, child: Icon(Icons.person, color: AppColors.textGray)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fr ? "Fournisseur" : "Provider",
                    style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                Text(r.householdName.isEmpty ? '—' : r.householdName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                if (r.address.isNotEmpty)
                  Text(r.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.textGray)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                meUid: r.collectorUid!,
                meName: r.collectorName ?? '',
                otherUid: r.householdUid,
                otherName: r.householdName,
              ),
            )),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrCard(CollectionRequest r, bool fr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Column(
        children: [
          Text(fr ? "QR code de vérification" : "Verification QR code",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          const SizedBox(height: 4),
          Text(
              fr
                  ? "Montrez ce code au fournisseur pour qu'il le scanne et confirme."
                  : "Show this code to the provider so they can scan and confirm.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textGray)),
          const SizedBox(height: 14),
          QrImageView(data: 'ecolindk:collection:${r.id}', size: 160),
          const SizedBox(height: 10),
          Text(r.reference, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.greenDeep)),
        ],
      ),
    );
  }

  /// [showRatingAndPoints] : `false` côté Collecteur (demande explicite : le
  /// Collecteur n'a pas de points — les points/la valeur affichés ici
  /// reviennent au Fournisseur, jamais au collecteur, donc jamais montrés
  /// comme "gagnés" par ce dernier ; la notation du collecteur reste aussi
  /// une action du Fournisseur uniquement).
  Widget _completionCard(BuildContext context, CollectionRequest r, bool fr,
      {required bool showRatingAndPoints}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.buttonGradient, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fr ? "Poids collecté" : "Weight collected",
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text("${(r.weightKg ?? 0).toStringAsFixed(1)} kg",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (showRatingAndPoints)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fr ? "Points gagnés" : "Points earned",
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      Text("+${r.pointsEarned ?? 0} pts",
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (showRatingAndPoints) ...[
          const SizedBox(height: 14),
          FutureBuilder(
            future: RatingService().fetch(r.id),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
              if (snap.data != null) {
                return Text(fr ? "Merci pour votre évaluation !" : "Thanks for your rating!",
                    style: TextStyle(fontSize: 12.5, color: AppColors.textGray));
              }
              return GradientPillButton(
                label: fr ? "Évaluer le collecteur" : "Rate the collector",
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RatingScreen(request: r)),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, CollectionRequest r, bool fr, CollectionService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(fr ? "Annuler cette demande ?" : "Cancel this request?"),
        content: Text(fr
            ? "Cette action est définitive."
            : "This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(fr ? "Retour" : "Back")),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(fr ? "Annuler la demande" : "Cancel request",
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.cancelRequest(r.id);
    }
  }
}
