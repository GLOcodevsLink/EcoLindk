import 'package:flutter/material.dart';
import '../../widgets/waste_photo_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/live_tracking_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/live_tracking_map.dart';
import '../../widgets/wp_common.dart';
import '../waste_provider/chat_screen.dart';
import 'collection_confirmation_screen.dart';

/// Écran "Collecte" du Collecteur, ouvert par le bouton central de sa barre
/// de navigation (voir CollectorShell). Déroule une collecte acceptée de
/// bout en bout :
/// 1. "Démarrer la collecte" : le Fournisseur est notifié pour partager sa
///    position, et le suivi en temps réel démarre (voir LiveTrackingMap).
/// 2. "Confirmer la collecte" : formulaire poids + prix (voir
///    CollectionConfirmationScreen) — sa soumission vaut confirmation du
///    Collecteur.
/// 3. QR code à faire scanner au Fournisseur, qui accepte ou refuse le
///    formulaire. Refus : erreur ici, le formulaire est à remplir de nouveau.
///    Acceptation : points crédités au Fournisseur, commission calculée pour
///    le Collecteur (voir CollectionService.confirmCollectionResult).
class CollectorCollectionScreen extends StatefulWidget {
  /// Collecte à afficher en premier (ex. depuis RequestStatusScreen) — sinon
  /// la plus récente des collectes en cours.
  final String? initialRequestId;
  const CollectorCollectionScreen({super.key, this.initialRequestId});

  @override
  State<CollectorCollectionScreen> createState() => _CollectorCollectionScreenState();
}

class _CollectorCollectionScreenState extends State<CollectorCollectionScreen> {
  final _service = CollectionService();
  late final String _uid = AuthService().currentUser?.uid ?? '';
  late final Stream<List<CollectionRequest>> _activeStream =
      _service.watchCollectorActiveRequests(_uid);
  late String? _selectedId = widget.initialRequestId;
  bool _starting = false;

