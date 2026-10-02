import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../admin_format.dart';
import '../admin_strings.dart';

/// Couleur des barres — une seule série par graphique, donc une seule
/// teinte de marque, contraste ≥ 3:1 vérifié sur la carte claire et sombre.
Color get _barColor => isDarkMode ? AppColors.greenMid : AppColors.greenDark;

/// Histogramme des posts publiés par jour, avec info-bulle au survol de
/// chaque colonne et une vue tableau équivalente.
class PostsPerDayChart extends StatefulWidget {
  final List<({DateTime day, int count})> points;
  const PostsPerDayChart({super.key, required this.points});

  @override
  State<PostsPerDayChart> createState() => _PostsPerDayChartState();
}

class _PostsPerDayChartState extends State<PostsPerDayChart> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _table = !_table),
            icon: Icon(_table ? Icons.bar_chart_rounded : Icons.table_rows_outlined, size: 18),
            label: Text(_table ? s.showChart : s.showTable),
          ),
        ),
        _table ? _buildTable(s) : _buildChart(s),
      ],
    );
  }

  Widget _buildTable(AdminStrings s) => Column(children: [
        for (final p in widget.points.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text(AdminFormat.date(p.day), style: TextStyle(color: AppColors.textGray))),
              Text('${p.count}', style: TextStyle(color: AppColors.mainText, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]);

  Widget _buildChart(AdminStrings s) {
    final max = widget.points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final top = max == 0 ? 1 : max;
    const plotHeight = 180.0;
    final axisStyle = TextStyle(color: AppColors.textGray, fontSize: 11);
    return Column(children: [
      SizedBox(
        height: plotHeight,
        child: Stack(children: [
          // Repères discrets : maximum et ligne de base.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Row(children: [
              Text('$top', style: axisStyle),
              const SizedBox(width: 6),
              Expanded(child: Divider(color: AppColors.line, height: 1, thickness: 0.6)),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(color: AppColors.line, height: 1, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in widget.points)
                  Expanded(
                    // Zone de survol = toute la colonne, pas seulement la barre.
                    child: Tooltip(
                      message: s.postsOnDay(p.count, AdminFormat.date(p.day)),
                      waitDuration: Duration.zero,
                      child: Container(
                        height: plotHeight,
                        color: Colors.transparent,
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FractionallySizedBox(
                          heightFactor: p.count == 0 ? 0.0 : (p.count / top).clamp(0.02, 1.0),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 36),
                            decoration: BoxDecoration(
                              color: _barColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.only(left: 22),
        child: Row(children: [
          for (var i = 0; i < widget.points.length; i++)
            Expanded(
              child: Text(
                // Un jour sur deux, plus le dernier (aujourd'hui).
                i.isEven || i == widget.points.length - 1 ? AdminFormat.dayMonth(widget.points[i].day) : '',
                textAlign: TextAlign.center,
                style: axisStyle,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Kg collectés par catégorie : barres horizontales, valeur écrite au bout
/// de chaque barre (étiquetage direct, pas de légende).
class KgByCategoryChart extends StatelessWidget {
  final Map<WasteCategory, double> kgByCategory;
  const KgByCategoryChart({super.key, required this.kgByCategory});

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    final entries = WasteCategory.values.map((c) => (category: c, kg: kgByCategory[c] ?? 0)).toList()
      ..sort((a, b) => b.kg.compareTo(a.kg));
    final max = entries.first.kg;
    if (max == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(s.noCollectedYet, style: TextStyle(color: AppColors.textGray)),
      );
    }
    return Column(children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(e.category.icon, size: 18, color: AppColors.textGray),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              child: Text(e.category.label(s.fr),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.mainText, fontSize: 13)),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 14,
                    width: e.kg == 0 ? 0 : (c.maxWidth * e.kg / max).clamp(3, c.maxWidth),
                    decoration: BoxDecoration(
                      color: _barColor,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(AdminFormat.kg(e.kg),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppColors.mainText, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
    ]);
  }
}
