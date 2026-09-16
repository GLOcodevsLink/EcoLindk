import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/collection_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/wp_common.dart';
import 'chat_screen.dart';
import 'rating_screen.dart';

/// Suivi d'une demande de collecte : chronologie de statut, informations du
/// collecteur une fois assigné, QR code de vérification, puis poids/valeur
/// une fois terminée. Écoute Firestore en temps réel (StreamBuilder) — pas
/// de suivi GPS en direct du collecteur pour l'instant (non implémenté :
/// voir la doc du module, on ne prétend jamais qu'un tel suivi existe).
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
          _collectorCard(context, r, fr),
          const SizedBox(height: 18),
          _qrCard(r, fr),
        ],

        if (r.status == RequestStatus.completed) _completionCard(context, r, fr),

        if (r.status == RequestStatus.pending) ...[
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

  Widget _timeline(CollectionRequest r, bool fr) {
    final steps = [
      (fr ? "Demande envoyée" : "Request submitted", true),
      (fr ? "Collecteur assigné" : "Collector assigned",
          [RequestStatus.accepted, RequestStatus.inProgress, RequestStatus.completed].contains(r.status)),
      (fr ? "Collecte en cours" : "Collection in progress",
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
                  ? "Montrez ce code au collecteur lors de la collecte."
                  : "Show this code to the collector at pickup.",
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

  Widget _completionCard(BuildContext context, CollectionRequest r, bool fr) {
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
