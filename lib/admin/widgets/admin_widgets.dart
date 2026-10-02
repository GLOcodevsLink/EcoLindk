import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../admin_strings.dart';
import '../services/admin_data.dart';

/// Cadre commun d'une page : titre, sous-titre, actions, puis contenu.
/// Affiche le chargement initial et les erreurs de lecture d'AdminData.
class AdminPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> Function(BuildContext context, AdminData data) builder;

  const AdminPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final data = AdminDataScope.of(context);
    final s = AdminStrings.of(appLanguage.value);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final pad = narrow ? 16.0 : 28.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppColors.textGray)),
              ],
            ),
            if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: 20),
        if (data.error != null)
          _Banner(icon: Icons.error_outline_rounded, text: s.loadError(_errorCode(data.error!)), error: true)
        else if (data.loading)
          const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
        else
          ...builder(context, data),
      ],
    );
  }

  static String _errorCode(Object e) {
    final text = e.toString();
    return text.contains('permission-denied') ? 'permission-denied' : text.split('\n').first;
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;

  const _Banner({required this.icon, required this.text, this.error = false});

  @override
  Widget build(BuildContext context) {
    final color = error ? Theme.of(context).colorScheme.error : AppColors.heading;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: AppColors.mainText))),
      ]),
    );
  }
}

/// Bandeau d'information (ex. "mode test" sur Paiements).
class AdminNote extends StatelessWidget {
  final String text;
  const AdminNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => _Banner(icon: Icons.info_outline_rounded, text: text);
}

/// Carte à titre (graphiques, listes, tableaux).
class AdminCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  const AdminCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(children: [
              Expanded(
                child: Text(title!,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.mainText)),
              ),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Tuile de chiffre clé.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  const StatTile({super.key, required this.icon, required this.label, required this.value, this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: AppColors.lightIconGradient, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textGray, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textGray, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Grille responsive : autant de colonnes que la largeur le permet.
class ResponsiveGrid extends StatelessWidget {
  final double minItemWidth;
  final List<Widget> children;
  final double spacing;

  const ResponsiveGrid({super.key, this.minItemWidth = 220, required this.children, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columns = (c.maxWidth / minItemWidth).floor().clamp(1, children.isEmpty ? 1 : children.length);
      final width = (c.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}

/// Pastille de statut : icône + texte, jamais la couleur seule.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const StatusChip({super.key, required this.label, required this.color, required this.icon});

  factory StatusChip.request(RequestStatus status) {
    final fr = appLanguage.value == AppLanguage.fr;
    final (color, icon) = switch (status) {
      RequestStatus.pending => (const Color(0xFFB7861F), Icons.schedule_rounded),
      RequestStatus.accepted => (AppColors.navy, Icons.local_shipping_outlined),
      RequestStatus.inProgress => (const Color(0xFF2E6E4E), Icons.qr_code_2_rounded),
      RequestStatus.completed => (AppColors.authGreenDeep, Icons.check_circle_outline_rounded),
      RequestStatus.cancelled => (const Color(0xFF6B7280), Icons.block_rounded),
    };
    return StatusChip(label: status.label(fr), color: color, icon: icon);
  }

  /// Statut d'un paiement (`success`, `pending`, `failed`…).
  factory StatusChip.payment(String status) {
    final s = AdminStrings.of(appLanguage.value);
    final (color, icon) = switch (status) {
      'success' || 'completed' => (AppColors.authGreenDeep, Icons.check_circle_outline_rounded),
      'pending' => (const Color(0xFFB7861F), Icons.schedule_rounded),
      _ => (const Color(0xFFC0392B), Icons.error_outline_rounded),
    };
    return StatusChip(label: s.paymentStatus(status), color: color, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    // En sombre, la couleur est éclaircie pour rester lisible sur la carte.
    final fg = isDarkMode ? Color.lerp(color, Colors.white, 0.55)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: isDarkMode ? 0.25 : 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Champ de recherche des pages de liste.
class AdminSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const AdminSearchField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return SizedBox(
      width: 280,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: s.search,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
        ),
      ),
    );
  }
}

/// Une ligne de [AdminTable].
class AdminRow {
  final List<Widget> cells;
  final VoidCallback? onTap;
  const AdminRow(this.cells, {this.onTap});
}

/// Tableau paginé (25 lignes par page), défilant horizontalement sur petit
/// écran.
class AdminTable extends StatefulWidget {
  final List<String> columns;

  /// Index des colonnes numériques (alignées à droite).
  final Set<int> numeric;
  final List<AdminRow> rows;
  final int pageSize;

  const AdminTable({super.key, required this.columns, required this.rows, this.numeric = const {}, this.pageSize = 25});

  @override
  State<AdminTable> createState() => _AdminTableState();
}

class _AdminTableState extends State<AdminTable> {
  int _page = 0;

  @override
  void didUpdateWidget(AdminTable old) {
    super.didUpdateWidget(old);
    // Filtre changé : la page courante peut ne plus exister.
    final last = widget.rows.isEmpty ? 0 : (widget.rows.length - 1) ~/ widget.pageSize;
    if (_page > last) _page = last;
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    if (widget.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(s.noResults, style: TextStyle(color: AppColors.textGray))),
      );
    }
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, widget.rows.length);
    final visible = widget.rows.sublist(start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textGray, fontSize: 12.5),
                dataTextStyle: TextStyle(color: AppColors.mainText, fontSize: 13.5),
                dividerThickness: 0.6,
                columns: [
                  for (var i = 0; i < widget.columns.length; i++)
                    DataColumn(label: Text(widget.columns[i]), numeric: widget.numeric.contains(i)),
                ],
                rows: [
                  for (final row in visible)
                    DataRow(
                      onSelectChanged: row.onTap == null ? null : (_) => row.onTap!(),
                      cells: [for (final cell in row.cells) DataCell(cell)],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.rows.length > widget.pageSize)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(s.pageOf(start + 1, end, widget.rows.length), style: TextStyle(color: AppColors.textGray)),
              const SizedBox(width: 8),
              IconButton(
                tooltip: s.previous,
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: s.next,
                onPressed: end >= widget.rows.length ? null : () => setState(() => _page++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ]),
          ),
      ],
    );
  }
}

/// Ligne "libellé : valeur" des fenêtres de détail.
class DetailLine extends StatelessWidget {
  final String label;
  final String value;
  const DetailLine(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(label, style: TextStyle(color: AppColors.textGray))),
          Expanded(child: SelectableText(value, style: TextStyle(color: AppColors.mainText))),
        ]),
      );
}

/// Fenêtre de détail (utilisateur, post…).
Future<void> showAdminDetail(BuildContext context, {required String title, required List<Widget> children}) {
  final s = AdminStrings.of(appLanguage.value);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title, style: TextStyle(color: AppColors.mainText, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close))],
    ),
  );
}

/// Sous-titre de section dans une fenêtre de détail.
class DetailSection extends StatelessWidget {
  final String title;
  const DetailSection(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.heading)),
      );
}
