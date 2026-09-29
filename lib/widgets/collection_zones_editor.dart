import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../core/geo_config.dart';
import '../core/theme.dart';
import '../models/collection_zone.dart';
import '../screens/collector/zone_picker_screen.dart';

/// Liste "Mes zones de collecte" : compteur (3 / 5), ajout, modification,
/// suppression. Partagée par l'inscription du Collecteur (liste en mémoire,
/// enregistrée à la fin) et l'écran de gestion du profil (enregistrée à
/// chaque changement) : [onChanged] reçoit la nouvelle liste déjà validée
/// (5 zones au plus, sans doublon) et renvoie `false` si l'enregistrement a
/// échoué, auquel cas l'affichage garde l'ancienne liste.
class CollectionZonesEditor extends StatelessWidget {
  final List<CollectionZone> zones;
  final Future<bool> Function(List<CollectionZone> zones) onChanged;
  final Country? phoneCountry;
  final bool fr;
  final bool busy;

  const CollectionZonesEditor({
    super.key,
    required this.zones,
    required this.onChanged,
    required this.fr,
    this.phoneCountry,
    this.busy = false,
  });

  bool get _full => zones.length >= GeoConfig.maxCollectionZones;

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addOrEdit(BuildContext context, {int? index}) async {
    if (index == null && _full) {
      _snack(context, fr
          ? "Maximum ${GeoConfig.maxCollectionZones} zones. Supprimez-en une pour en ajouter une autre."
          : "Maximum ${GeoConfig.maxCollectionZones} zones. Remove one to add another.");
      return;
    }
    final zone = await Navigator.of(context).push<CollectionZone>(MaterialPageRoute(
      builder: (_) => ZonePickerScreen(
        initialCountry: phoneCountry,
        editing: index == null ? null : zones[index],
      ),
    ));
    if (zone == null || !context.mounted) return;

    final next = [...zones];
    final duplicateAt = next.indexWhere((z) => z.key == zone.key);
    if (duplicateAt != -1 && duplicateAt != index) {
      _snack(context, fr ? "Cette zone est déjà dans votre liste." : "This zone is already in your list.");
      return;
    }
    if (index == null) {
      next.add(zone);
    } else {
      next[index] = zone;
    }
    await onChanged(next);
  }

  Future<void> _remove(BuildContext context, int index) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(fr ? "Supprimer cette zone ?" : "Remove this zone?"),
        content: Text(zones[index].label),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(fr ? "Annuler" : "Cancel")),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(fr ? "Supprimer" : "Remove",
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    await onChanged([...zones]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(fr ? "Mes zones de collecte" : "My collection zones",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.mainText)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _full ? AppColors.amber.withValues(alpha: 0.18) : AppColors.greenMid.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                  "${zones.length} / ${GeoConfig.maxCollectionZones} ${fr ? 'zones' : 'zones'}",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _full ? AppColors.heading : AppColors.greenDeep)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            fr
                ? "Vous êtes notifié des nouveaux posts situés à ${GeoConfig.zoneNotificationRadiusKm.toStringAsFixed(0)} km ou moins de l'une de ces zones."
                : "You're notified of new posts within ${GeoConfig.zoneNotificationRadiusKm.toStringAsFixed(0)} km of one of these zones.",
            style: TextStyle(fontSize: 11.5, color: AppColors.textGray, height: 1.35)),
        const SizedBox(height: 12),
        if (zones.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.location_off_outlined, color: AppColors.textGray),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      fr
                          ? "Aucune zone : vous ne recevrez pas de notification de nouveaux posts."
                          : "No zone: you won't be notified of new posts.",
                      style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
                ),
              ],
            ),
          ),
        for (var i = 0; i < zones.length; i++) _zoneTile(context, i),
        const SizedBox(height: 10),
        Opacity(
          opacity: _full || busy ? 0.5 : 1,
          child: OutlinedButton.icon(
            onPressed: busy ? null : () => _addOrEdit(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.greenMid, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.greenDeep),
            label: Text(
                _full
                    ? (fr ? "Maximum atteint (${GeoConfig.maxCollectionZones} zones)" : "Maximum reached")
                    : (fr ? "Ajouter une zone de collecte" : "Add a collection zone"),
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
          ),
        ),
      ],
    );
  }

  Widget _zoneTile(BuildContext context, int i) {
    final z = zones[i];
    final legacy = z.city.isEmpty; // ancienne zone en texte libre
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: legacy ? AppColors.amber : AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
            child: const Icon(Icons.place_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(z.neighborhood,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                Text(
                    legacy
                        ? (fr ? "Ancienne zone : modifiez-la pour la préciser" : "Old zone: edit it to make it precise")
                        : [z.country, z.city].where((p) => p.isNotEmpty).join(' → '),
                    style: TextStyle(fontSize: 11.5, color: legacy ? const Color(0xFFB07E00) : AppColors.textGray)),
              ],
            ),
          ),
          IconButton(
            tooltip: fr ? "Modifier" : "Edit",
            onPressed: busy ? null : () => _addOrEdit(context, index: i),
            icon: Icon(Icons.edit_rounded, size: 19, color: AppColors.textGray),
          ),
          IconButton(
            tooltip: fr ? "Supprimer" : "Remove",
            onPressed: busy ? null : () => _remove(context, i),
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
