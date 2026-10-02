import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/user_role.dart';
import '../admin_format.dart';
import '../admin_strings.dart';
import '../models/admin_models.dart';
import '../services/admin_data.dart';
import '../services/admin_stats.dart';
import '../widgets/admin_widgets.dart';
import 'providers_page.dart';

/// Collecteurs (`users` au rôle `collector`), avec leur activité, leur note
/// et leur commission restant due.
class CollectorsPage extends StatefulWidget {
  const CollectorsPage({super.key});

  @override
  State<CollectorsPage> createState() => _CollectorsPageState();
}

class _CollectorsPageState extends State<CollectorsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return AdminPage(
      title: s.navCollectors,
      subtitle: s.collectorsSubtitle,
      actions: [AdminSearchField(onChanged: (v) => setState(() => _query = v.trim().toLowerCase()))],
      builder: (context, data) {
        final collectors = data.users.where((u) => u.role == UserRole.collector && matchesUser(u, _query)).toList();
        return [
          AdminCard(
            padding: const EdgeInsets.all(8),
            child: AdminTable(
              columns: [s.colName, s.colType, s.colZones, s.colCompleted, s.colKg, s.colRating, s.colOutstanding],
              numeric: const {2, 3, 4, 6},
              rows: [
                for (final u in collectors)
                  () {
                    final sum = CollectorSummary.of(u.uid, data.requests, data.commissionPayments, data.ratings);
                    return AdminRow([
                      Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(_typeOf(s, u)),
                      Text('${u.zones.length}'),
                      Text('${sum.completed}'),
                      Text(AdminFormat.kg(sum.kg)),
                      Text(sum.averageRating == null ? '—' : '★ ${sum.averageRating!.toStringAsFixed(1)}'),
                      Text(AdminFormat.fcfa(sum.outstandingFcfa)),
                    ], onTap: () => _showCollector(context, data, u, sum));
                  }(),
              ],
            ),
          ),
        ];
      },
    );
  }

  static String _typeOf(AdminStrings s, AdminUser u) {
    if (u.workStatus == WorkStatus.company || (u.companyName ?? '').isNotEmpty) {
      return (u.companyName ?? '').isEmpty ? s.company : '${s.company} · ${u.companyName}';
    }
    return s.independent;
  }

  void _showCollector(BuildContext context, AdminData data, AdminUser u, CollectorSummary sum) {
    final s = AdminStrings.of(appLanguage.value);
    final history = data.requests.where((r) => r.collectorUid == u.uid).toList();
    final payments = data.commissionPayments.where((p) => p.collectorUid == u.uid).toList();
    showAdminDetail(context, title: u.displayName, children: [
      DetailLine(s.colType, _typeOf(s, u)),
      DetailLine(s.email, u.email.isEmpty ? '—' : u.email),
      DetailLine(s.colPhone, u.phone.isEmpty ? '—' : '${u.phone}${u.phoneVerified ? ' ✓' : ''}'),
      DetailLine(s.colJoined, AdminFormat.date(u.createdAt)),
      DetailLine(s.colRating,
          sum.averageRating == null ? s.noRating : s.ratingOf(sum.averageRating!.toStringAsFixed(1), sum.ratingCount)),
      DetailLine(s.colOutstanding, AdminFormat.fcfa(sum.outstandingFcfa)),
      DetailLine('UID', u.uid),
      DetailSection(s.zonesTitle),
      if (u.zones.isEmpty) Text(s.noZones, style: TextStyle(color: AppColors.textGray)),
      for (final z in u.zones)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('• ${z.label}', style: TextStyle(color: AppColors.mainText)),
        ),
      DetailSection('${s.historyTitle} (${history.length})'),
      if (history.isEmpty) Text(s.noResults, style: TextStyle(color: AppColors.textGray)),
      for (final r in history.take(20)) RequestLine(r),
      DetailSection(s.paymentsTitle),
      if (payments.isEmpty) Text(s.noPayments, style: TextStyle(color: AppColors.textGray)),
      for (final p in payments.take(20))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Text('${AdminFormat.dateTime(p.createdAt)} · ${AdminFormat.fcfa(p.amountFcfa)} · ${operatorLabel(p.channel)}',
                  style: TextStyle(color: AppColors.mainText, fontSize: 13)),
            ),
            StatusChip.payment(p.status),
          ]),
        ),
    ]);
  }
}
