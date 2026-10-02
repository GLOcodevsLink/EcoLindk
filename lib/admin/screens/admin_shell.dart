import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../widgets/app_logo.dart';
import '../admin_strings.dart';
import '../pages/collections_page.dart';
import '../pages/collectors_page.dart';
import '../pages/overview_page.dart';
import '../pages/payments_page.dart';
import '../pages/posts_page.dart';
import '../pages/providers_page.dart';
import '../services/admin_auth.dart';
import '../services/admin_data.dart';
import '../services/admin_repository.dart';

enum AdminSection { overview, providers, collectors, posts, collections, payments }

extension on AdminSection {
  String label(AdminStrings s) => switch (this) {
        AdminSection.overview => s.navOverview,
        AdminSection.providers => s.navProviders,
        AdminSection.collectors => s.navCollectors,
        AdminSection.posts => s.navPosts,
        AdminSection.collections => s.navCollections,
        AdminSection.payments => s.navPayments,
      };

  IconData get icon => switch (this) {
        AdminSection.overview => RemixIcons.dashboard_line,
        AdminSection.providers => RemixIcons.home_4_line,
        AdminSection.collectors => RemixIcons.truck_line,
        AdminSection.posts => RemixIcons.recycle_line,
        AdminSection.collections => RemixIcons.scales_3_line,
        AdminSection.payments => RemixIcons.bank_card_line,
      };

  Widget get page => switch (this) {
        AdminSection.overview => const OverviewPage(),
        AdminSection.providers => const ProvidersPage(),
        AdminSection.collectors => const CollectorsPage(),
        AdminSection.posts => const PostsPage(),
        AdminSection.collections => const CollectionsPage(),
        AdminSection.payments => const PaymentsPage(),
      };
}

/// Structure du tableau de bord : barre latérale (étendue ≥ 1100 px,
/// réduite aux icônes ≥ 700 px, tiroir en dessous) + page courante. Possède
/// l'unique [AdminData] partagé par toutes les pages.
class AdminShell extends StatefulWidget {
  final AdminAuth auth;
  final AdminRepository repository;
  final User user;

  const AdminShell({super.key, required this.auth, required this.repository, required this.user});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final AdminData _data = AdminData(widget.repository);
  AdminSection _section = AdminSection.overview;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  void _select(AdminSection section) => setState(() => _section = section);

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    final width = MediaQuery.sizeOf(context).width;
    final drawerMode = width < 700;
    final page = AdminDataScope(data: _data, child: KeyedSubtree(key: ValueKey(_section), child: _section.page));

    if (drawerMode) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          title: Text(_section.label(s), style: TextStyle(color: AppColors.mainText, fontWeight: FontWeight.w700)),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.card,
          child: _Sidebar(
            extended: true,
            selected: _section,
            email: widget.user.email ?? '',
            onSelect: (section) {
              Navigator.pop(context);
              _select(section);
            },
            onSignOut: widget.auth.signOut,
          ),
        ),
        body: page,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(children: [
        _Sidebar(
          extended: width >= 1100,
          selected: _section,
          email: widget.user.email ?? '',
          onSelect: _select,
          onSignOut: widget.auth.signOut,
        ),
        VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
        Expanded(child: page),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool extended;
  final AdminSection selected;
  final String email;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.extended,
    required this.selected,
    required this.email,
    required this.onSelect,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return Container(
      width: extended ? 248 : 76,
      color: AppColors.card,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: extended ? 20 : 12),
            child: extended
                ? Row(children: [
                    const AppLogo(width: 110),
                    const SizedBox(width: 8),
                    Text('Admin', style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w600)),
                  ])
                : const AppLogo(width: 44, iconOnly: true),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final section in AdminSection.values)
                  _NavItem(
                    icon: section.icon,
                    label: section.label(s),
                    extended: extended,
                    selected: section == selected,
                    onTap: () => onSelect(section),
                  ),
              ],
            ),
          ),
          Divider(color: AppColors.line, height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _NavItem(
                icon: isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                label: s.darkMode,
                extended: extended,
                onTap: () => appThemeMode.value = isDarkMode ? ThemeMode.light : ThemeMode.dark,
              ),
              _NavItem(
                icon: Icons.translate_rounded,
                label: s.language,
                extended: extended,
                onTap: () => appLanguage.value = s.fr ? AppLanguage.en : AppLanguage.fr,
              ),
              _NavItem(icon: Icons.logout_rounded, label: s.signOut, extended: extended, onTap: onSignOut),
              if (extended && email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(email,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool extended;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.extended,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.heading : AppColors.textGray;
    final item = Material(
      color: selected ? AppColors.greenMid.withValues(alpha: isDarkMode ? 0.25 : 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              if (extended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: extended ? item : Tooltip(message: label, child: item),
    );
  }
}