  Future<void> _start(CollectionRequest r, bool fr) async {
    setState(() => _starting = true);
    try {
      await _service.startCollection(r.id);
    } catch (e) {
      debugPrint('CollectorCollectionScreen._start failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(fr
                ? "Impossible de démarrer la collecte. Réessayez."
                : "Couldn't start the collection. Try again.")));
      }
    }
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _openConfirmation(CollectionRequest r) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CollectionConfirmationScreen(request: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(Icons.arrow_back, color: AppColors.heading),
                              ),
                              Text(fr ? "Collecte" : "Collection",
                                  style: TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                            ],
                          ),
                          Expanded(child: _body(fr)),
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

  Widget _body(bool fr) {
    if (_uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<CollectionRequest>>(
      stream: _activeStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4));
        }
        if (snap.hasError) {
          return Center(
            child: InlineErrorBanner(
                message: fr ? "Impossible de charger vos collectes." : "Couldn't load your pickups."),
          );
        }
        final active = snap.data ?? const <CollectionRequest>[];
        // Une collecte tout juste terminée sort de la liste "en cours" : on
        // la garde sélectionnée pour afficher le succès au collecteur.
        final selectedId = _selectedId ?? (active.isEmpty ? null : active.first.id);
        if (selectedId == null) {
          return EmptyState(
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF2094C4),
            title: fr ? "Aucune collecte en cours" : "No collection in progress",
            message: fr
                ? "Acceptez une demande depuis l'onglet Collectes pour la démarrer ici."
                : "Accept a request from the Pickups tab to start it here.",
          );
        }
        return ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          children: [
            if (active.length > 1) ...[
              _selector(active, selectedId, fr),
              const SizedBox(height: 14),
            ],
            StreamBuilder<CollectionRequest?>(
              key: ValueKey(selectedId),
              stream: _service.watchRequest(selectedId),
              builder: (context, reqSnap) {
                final r = reqSnap.data;
                if (r == null) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4)),
                  );
                }
                return _requestFlow(r, fr);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _selector(List<CollectionRequest> active, String selectedId, bool fr) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: active.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = active[i];
          final selected = r.id == selectedId;
          return ChoiceChip(
            avatar: Icon(r.category.icon, size: 16, color: selected ? Colors.white : r.category.color),
            label: Text(r.reference),
            selected: selected,
            selectedColor: AppColors.greenMid,
            labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.mainText, fontWeight: FontWeight.w700),
            onSelected: (_) => setState(() => _selectedId = r.id),
          );
        },
      ),
    );
  }

  Widget _requestFlow(CollectionRequest r, bool fr) {
    final started = r.collectionStartedAt != null;
    final step = switch (r.status) {
      RequestStatus.accepted => started ? 1 : 0,
      RequestStatus.inProgress => 2,
      RequestStatus.completed => 3,
      _ => 0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryCard(r, fr),
        const SizedBox(height: 16),
        _stepper(step, fr),
        const SizedBox(height: 18),
        if (r.status == RequestStatus.accepted) ...[
          if (r.resultRejected) ...[
            InlineErrorBanner(
              message: fr
                  ? "Le fournisseur a refusé votre formulaire. Vérifiez le poids et le prix, puis remplissez-le de nouveau."
                  : "The supplier rejected your form. Check the weight and price, then fill it in again.",
            ),
            const SizedBox(height: 14),
          ],
          if (!started)
            _starting
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        fr
                            ? "Démarrez la collecte quand vous partez : le fournisseur sera invité à partager sa position pour le suivi en temps réel."
                            : "Start the collection when you head out: the supplier will be asked to share their location for real-time tracking.",
                        style: TextStyle(fontSize: 12, color: AppColors.textGray, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      GradientPillButton(
                        label: fr ? "Démarrer la collecte" : "Start collection",
                        onPressed: () => _start(r, fr),
                      ),
                    ],
                  )
          else ...[
            LiveTrackingMap(request: r, role: TrackingRole.collector, fr: fr, autoShare: true),
            const SizedBox(height: 18),
            GradientPillButton(
              label: r.resultRejected
                  ? (fr ? "Remplir le formulaire de nouveau" : "Fill in the form again")
                  : (fr ? "Confirmer la collecte" : "Confirm collection"),
              onPressed: () => _openConfirmation(r),
            ),
          ],
        ],
        if (r.status == RequestStatus.inProgress) _awaitingScan(r, fr),
        if (r.status == RequestStatus.completed) _completed(r, fr),
        if (r.status == RequestStatus.cancelled)
          InlineErrorBanner(message: fr ? "Cette demande a été annulée." : "This request was cancelled."),
      ],
    );
  }

  Widget _summaryCard(CollectionRequest r, bool fr) {
    final declared = r.quantityRange.declaredWeightKg;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: r.imageUrl.isEmpty
                ? Container(
                    width: 54,
                    height: 54,
                    color: AppColors.inputFill,
                    child: Icon(r.category.icon, color: r.category.color))
                : WastePhotoImage(url: r.imageUrl, width: 54, height: 54, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${r.category.label(fr)} · ${declared == null ? r.quantityRange : "${declared.toStringAsFixed(declared == declared.roundToDouble() ? 0 : 1)} kg"}",
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                Text(r.householdName.isEmpty ? '—' : r.householdName,
                    style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                if (r.address.isNotEmpty)
                  Text(r.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.textGray)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RequestStatusBadge(status: r.status, fr: fr),
              if (r.status == RequestStatus.accepted || r.status == RequestStatus.inProgress) ...[
                const SizedBox(height: 8),
                _chatButton(r, fr),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Discussion avec le Fournisseur de cette collecte (voir ChatScreen) —
  /// même conversation que celle qu'il ouvre depuis "Votre collecteur".
  Widget _chatButton(CollectionRequest r, bool fr) {
    return Tooltip(
      message: fr ? "Écrire au fournisseur" : "Message the supplier",
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            meUid: _uid,
            meName: r.collectorName ?? '',
            otherUid: r.householdUid,
            otherName: r.householdName,
          ),
        )),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 17),
        ),
      ),
    );
  }

  Widget _stepper(int current, bool fr) {
    final labels = fr
        ? ["Démarrer", "Suivi", "Scan", "Terminé"]
        : ["Start", "Tracking", "Scan", "Done"];
    return Row(
      children: List.generate(labels.length, (i) {
        final done = i < current;
        final active = i == current;
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 4,
                margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: done || active ? AppColors.greenMid : AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 6),
              Text(labels[i],
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: done || active ? AppColors.greenDeep : AppColors.textGray)),
            ],
          ),
        );
      }),
    );
  }

  Widget _awaitingScan(CollectionRequest r, bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: _metric(fr ? "Poids soumis" : "Submitted weight",
                    "${(r.pendingWeightKg ?? 0).toStringAsFixed(1)} kg"),
              ),
              Expanded(
                child: _metric(fr ? "Prix soumis" : "Submitted price",
                    "${(r.pendingPriceFcfa ?? 0).toStringAsFixed(0)} FCFA"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Column(
            children: [
              Text(fr ? "Faites scanner ce code au fournisseur" : "Have the supplier scan this code",
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
              const SizedBox(height: 4),
              Text(
                  fr
                      ? "Il verra votre formulaire et pourra l'accepter ou le refuser."
                      : "They'll see your form and can accept or reject it.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textGray)),
              const SizedBox(height: 14),
              // Fond blanc forcé : un QR sur fond sombre (mode nuit) ne se
              // scanne pas de façon fiable.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: QrImageView(data: r.qrPayload, size: 190),
              ),
              const SizedBox(height: 10),
              Text(r.reference,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.greenDeep)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded, size: 18, color: AppColors.greenMid),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  fr
                      ? "En attente de la confirmation du fournisseur…"
                      : "Waiting for the supplier's confirmation…",
                  style: TextStyle(fontSize: 12, color: AppColors.textGray)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _completed(CollectionRequest r, bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                        ? "Collecte confirmée par les deux parties !"
                        : "Collection confirmed by both parties!",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: AppColors.buttonGradient, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Expanded(
                child: _metric(fr ? "Poids collecté" : "Weight collected",
                    "${(r.weightKg ?? 0).toStringAsFixed(1)} kg",
                    onGradient: true),
              ),
              Expanded(
                child: _metric(fr ? "Commission" : "Commission",
                    "${(r.commissionFcfa ?? 0).toStringAsFixed(0)} FCFA",
                    onGradient: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value, {bool onGradient = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10.5, color: onGradient ? Colors.white70 : AppColors.textGray)),
        Text(value,
            style: TextStyle(
                fontSize: onGradient ? 19 : 15,
                fontWeight: FontWeight.w800,
                color: onGradient ? Colors.white : AppColors.mainText)),
      ],
    );
  }
}
