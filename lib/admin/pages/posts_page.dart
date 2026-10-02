import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../widgets/waste_photo_image.dart';
import '../admin_format.dart';
import '../admin_strings.dart';
import '../services/admin_data.dart';
import '../widgets/admin_widgets.dart';

/// Tous les posts de déchets (`collectionRequests`), en cartes avec photo,
/// filtrables ; un post encore libre peut être retiré (modération).
class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  static const _pageSize = 24;

  String _query = '';
  RequestStatus? _status;
  WasteCategory? _category;
  int _shown = _pageSize;

  bool _matches(AdminData data, CollectionRequest r) {
    if (_status != null && r.status != _status) return false;
    if (_category != null && r.category != _category) return false;
    if (_query.isEmpty) return true;
    return [
      r.reference,
      data.nameOf(r.householdUid, fallback: r.householdName),
      r.address,
      r.city ?? '',
      r.neighborhood ?? '',
      r.description,
    ].any((f) => f.toLowerCase().contains(_query));
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return AdminPage(
      title: s.navPosts,
      subtitle: s.postsSubtitle,
      actions: [
        DropdownButton<WasteCategory?>(
          value: _category,
          underline: const SizedBox.shrink(),
          dropdownColor: AppColors.card,
          items: [
            DropdownMenuItem(value: null, child: Text(s.allCategories)),
            for (final c in WasteCategory.values) DropdownMenuItem(value: c, child: Text(c.label(s.fr))),
          ],
          onChanged: (c) => setState(() {
            _category = c;
            _shown = _pageSize;
          }),
        ),
        AdminSearchField(onChanged: (v) => setState(() {
              _query = v.trim().toLowerCase();
              _shown = _pageSize;
            })),
      ],
      builder: (context, data) {
        final posts = data.requests.where((r) => _matches(data, r)).toList();
        return [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: Text('${s.all} (${data.requests.length})'),
              selected: _status == null,
              onSelected: (_) => setState(() => _status = null),
            ),
            for (final status in RequestStatus.values)
              ChoiceChip(
                label: Text('${status.label(s.fr)} (${data.stats.count(status)})'),
                selected: _status == status,
                onSelected: (_) => setState(() {
                  _status = status;
                  _shown = _pageSize;
                }),
              ),
          ]),
          const SizedBox(height: 16),
          if (posts.isEmpty)
            AdminCard(child: Center(child: Text(s.noResults, style: TextStyle(color: AppColors.textGray))))
          else
            ResponsiveGrid(
              minItemWidth: 280,
              children: [for (final r in posts.take(_shown)) _PostCard(request: r, providerName: data.nameOf(r.householdUid, fallback: r.householdName))],
            ),
          if (posts.length > _shown)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: OutlinedButton(
                  onPressed: () => setState(() => _shown += _pageSize),
                  child: Text('${s.next} (${posts.length - _shown})'),
                ),
              ),
            ),
        ];
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final CollectionRequest request;
  final String providerName;

  const _PostCard({required this.request, required this.providerName});

  Future<void> _remove(BuildContext context) async {
    final s = AdminStrings.of(appLanguage.value);
    final data = AdminDataScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(s.removePostTitle),
        content: Text(s.removePostBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.removePost),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await data.repository.cancelPost(request.id);
      messenger.showSnackBar(SnackBar(content: Text(s.removed)));
    } catch (e) {
      debugPrint('cancelPost(${request.id}) : $e');
      messenger.showSnackBar(SnackBar(content: Text(s.removeFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    final r = request;
    final place = [r.neighborhood, r.city].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
    final muted = TextStyle(color: AppColors.textGray, fontSize: 12.5);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          WastePhotoImage(url: r.imageUrl, height: 160, width: double.infinity),
          Positioned(top: 10, left: 10, child: _OnPhoto(StatusChip.request(r.status))),
        ]),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(r.category.icon, size: 18, color: r.category.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${r.category.label(s.fr)} · ${r.quantityRange}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.mainText)),
              ),
              Text(r.reference, style: muted),
            ]),
            const SizedBox(height: 6),
            Text(providerName, style: TextStyle(color: AppColors.mainText, fontWeight: FontWeight.w600)),
            Text(
              [if (place.isNotEmpty) place else r.address, if (r.locationIsApproximate) s.approxLocation]
                  .where((p) => p.isNotEmpty)
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
            if (r.aiSuggestedCategory != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${s.aiSuggested} : ${r.aiSuggestedCategory!.label(s.fr)}'
                  '${r.aiConfidence != null ? ' (${s.aiConfidence((r.aiConfidence! * 100).round())})' : ''}',
                  style: muted,
                ),
              ),
            if (r.collectorUid != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${s.colCollector} : ${AdminDataScope.of(context).nameOf(r.collectorUid, fallback: r.collectorName)}',
                    style: muted),
              ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(AdminFormat.dateTime(r.createdAt), style: muted)),
              if (r.status == RequestStatus.pending)
                TextButton.icon(
                  onPressed: () => _remove(context),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(s.removePost),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Fond opaque pour qu'une pastille reste lisible sur n'importe quelle photo.
class _OnPhoto extends StatelessWidget {
  final Widget child;
  const _OnPhoto(this.child);

  @override
  Widget build(BuildContext context) =>
      DecoratedBox(decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)), child: child);
}
