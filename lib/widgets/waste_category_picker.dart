import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/collection_request.dart';
import 'waste_category_art.dart';

/// Pastille d'une catégorie : disque en dégradé de la couleur de la
/// catégorie (palette vert/or du thème), cerclé de blanc, avec
/// l'illustration de la catégorie au centre (voir [WasteCategoryArt] —
/// demande explicite : "une image de la catégorie", pas un disque uni).
/// [checked] ajoute une petite coche en bas à droite.
class WasteCategoryBadge extends StatelessWidget {
  final WasteCategory category;
  final double size;
  final bool checked;
  const WasteCategoryBadge({super.key, required this.category, this.size = 46, this.checked = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.card,
        border: Border.all(color: category.color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: category.color.withValues(alpha: 0.30),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: category.gradient),
            child: Center(child: WasteCategoryArt(category: category, size: size * 0.74)),
          ),
          Positioned(
            right: -size * 0.1,
            bottom: -size * 0.1,
            child: AnimatedScale(
              scale: checked ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.card, width: 1.5),
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: size * 0.28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grille des catégories (2 colonnes, la dernière tuile prend toute la
/// largeur si le nombre est impair) : pastille de couleur, nom et exemples.
/// [selected] `null` = aucune catégorie choisie ; retaper la
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
      final half = (constraints.maxWidth - gap) / 2;
      const values = WasteCategory.values;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < values.length; i++)
            SizedBox(
              width: values.length.isOdd && i == values.length - 1 ? constraints.maxWidth : half,
              child: _tile(values[i]),
            ),
        ],
      );
    });
  }

  /// Tuile : pastille de couleur, nom et exemples — pas de taux de points
  /// ici (demande explicite). Sélectionnée : fond teinté en dégradé de la
  /// couleur de la catégorie, bordure pleine et coche dans la pastille.
  Widget _tile(WasteCategory c) {
    final active = selected == c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(active && allowDeselect ? null : c),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
          decoration: BoxDecoration(
            color: AppColors.card,
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.color.withValues(alpha: 0.16), c.color.withValues(alpha: 0.04)],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? c.color : AppColors.line, width: active ? 1.8 : 1.2),
            boxShadow: [
              BoxShadow(
                color: active ? c.color.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.04),
                blurRadius: active ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              WasteCategoryBadge(category: c, size: 40, checked: active),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.label(fr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: active && !isDarkMode ? Color.lerp(c.color, Colors.black, 0.25) : AppColors.mainText)),
                    const SizedBox(height: 2),
                    Text(c.examples(fr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textGray)),
                  ],
                ),
              ),
            ],
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
  final String? errorText;

  const WeightInput(
      {super.key, required this.controller, required this.fr, this.hint, this.onChanged, this.errorText});

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
              errorText: errorText,
              errorMaxLines: 2,
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
