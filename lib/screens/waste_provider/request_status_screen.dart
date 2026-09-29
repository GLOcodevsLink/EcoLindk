import 'package:flutter/material.dart';
import '../../widgets/waste_photo_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/live_tracking_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/live_tracking_map.dart';
import '../../widgets/wp_common.dart';
import '../collector/collector_collection_screen.dart';
import 'chat_screen.dart';
import 'rating_screen.dart';
import 'scan_screen.dart';

/// Suivi d'une demande de collecte : chronologie de statut, informations du
/// partenaire (collecteur pour le Fournisseur, Fournisseur pour le
/// Collecteur), QR code de vérification, puis poids/valeur une fois
/// terminée. Écoute Firestore en temps réel (StreamBuilder) ; une fois la
/// collecte démarrée par le Collecteur, le Fournisseur y partage sa position
/// et suit celle du collecteur (voir LiveTrackingMap).
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
                  : WastePhotoImage(url: r.imageUrl, width: 64, height: 64, fit: BoxFit.cover),
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
        // Tout le déroulé côté Collecteur (démarrage, suivi, formulaire, QR)
        // vit sur son écran Collecte — un seul endroit, pas deux formulaires.
        if (r.status == RequestStatus.accepted && isCollectorView)
          GradientPillButton(
            label: fr ? "Ouvrir la collecte" : "Open the collection",
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CollectorCollectionScreen(initialRequestId: r.id),
            )),
          ),
        if (r.status == RequestStatus.accepted && isHouseholdView)
          r.collectionStartedAt == null
              ? _waitingNote(
                  fr
                      ? "En attente que le collecteur démarre la collecte."
                      : "Waiting for the collector to start the collection.",
                  fr)
              : _householdTracking(r, fr),

        if (r.status == RequestStatus.inProgress && isCollectorView)
          _collectorPendingCard(r, fr),
        if (r.status == RequestStatus.inProgress && isHouseholdView)
          _householdScanPrompt(context, r, fr),

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

  /// Vue Fournisseur une fois la collecte démarrée : invitation à partager
  /// sa position + carte en direct des deux parties.
  Widget _householdTracking(CollectionRequest r, bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: Color(0xFF2094C4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    fr
                        ? "${r.collectorName ?? 'Votre collecteur'} est en route. Votre position est partagée avec lui pendant la collecte pour qu'il vous trouve facilement."
                        : "${r.collectorName ?? 'Your collector'} is on the way. Your location is shared with them during the collection so they can find you easily.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.mainText, height: 1.4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Partage automatique dès l'ouverture, comme côté collecteur : les
        // deux parties se voient bouger sans action supplémentaire (bouton
        // "Arrêter de partager" toujours disponible sur la carte).
        LiveTrackingMap(request: r, role: TrackingRole.household, fr: fr, autoShare: true),
      ],
    );
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
                : "Waiting for the supplier to scan this code and confirm.",
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

  /// Vue Fournisseur pendant [RequestStatus.inProgress] : le formulaire du
  /// collecteur n'est PAS affiché ici — on ne peut l'accepter ou le refuser
  /// qu'en scannant le QR code affiché sur l'écran du collecteur (voir
  /// ScanScreen/CollectionReviewScreen), donc en sa présence.
  Widget _householdScanPrompt(BuildContext context, CollectionRequest r, bool fr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    fr
                        ? "${r.collectorName ?? 'Le collecteur'} a rempli le formulaire de collecte."
                        : "${r.collectorName ?? 'The collector'} filled in the collection form.",
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
              fr
                  ? "Scannez le QR code affiché sur son téléphone pour voir le poids et le prix, puis accepter ou refuser."
                  : "Scan the QR code shown on their phone to see the weight and price, then accept or reject.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textGray, height: 1.4)),
          const SizedBox(height: 14),
          GradientPillButton(
            label: fr ? "Scanner le QR code" : "Scan the QR code",
            trailingIcon: Icons.qr_code_scanner_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScanScreen()),
            ),
          ),
        ],
      ),
    );
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
                Text(fr ? "Fournisseur" : "Supplier",
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
                  : "Show this code to the supplier so they can scan and confirm.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textGray)),
          const SizedBox(height: 14),
          // Fond blanc forcé : un QR sur fond sombre (mode nuit) ne se
          // scanne pas de façon fiable.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(data: r.qrPayload, size: 160),
          ),
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
