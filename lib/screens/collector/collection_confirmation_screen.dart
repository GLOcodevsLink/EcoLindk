import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/collection_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/wp_common.dart';

/// Formulaire de confirmation du Collecteur, une fois sur place : poids
/// pesé + prix payé. Le poids est comparé à celui déclaré par le Fournisseur
/// au moment du post (voir [QuantityRangeBounds.acceptsCollectedWeight]) :
/// au-delà de [maxWeightDeviationKg] kg d'écart, une erreur demande le poids
/// correct et bloque l'envoi — revérifié par
/// CollectionService.submitCollectionResult. Soumettre ce formulaire vaut confirmation du Collecteur ;
/// renvoie `true` à l'écran appelant une fois enregistré (il affiche alors
/// le QR à faire scanner au Fournisseur).
class CollectionConfirmationScreen extends StatefulWidget {
  final CollectionRequest request;
  const CollectionConfirmationScreen({super.key, required this.request});

  @override
  State<CollectionConfirmationScreen> createState() => _CollectionConfirmationScreenState();
}

class _CollectionConfirmationScreenState extends State<CollectionConfirmationScreen> {
  final _weightCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _submitted = false; // n'affiche les erreurs qu'après une 1re tentative
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  String _kg(double v) =>
      "${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} kg";

  String? _weightError(bool fr) {
    final w = _parse(_weightCtrl);
    if (w == null || w <= 0) {
      return fr ? "Entrez le poids pesé, en kg." : "Enter the weighed weight, in kg.";
    }
    final r = widget.request;
    if (r.quantityRange.acceptsCollectedWeight(w)) return null;
    final declared = r.quantityRange.declaredWeightKg;
    if (declared != null) {
      final (min, max) = r.quantityRange.weightBoundsKg;
      return fr
          ? "Poids incorrect : ${_kg(w)} s'écarte de ${_kg((w - declared).abs())} des ${_kg(declared)} "
              "déclarés au post (${_kg(maxWeightDeviationKg)} d'écart au plus). "
              "Entrez le poids correct, entre ${_kg(min)} et ${_kg(max)}."
          : "Incorrect weight: ${_kg(w)} is ${_kg((w - declared).abs())} away from the ${_kg(declared)} "
              "declared in the post (${_kg(maxWeightDeviationKg)} difference at most). "
              "Enter the correct weight, between ${_kg(min)} and ${_kg(max)}.";
    }
    return fr
        ? "Poids hors de la fourchette déclarée (${r.quantityRange})."
        : "Weight outside the declared range (${r.quantityRange}).";
  }

  String? _priceError(bool fr) {
    final p = _parse(_priceCtrl);
    if (p == null || p <= 0) return fr ? "Entrez un prix valide, en FCFA." : "Enter a valid price, in FCFA.";
    return null;
  }

  Future<void> _submit(bool fr) async {
    setState(() => _submitted = true);
    if (_weightError(fr) != null || _priceError(fr) != null) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await CollectionService().submitCollectionResult(
        widget.request.id,
        weightKg: _parse(_weightCtrl)!,
        priceFcfa: _parse(_priceCtrl)!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('CollectionConfirmationScreen._submit failed: $e');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e is FormatException
            ? _weightError(fr) ?? (fr ? "Formulaire invalide." : "Invalid form.")
            : (fr
                ? "Envoi impossible. Vérifiez votre connexion et réessayez."
                : "Couldn't submit. Check your connection and try again.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        final r = widget.request;
        final declared = r.quantityRange.declaredWeightKg;
        final weight = _parse(_weightCtrl);
        final weightError = _weightError(fr);
        // L'écart est signalé en direct dès qu'un poids valide est saisi, pas
        // seulement à l'envoi — le collecteur voit tout de suite le problème.
        final showWeightError = _submitted || (weight != null && weight > 0 && weightError != null);
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
                            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Text(fr ? "Confirmer la collecte" : "Confirm the collection",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(top: 14),
                          children: [
                            _declaredCard(r, declared, fr),
                            const SizedBox(height: 18),
                            Text(fr ? "Poids pesé" : "Weighed weight",
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _weightCtrl,
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: fr ? "Ex. 14.5" : "E.g. 14.5",
                                prefixIcon: const Icon(Icons.scale_outlined, size: 19),
                                suffixText: 'kg',
                              ),
                            ),
                            if (showWeightError && weightError != null) ...[
                              const SizedBox(height: 8),
                              InlineErrorBanner(message: weightError),
                            ],
                            const SizedBox(height: 18),
                            Text(fr ? "Prix payé au fournisseur" : "Price paid to the supplier",
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: fr ? "Ex. 1500" : "E.g. 1500",
                                prefixIcon: const Icon(Icons.payments_outlined, size: 19),
                                suffixText: 'FCFA',
                              ),
                            ),
                            if (_submitted && _priceError(fr) != null) ...[
                              const SizedBox(height: 8),
                              InlineErrorBanner(message: _priceError(fr)!),
                            ],
                            if (weight != null && weightError == null) ...[
                              const SizedBox(height: 18),
                              _commissionPreview(r, weight, fr),
                            ],
                          ],
                        ),
                      ),
                      if (_submitError != null) ...[
                        InlineErrorBanner(message: _submitError!),
                        const SizedBox(height: 10),
                      ],
                      _submitting
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
                          : GradientPillButton(
                              label: fr ? "Soumettre et générer le QR" : "Submit and generate the QR",
                              onPressed: () => _submit(fr),
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

  Widget _declaredCard(CollectionRequest r, double? declared, bool fr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: r.category.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(r.category.icon, color: r.category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.category.label(fr),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                Text(
                    fr
                        ? "Déclaré au post : ${declared == null ? r.quantityRange : _kg(declared)}"
                        : "Declared in the post: ${declared == null ? r.quantityRange : _kg(declared)}",
                    style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                if (declared != null)
                  Builder(builder: (_) {
                    final (min, max) = r.quantityRange.weightBoundsKg;
                    return Text(
                        fr
                            ? "Poids accepté : ${_kg(min)} à ${_kg(max)}"
                            : "Accepted weight: ${_kg(min)} to ${_kg(max)}",
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.greenDeep));
                  }),
                Text(r.householdName.isEmpty ? r.reference : "${r.householdName} · ${r.reference}",
                    style: TextStyle(fontSize: 11, color: AppColors.textGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commissionPreview(CollectionRequest r, double weight, bool fr) {
    final rate = RewardsConfig.commissionPerKgFcfa[r.category] ?? 0;
    final commission = RewardsConfig.commissionForCollection(r.category, weight);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.greenMid),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fr
                  ? "Commission une fois confirmée : ${_kg(weight)} × ${rate.toStringAsFixed(0)} FCFA = ${commission.toStringAsFixed(0)} FCFA"
                  : "Commission once confirmed: ${_kg(weight)} × ${rate.toStringAsFixed(0)} FCFA = ${commission.toStringAsFixed(0)} FCFA",
              style: TextStyle(fontSize: 12, color: AppColors.textGray, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
