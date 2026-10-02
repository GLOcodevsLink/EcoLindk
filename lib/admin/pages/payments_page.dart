import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../models/wallet_models.dart';
import '../admin_format.dart';
import '../admin_strings.dart';
import '../services/admin_stats.dart';
import '../widgets/admin_widgets.dart';

/// Paiements : commissions réglées par les collecteurs (CommissionService)
/// et conversions de points des fournisseurs (WalletService.redeem).
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _redemptions = false;

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return AdminPage(
      title: s.navPayments,
      subtitle: s.paymentsSubtitle,
      actions: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(s.tabCommissions)),
            ButtonSegment(value: true, label: Text(s.tabRedemptions)),
          ],
          selected: {_redemptions},
          onSelectionChanged: (v) => setState(() => _redemptions = v.first),
        ),
      ],
      builder: (context, data) {
        final st = data.stats;
        if (_redemptions) {
          final completed = data.redemptions.where((r) => r.request.status == RedemptionStatus.completed).length;
          return [
            ResponsiveGrid(children: [
              StatTile(icon: Icons.swap_horiz_rounded, label: s.totalRedeemed, value: AdminFormat.fcfa(st.redeemedFcfa)),
              StatTile(icon: Icons.check_circle_outline_rounded, label: s.paymentStatus('completed'), value: '$completed'),
              StatTile(
                icon: Icons.schedule_rounded,
                label: s.totalPending,
                value: '${data.redemptions.length - completed}',
              ),
            ]),
            const SizedBox(height: 16),
            AdminCard(
              padding: const EdgeInsets.all(8),
              child: AdminTable(
                columns: [s.colDate, s.colProvider, s.colMethod, s.colPoints, s.colAmount, s.colPhone, s.colStatus],
                numeric: const {3, 4},
                rows: [
                  for (final r in data.redemptions)
                    AdminRow([
                      Text(AdminFormat.dateTime(r.request.createdAt)),
                      Text(data.nameOf(r.uid)),
                      Text(s.redemptionMethod(r.request.method.name)),
                      Text(AdminFormat.integer(r.request.pointsSpent)),
                      Text(AdminFormat.fcfa(r.request.amountFcfa)),
                      Text(r.request.recipientPhone),
                      StatusChip.payment(r.request.status.name),
                    ]),
                ],
              ),
            ),
          ];
        }
        return [
          AdminNote(s.testModeNote),
          const SizedBox(height: 16),
          ResponsiveGrid(children: [
            StatTile(icon: Icons.account_balance_wallet_outlined, label: s.totalPaid, value: AdminFormat.fcfa(st.commissionPaidFcfa)),
            StatTile(
              icon: Icons.receipt_long_outlined,
              label: s.kpiOutstanding,
              value: AdminFormat.fcfa(st.commissionOutstandingFcfa),
            ),
            StatTile(icon: Icons.error_outline_rounded, label: s.totalFailed, value: '${st.failedPayments}'),
            StatTile(icon: Icons.schedule_rounded, label: s.totalPending, value: '${st.pendingPayments}'),
          ]),
          const SizedBox(height: 16),
          AdminCard(
            padding: const EdgeInsets.all(8),
            child: AdminTable(
              columns: [s.colDate, s.colCollector, s.colAmount, s.colOperator, s.colPhone, s.colMode, s.colStatus, s.colMessage],
              numeric: const {2},
              rows: [
                for (final p in data.commissionPayments)
                  AdminRow([
                    Text(AdminFormat.dateTime(p.createdAt)),
                    Text(data.nameOf(p.collectorUid)),
                    Text(AdminFormat.fcfa(p.amountFcfa)),
                    Text(operatorLabel(p.channel)),
                    Text(p.phone),
                    Text(p.mode),
                    StatusChip.payment(p.status),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(p.message ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
              ],
            ),
          ),
        ];
      },
    );
  }
}
