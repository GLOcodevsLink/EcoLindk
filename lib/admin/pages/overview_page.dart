import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../admin_format.dart';
import '../admin_strings.dart';
import '../widgets/admin_charts.dart';
import '../widgets/admin_widgets.dart';

/// Statistiques globales de la plateforme.
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return AdminPage(
      title: s.navOverview,
      subtitle: s.overviewSubtitle,
      builder: (context, data) {
        final st = data.stats;
        final wide = MediaQuery.sizeOf(context).width >= 1200;
        final charts = [
          AdminCard(title: s.chartPostsPerDay, child: PostsPerDayChart(points: st.postsPerDay)),
          AdminCard(title: s.chartKgByCategory, child: KgByCategoryChart(kgByCategory: st.kgByCategory)),
        ];
        return [
          ResponsiveGrid(children: [
            StatTile(
              icon: RemixIcons.home_4_line,
              label: s.kpiProviders,
              value: AdminFormat.integer(st.providers),
              detail: st.incompleteAccounts > 0 ? s.incompleteAccounts(st.incompleteAccounts) : null,
            ),
            StatTile(icon: RemixIcons.truck_line, label: s.kpiCollectors, value: AdminFormat.integer(st.collectors)),
            StatTile(
              icon: RemixIcons.recycle_line,
              label: s.kpiOpenPosts,
              value: AdminFormat.integer(st.count(RequestStatus.pending)),
            ),
            StatTile(
              icon: RemixIcons.checkbox_circle_line,
              label: s.kpiCompleted,
              value: AdminFormat.integer(st.count(RequestStatus.completed)),
              detail: s.completionRate(st.completionRatePct),
            ),
            StatTile(icon: RemixIcons.scales_3_line, label: s.kpiKg, value: AdminFormat.kg(st.kgCollected)),
            StatTile(icon: RemixIcons.money_dollar_circle_line, label: s.kpiValue, value: AdminFormat.fcfa(st.valueFcfa)),
            StatTile(
              icon: RemixIcons.bank_card_line,
              label: s.kpiOutstanding,
              value: AdminFormat.fcfa(st.commissionOutstandingFcfa),
              detail: s.paidOf(AdminFormat.fcfa(st.commissionPaidFcfa)),
            ),
            StatTile(icon: RemixIcons.trophy_line, label: s.kpiPoints, value: AdminFormat.integer(st.pointsAwarded)),
          ]),
          const SizedBox(height: 16),
          if (wide)
            // Pas d'IntrinsicHeight : les graphiques utilisent LayoutBuilder.
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: charts[0]),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: charts[1]),
            ])
          else ...[
            charts[0],
            const SizedBox(height: 16),
            charts[1],
          ],
          const SizedBox(height: 16),
          ResponsiveGrid(minItemWidth: 380, children: [
            AdminCard(
              title: s.statusBreakdown,
              child: Column(children: [
                for (final status in RequestStatus.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      StatusChip.request(status),
                      const Spacer(),
                      Text(AdminFormat.integer(st.count(status)),
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.mainText)),
                    ]),
                  ),
              ]),
            ),
            AdminCard(
              title: s.recentPosts,
              child: data.requests.isEmpty
                  ? Text(s.noResults, style: TextStyle(color: AppColors.textGray))
                  : Column(children: [
                      for (final r in data.requests.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Icon(r.category.icon, size: 18, color: AppColors.textGray),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(data.nameOf(r.householdUid, fallback: r.householdName),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppColors.mainText, fontWeight: FontWeight.w600)),
                                Text('${r.category.label(s.fr)} · ${r.quantityRange} · ${AdminFormat.dateTime(r.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                              ]),
                            ),
                            StatusChip.request(r.status),
                          ]),
                        ),
                    ]),
            ),
          ]),
        ];
      },
    );
  }
}
