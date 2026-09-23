import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/osm_map_preview.dart';
import '../../widgets/wp_common.dart';
import '../waste_provider/request_status_screen.dart';

/// Détail d'une demande de collecte encore LIBRE (`pending`), ouvert depuis
/// la carte ou la liste du Collecteur (voir CollectorMapScreen) — montre les
/// infos du déchet + sa position réelle, avec un seul bouton d'action :
/// accepter cette collecte. Distincte de CollectionDetailScreen (fiche de
/// traçabilité d'une collecte déjà TERMINÉE) : deux moments très différents
/// du cycle de vie d'une demande, deux écrans séparés plutôt qu'un seul
/// bourré de conditions.
class CollectorRequestPreviewScreen extends StatefulWidget {
  final CollectionRequest request;
  const CollectorRequestPreviewScreen({super.key, required this.request});

  @override
  State<CollectorRequestPreviewScreen> createState() =>
      _CollectorRequestPreviewScreenState();
}

class _CollectorRequestPreviewScreenState
    extends State<CollectorRequestPreviewScreen> {
  final _authService = AuthService();
  final _collectionService = CollectionService();
  bool _accepting = false;
  String? _error;

  Future<void> _accept(bool fr) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      final doc = await _authService.fetchUserDocument(uid);
      final data = doc.data();
      final firstName = ((data?['firstName'] as String?) ?? '').trim();
      final name = firstName.isEmpty
          ? (data?['fullName'] as String? ?? '')
          : '$firstName ${data?['lastName'] ?? ''}'.trim();

      await _collectionService.acceptRequest(
        widget.request.id,
        collectorUid: uid,
        collectorName: name,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => RequestStatusScreen(requestId: widget.request.id)),
      );
    } on StateError {
      // `already-accepted` (voir CollectionService) : un autre collecteur a
      // été plus rapide — jamais silencieux, on le dit clairement.
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = fr
            ? "Un autre collecteur vient d'accepter cette demande."
            : "Another collector just accepted this request.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = fr
            ? "Impossible d'accepter cette demande. Réessayez."
            : "Couldn't accept this request. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
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
                              Text(r.reference,
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.heading)),
                              const Spacer(),
                              RequestStatusBadge(status: r.status, fr: fr),
                            ],
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.only(top: 14, bottom: 20),
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: r.imageUrl.isEmpty
                                      ? Container(
                                          height: 180,
                                          color: AppColors.inputFill,
                                          child: Icon(r.category.icon,
                                              size: 40, color: AppColors.greenMid))
                                      : Image.network(r.imageUrl,
                                          height: 180, width: double.infinity, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 16),
                                Text(r.category.label(fr),
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                                const SizedBox(height: 4),
                                Text(r.description.isEmpty ? '—' : r.description,
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textGray, height: 1.4)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _infoTile(fr ? "Quantité" : "Quantity",
                                            r.quantityRange, Icons.scale_outlined)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: _infoTile(fr ? "Fournisseur" : "Provider",
                                            r.householdName.isEmpty ? '—' : r.householdName,
                                            Icons.person_outline)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(fr ? "Adresse de collecte" : "Collection address",
                                    style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                                const SizedBox(height: 4),
                                Text(r.address.isEmpty ? '—' : r.address,
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
                                const SizedBox(height: 10),
                                MiniMapPreview(
                                  latitude: r.latitude,
                                  longitude: r.longitude,
                                  approximate: r.locationIsApproximate,
                                  fr: fr,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  InlineErrorBanner(message: _error!),
                                ],
                              ],
                            ),
                          ),
                          _accepting
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.greenMid, strokeWidth: 2.4)),
                                )
                              : GradientPillButton(
                                  label: fr ? "Accepter cette collecte" : "Accept this collection",
                                  onPressed: () => _accept(fr),
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

  Widget _infoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.greenMid),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                Text(value,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.mainText),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
