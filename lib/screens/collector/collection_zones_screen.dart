import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/phone_country.dart';
import '../../core/theme.dart';
import '../../models/collection_zone.dart';
import '../../services/auth_service.dart';
import '../../services/collector_zone_service.dart';
import '../../widgets/collection_zones_editor.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/wp_common.dart';

/// Profil du Collecteur → Zones de collecte : chaque modification est
/// enregistrée tout de suite dans Firebase (voir CollectorZoneService) et
/// s'applique dès le post suivant.
class CollectionZonesScreen extends StatefulWidget {
  const CollectionZonesScreen({super.key});

  @override
  State<CollectionZonesScreen> createState() => _CollectionZonesScreenState();
}

class _CollectionZonesScreenState extends State<CollectionZonesScreen> {
  final _service = CollectorZoneService();
  final _uid = AuthService().currentUser?.uid ?? '';

  List<CollectionZone>? _zones;
  Country? _phoneCountry;
  String? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final results = await Future.wait([
        _service.load(_uid),
        AuthService().fetchUserDocument(_uid),
      ]);
      if (!mounted) return;
      final doc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      setState(() {
        _zones = results[0] as List<CollectionZone>;
        _phoneCountry = countryFromPhone(doc.data()?['phone'] as String?);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = appLanguage.value == AppLanguage.fr
            ? "Impossible de charger vos zones."
            : "Couldn't load your zones.");
      }
    }
  }

  Future<bool> _save(List<CollectionZone> zones) async {
    final fr = appLanguage.value == AppLanguage.fr;
    setState(() => _saving = true);
    try {
      final saved = await _service.save(_uid, zones);
      if (!mounted) return true;
      setState(() {
        _zones = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fr ? "Zones enregistrées." : "Zones saved.")));
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is CollectionZoneException && e.code == 'duplicate'
              ? (fr ? "Cette zone est déjà dans votre liste." : "This zone is already in your list.")
              : e is CollectionZoneException
                  ? (fr ? "Nombre maximal de zones atteint." : "Maximum number of zones reached.")
                  : (fr ? "Enregistrement impossible. Vérifiez votre connexion." : "Couldn't save. Check your connection."))));
      return false;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Text(fr ? "Zones de collecte" : "Collection zones",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                          const Spacer(),
                          if (_saving)
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.greenMid)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loadError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: InlineErrorBanner(
                                    message: _loadError!, retryLabel: fr ? "Réessayer" : "Retry", onRetry: _load),
                              ),
                            )
                          : _zones == null
                              ? const Center(
                                  child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                                  children: [
                                    CollectionZonesEditor(
                                      zones: _zones!,
                                      phoneCountry: _phoneCountry,
                                      fr: fr,
                                      busy: _saving,
                                      onChanged: _save,
                                    ),
                                    const SizedBox(height: 22),
                                    _gpsNote(fr),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Rappelle la différence entre zones (notifications) et GPS (recherche).
  Widget _gpsNote(bool fr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEAF6FB), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.my_location_rounded, color: Color(0xFF2094C4), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                fr
                    ? "Ces zones servent uniquement aux notifications. Pour chercher des posts là où vous êtes, utilisez « Autour de moi » sur la carte des collectes : c'est votre position GPS actuelle qui compte, même hors de vos zones."
                    : "These zones are only used for notifications. To find posts where you are, use \"Around me\" on the pickups map: your current GPS position is used, even outside your zones.",
                style: TextStyle(fontSize: 12, color: AppColors.mainText, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
