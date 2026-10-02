import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../models/user_role.dart';
import '../admin_format.dart';
import '../admin_strings.dart';
import '../models/admin_models.dart';
import '../services/admin_data.dart';
import '../services/admin_stats.dart';
import '../widgets/admin_widgets.dart';

/// Fournisseurs de déchets (`users` au rôle `household`).
class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key});

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return AdminPage(
      title: s.navProviders,
      subtitle: s.providersSubtitle,
      actions: [AdminSearchField(onChanged: (v) => setState(() => _query = v.trim().toLowerCase()))],
      builder: (context, data) {
        final providers = data.users.where((u) => u.role == UserRole.household && matchesUser(u, _query)).toList();
        return [
          AdminCard(
            padding: const EdgeInsets.all(8),
            child: AdminTable(
              columns: [s.colName, s.colContact, s.colJoined, s.colPosts, s.colCompleted, s.colKg, s.colPoints],
              numeric: const {3, 4, 5, 6},
              rows: [
                for (final u in providers)
                  () {
                    final sum = ProviderSummary.of(u.uid, data.requests, data.wallets);
                    return AdminRow([
                      Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(u.email.isNotEmpty ? u.email : u.phone),
                      Text(AdminFormat.date(u.createdAt)),
                      Text('${sum.posts}'),
                      Text('${sum.completed}'),
                      Text(AdminFormat.kg(sum.kg)),
                      Text(AdminFormat.integer(sum.wallet.balance)),
                    ], onTap: () => _showProvider(context, data, u, sum));
                  }(),
              ],
            ),
          ),
        ];
      },
    );
  }

  void _showProvider(BuildContext context, AdminData data, AdminUser u, ProviderSummary sum) {
    final s = AdminStrings.of(appLanguage.value);
    final posts = data.requests.where((r) => r.householdUid == u.uid).toList();
    showAdminDetail(context, title: u.displayName, children: [
      DetailLine(s.email, u.email.isEmpty ? '—' : u.email),
      DetailLine(s.colPhone, u.phone.isEmpty ? '—' : '${u.phone}${u.phoneVerified ? ' ✓' : ''}'),
      DetailLine(s.address, u.address.isEmpty ? '—' : u.address),
      DetailLine(s.colJoined, AdminFormat.date(u.createdAt)),
      DetailLine(s.colPoints, AdminFormat.integer(sum.wallet.balance)),
      DetailLine(s.lifetimePoints, AdminFormat.integer(sum.wallet.lifetimeEarned)),
      DetailLine('UID', u.uid),
      DetailSection('${s.historyTitle} (${posts.length})'),
      if (posts.isEmpty) Text(s.noResults, style: TextStyle(color: AppColors.textGray)),
      for (final r in posts.take(20)) RequestLine(r),
    ]);
  }
}

/// Recherche dans le nom, l'email, le téléphone ou l'entreprise.
bool matchesUser(AdminUser u, String query) {
  if (query.isEmpty) return true;
  return [u.displayName, u.email, u.phone, u.companyName ?? '', u.uid].any((f) => f.toLowerCase().contains(query));
}

/// Ligne résumée d'une demande, dans les fenêtres de détail.
class RequestLine extends StatelessWidget {
  final CollectionRequest r;
  const RequestLine(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final fr = appLanguage.value == AppLanguage.fr;
    final weight = r.weightKg != null ? AdminFormat.kg(r.weightKg) : r.quantityRange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(r.category.icon, size: 16, color: AppColors.textGray),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${r.reference} · ${r.category.label(fr)} · $weight · ${AdminFormat.date(r.createdAt)}',
              style: TextStyle(color: AppColors.mainText, fontSize: 13)),
        ),
        StatusChip.request(r.status),
      ]),
    );
  }
}
