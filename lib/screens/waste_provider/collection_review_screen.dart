import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/collection_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/wp_common.dart';

/// Formulaire de collecte soumis par le Collecteur, vu par le Fournisseur —
/// ouvert UNIQUEMENT en scannant le QR code affiché sur l'écran du
/// collecteur (voir ScanScreen), d'où [scanCode], revérifié par
/// CollectionService à l'acceptation comme au refus.
///
/// - Accepter : la transaction est terminée, les points du Fournisseur sont
///   crédités et la commission du Collecteur calculée.
/// - Refuser : le collecteur voit une erreur sur son écran et doit renvoyer
///   le formulaire.
class CollectionReviewScreen extends StatefulWidget {
  final String requestId;
  final String scanCode;
  const CollectionReviewScreen({super.key, required this.requestId, required this.scanCode});

  @override
  State<CollectionReviewScreen> createState() => _CollectionReviewScreenState();
}

class _CollectionReviewScreenState extends State<CollectionReviewScreen> {
  final _service = CollectionService();
  late final Stream<CollectionRequest?> _stream = _service.watchRequest(widget.requestId);
  bool _busy = false;

  /// Résultat affiché une fois l'action faite (le document change ensuite
  /// de statut, le formulaire n'a plus à s'afficher).
  _Outcome? _outcome;

  Future<void> _decide(CollectionRequest r, bool fr, {required bool accept}) async {
    if (!accept) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(fr ? "Refuser ce formulaire ?" : "Reject this form?"),
          content: Text(fr
              ? "Le collecteur verra une erreur et devra renvoyer un formulaire corrigé."
              : "The collector will see an error and must send a corrected form."),
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
      if (sure != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final points = RewardsConfig.pointsForCollection(r.category, r.pendingWeightKg ?? 0).round();
      if (accept) {
        await _service.confirmCollectionResult(r.id, scanCode: widget.scanCode);
      } else {
        await _service.rejectCollectionResult(r.id, scanCode: widget.scanCode);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outcome = accept ? _Outcome.accepted(points) : const _Outcome.rejected();
      });
    } catch (e) {
      debugPrint('CollectionReviewScreen._decide failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is StateError
            ? (fr
                ? "Ce formulaire n'est plus valable. Scannez de nouveau le QR du collecteur."
                : "This form is no longer valid. Scan the collector's QR code again.")
            : (fr ? "Action impossible. Réessayez." : "Couldn't complete. Try again.")),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            onPressed: _busy ? null : () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Text(fr ? "Formulaire de collecte" : "Collection form",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                      Expanded(
                        child: _outcome != null
                            ? _outcomeView(_outcome!, fr)
                            : StreamBuilder<CollectionRequest?>(
                                stream: _stream,
                                builder: (context, snap) {
                                  final r = snap.data;
                                  if (r == null) {
                                    return const Center(
                                        child: CircularProgressIndicator(
                                            color: AppColors.greenMid, strokeWidth: 2.4));
                                  }
                                  if (r.status != RequestStatus.inProgress ||
                                      r.scanCode != widget.scanCode) {
                                    return Center(
                                      child: InlineErrorBanner(
                                        message: fr
                                            ? "Ce formulaire n'est plus en attente. Scannez le QR code actuel du collecteur."
                                            : "This form is no longer pending. Scan the collector's current QR code.",
                                      ),
                                    );
                                  }
                                  return _form(r, fr);
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
  }

  Widget _form(CollectionRequest r, bool fr) {
    final declared = r.quantityRange.declaredWeightKg;
    final weight = r.pendingWeightKg ?? 0;
    final points = RewardsConfig.pointsForCollection(r.category, weight).round();
    final rate = RewardsConfig.pointsPerKg[r.category] ?? 0;
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.buttonGradient, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Icon(r.category.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.category.label(fr),
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(r.reference, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _big(fr ? "Poids pesé" : "Weighed", "${weight.toStringAsFixed(1)} kg")),
                  Expanded(
                      child: _big(fr ? "Prix payé" : "Price paid",
                          "${(r.pendingPriceFcfa ?? 0).toStringAsFixed(0)} FCFA")),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Column(
            children: [
              _row(fr ? "Collecteur" : "Collector", r.collectorName ?? '—'),
              _row(fr ? "Poids déclaré au post" : "Weight declared in the post",
                  declared == null ? r.quantityRange : "${declared.toStringAsFixed(1)} kg"),
              _row(fr ? "Poids pesé" : "Weighed weight", "${weight.toStringAsFixed(1)} kg"),
              _row(fr ? "Taux de la catégorie" : "Category rate",
                  "${rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(1)} P/kg"),
              const Divider(height: 18),
              _row(fr ? "Points si vous acceptez" : "Points if you accept", "+$points P",
                  highlight: true),
              _row(fr ? "Soit" : "Worth",
                  "${RewardsConfig.fcfaForPoints(points).toStringAsFixed(0)} FCFA"),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (_busy)
          const Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
        else ...[
          GradientPillButton(
            label: fr ? "Accepter et terminer" : "Accept and complete",
            trailingIcon: Icons.check_rounded,
            onPressed: () => _decide(r, fr, accept: true),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _decide(r, fr, accept: false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
              label: Text(fr ? "Refuser" : "Reject",
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _outcomeView(_Outcome o, bool fr) {
    final ok = o.accepted;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              gradient: ok ? AppColors.buttonGradient : null,
              color: ok ? null : Colors.redAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(ok ? Icons.check_rounded : Icons.replay_rounded,
                color: ok ? Colors.white : Colors.redAccent, size: 42),
          ),
          const SizedBox(height: 18),
          Text(
              ok
                  ? (fr ? "Transaction terminée !" : "Transaction completed!")
                  : (fr ? "Formulaire refusé" : "Form rejected"),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          const SizedBox(height: 8),
          Text(
              ok
                  ? (fr
                      ? "+${o.points} points ont été ajoutés à votre portefeuille."
                      : "+${o.points} points were added to your wallet.")
                  : (fr
                      ? "Le collecteur a été prévenu et va renvoyer un formulaire corrigé."
                      : "The collector was notified and will send a corrected form."),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textGray, height: 1.4)),
          const SizedBox(height: 24),
          GradientPillButton(
            label: fr ? "Terminer" : "Done",
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _big(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _row(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textGray))),
            Text(value,
                style: TextStyle(
                    fontSize: highlight ? 15 : 12.5,
                    fontWeight: FontWeight.w800,
                    color: highlight ? AppColors.greenDeep : AppColors.mainText)),
          ],
        ),
      );
}

class _Outcome {
  final bool accepted;
  final int points;
  const _Outcome.accepted(this.points) : accepted = true;
  const _Outcome.rejected()
      : accepted = false,
        points = 0;
}
