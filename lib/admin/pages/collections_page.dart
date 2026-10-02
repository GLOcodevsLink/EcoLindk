import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/commission_service.dart';
import '../admin_format.dart';
import '../admin_strings.dart';
import '../widgets/admin_widgets.dart';

/// Collectes : demandes prises en charge par un collecteur (acceptées, en
/// attente de confirmation, terminées), avec poids, valeur et commission.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  static const _statuses = [RequestStatus.accepted, RequestStatus.inProgress, RequestStatus.completed];

  String _query = '';
  RequestStatus? _status;

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return AdminPage(
      title: s.navCollections,
      subtitle: s.collectionsSubtitle,
      actions: [AdminSearchField(onChanged: (v) => setState(() => _query = v.trim().toLowerCase()))],
      builder: (context, data) {
        final collections = data.requests.where((r) {
          if (r.collectorUid == null || !_statuses.contains(r.status)) return false;
          if (_status != null && r.status != _status) return false;
          if (_query.isEmpty) return true;
          return [
            r.reference,
            data.nameOf(r.householdUid, fallback: r.householdName),
            data.nameOf(r.collectorUid, fallback: r.collectorName),
          ].any((f) => f.toLowerCase().contains(_query));
        }).toList()
          // Les plus récemment actives d'abord.
          ..sort((a, b) => (b.completedAt ?? b.acceptedAt ?? b.createdAt).compareTo(a.completedAt ?? a.acceptedAt ?? a.createdAt));

        return [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: Text(s.all), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
            for (final status in _statuses)
              ChoiceChip(
                label: Text('${status.label(s.fr)} (${data.stats.count(status)})'),
                selected: _status == status,
                onSelected: (_) => setState(() => _status = status),
              ),
          ]),
          const SizedBox(height: 16),
          AdminCard(
            padding: const EdgeInsets.all(8),
            child: AdminTable(
              columns: [
                s.colReference,
                s.colProvider,
                s.colCollector,
                s.colCategory,
                s.colStatus,
                s.colWeight,
                s.colValue,
                s.colCommission,
                s.colDate,
              ],
              numeric: const {5, 6, 7},
              rows: [
                for (final r in collections)
                  AdminRow([
                    Text(r.reference, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(data.nameOf(r.householdUid, fallback: r.householdName)),
                    Text(data.nameOf(r.collectorUid, fallback: r.collectorName)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(r.category.icon, size: 16, color: AppColors.textGray),
                      const SizedBox(width: 6),
                      Text(r.category.label(s.fr)),
                    ]),
                    StatusChip.request(r.status),
                    _weight(s, r),
                    Text(AdminFormat.fcfa(r.valueFcfa ?? r.pendingPriceFcfa)),
                    Text(r.status == RequestStatus.completed ? AdminFormat.fcfa(CommissionService.commissionOf(r)) : '—'),
                    Text(AdminFormat.date(r.completedAt ?? r.acceptedAt ?? r.createdAt)),
                  ]),
              ],
            ),
          ),
        ];
      },
    );
  }

  /// Poids définitif, ou poids soumis par le collecteur en attente de la
  /// confirmation du fournisseur (marqué d'un astérisque expliqué au survol).
  static Widget _weight(AdminStrings s, CollectionRequest r) {
    if (r.weightKg != null) return Text(AdminFormat.kg(r.weightKg));
    if (r.pendingWeightKg != null) {
      return Tooltip(message: s.awaitingWeight, child: Text('${AdminFormat.kg(r.pendingWeightKg)} *'));
    }
    return Text(r.quantityRange);
  }
}
