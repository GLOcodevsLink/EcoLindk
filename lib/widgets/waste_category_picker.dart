import 'package:flutter/material.dart';
import '../core/rewards_config.dart';
import '../core/theme.dart';
import '../models/collection_request.dart';

/// Pastille d'icône d'une catégorie : carré arrondi en dégradé de la couleur
/// de la catégorie, avec un reflet léger — utilisée partout où une catégorie
/// doit se reconnaître d'un coup d'œil (formulaire de post, résultat IA).
class WasteCategoryBadge extends StatelessWidget {
  final WasteCategory category;
  final double size;
  const WasteCategoryBadge({super.key, required this.category, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: category.gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: category.color.withValues(alpha: 0.35),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Reflet en haut à gauche, pour un rendu moins plat.
          Positioned(
            top: size * 0.08,
            left: size * 0.1,
            child: Container(
              width: size * 0.42,
              height: size * 0.2,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          Icon(category.icon, color: Colors.white, size: size * 0.5),
        ],
      ),
    );
  }
}

/// Grille des 4 catégories (2 colonnes) : pastille, nom, exemples et taux de
/// points par kg. [selected] `null` = aucune catégorie choisie ; retaper la
/// catégorie choisie la désélectionne quand [allowDeselect] est vrai (choix
/// facultatif avant l'analyse IA).
class WasteCategoryPicker extends StatelessWidget {
  final WasteCategory? selected;
  final ValueChanged<WasteCategory?> onChanged;
  final bool fr;
  final bool allowDeselect;

  const WasteCategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.fr,
    this.allowDeselect = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      final width = (constraints.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: WasteCategory.values
            .map((c) => SizedBox(width: width, child: _tile(c)))
            .toList(),
      );
    });
  }

  Widget _tile(WasteCategory c) {
    final active = selected == c;
    final rate = RewardsConfig.pointsPerKg[c] ?? 0;
    final rateText = rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(1);
    return AnimatedScale(
      scale: active ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onChanged(active && allowDeselect ? null : c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: active ? c.color.withValues(alpha: 0.10) : AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? c.color : AppColors.line,
                width: active ? 2 : 1.2,
              ),
              boxShadow: [
                if (active)
                  BoxShadow(
                      color: c.color.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WasteCategoryBadge(category: c, size: 44),
                    const SizedBox(height: 10),
                    Text(c.label(fr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                    const SizedBox(height: 2),
                    Text(c.examples(fr),
                        maxLines: 2,
                        style: TextStyle(fontSize: 10.5, color: AppColors.textGray, height: 1.3)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text("$rateText P/kg",
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c.color)),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ de poids en kg avec boutons − / + (pas de 0,5 kg) — saisie libre
/// toujours possible, approximative ou exacte.
class WeightInput extends StatelessWidget {
  final TextEditingController controller;
  final bool fr;
  final String? hint;
  final VoidCallback? onChanged;

  const WeightInput({super.key, required this.controller, required this.fr, this.hint, this.onChanged});

  double? get _value => double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _step(double delta) {
    final next = ((_value ?? 0) + delta).clamp(0, 10000).toDouble();
    controller.text = next == next.roundToDouble() ? next.toStringAsFixed(0) : next.toStringAsFixed(1);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _roundButton(Icons.remove_rounded, () => _step(-0.5)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged?.call(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.mainText),
            decoration: InputDecoration(
              hintText: hint ?? (fr ? "Ex. 3.5" : "E.g. 3.5"),
              hintStyle: TextStyle(fontSize: 15, color: AppColors.textGray, fontWeight: FontWeight.w500),
              suffixText: 'kg',
              suffixStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textGray),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _roundButton(Icons.add_rounded, () => _step(0.5)),
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.greenMid.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppColors.greenDeep)),
      ),
    );
  }
}
