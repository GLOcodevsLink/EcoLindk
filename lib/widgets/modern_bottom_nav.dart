import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Un onglet de [ModernBottomNav] : icône contour (inactif) + icône pleine
/// (actif), libellé, et un compteur optionnel (badge) affiché en overlay.
class ModernNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Stream<int>? badge;
  const ModernNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}

/// Barre de navigation basse "flottante", façon Material 3 (voir les
/// composants `NavigationBar` des démos officielles Flutter) : une carte
/// arrondie détachée des bords de l'écran, un fond EN VERRE DÉPOLI (flou +
/// translucide, demande explicite : "effet plus glass like"), un fond en
/// pilule elle-même vitrée qui apparaît derrière l'onglet actif (icône
/// pleine en dégradé + libellé bien visible), et une icône simple (sans
/// libellé) pour les onglets inactifs.
///
/// Un [centerAction] optionnel (le bouton Scanner) peut être fourni pour
/// rester au milieu, surélevé au-dessus de la barre.
class ModernBottomNav extends StatelessWidget {
  final List<ModernNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget? centerAction;

  const ModernBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.centerAction,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final half = (items.length / 2).ceil();
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      // Un espace réservé de la largeur du bouton central, plutôt que le
      // widget lui-même : [centerAction] (le bouton Scanner) est plus haut
      // que la barre et flotte au-dessus via son propre Transform.translate
      // — le poser directement dans cette Row à hauteur fixe le ferait
      // déborder verticalement (RenderFlex overflow). Il est plutôt peint
      // par-dessus via le Stack ci-dessous, indépendant de cette hauteur.
      if (centerAction != null && i == half) {
        children.add(const SizedBox(width: 72));
      }
      children.add(Expanded(child: _NavItemView(
        item: items[i],
        active: i == currentIndex,
        onTap: () => onTap(i),
      )));
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Verre dépoli : flou du contenu qui défile derrière la barre +
          // fond très translucide + liseré clair en haut, façon vitre.
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card.withOpacity(isDarkMode ? 0.55 : 0.62),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Colors.white.withOpacity(isDarkMode ? 0.10 : 0.55),
                      width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8)),
                  ],
                ),
                // Hauteur fixe explicite — sans ça, Scaffold mesure
                // bottomNavigationBar avec une contrainte de hauteur "lâche"
                // mais très grande (tout l'écran disponible), et Container
                // s'y étend (voir la doc de [_NavItemView]), écrasant le
                // contenu de la page.
                child: SizedBox(
                  // Agrandi (58 -> 68, demande explicite : "les éléments...
                  // sont trop petits, agrandis-les") — icônes et libellé
                  // plus grands ci-dessous en profitent sans être écrasés.
                  height: 68,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
          if (centerAction != null) centerAction!,
        ],
      ),
    );
  }
}

class _NavItemView extends StatelessWidget {
  final ModernNavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavItemView(
      {required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Libellé actif nettement plus foncé/contrasté que l'icône inactive
    // (demande explicite : "le texte... doit être plus visible") — le vert
    // de marque le plus foncé, pas le même ton que l'icône inactive.
    final labelColor = isDarkMode ? Colors.white : AppColors.greenDark;
    final iconColor = active
        ? (isDarkMode ? Colors.white : AppColors.greenDark)
        : AppColors.textGray;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        // Pas d'`alignment` ici : sur un Container, `alignment` déclenche un
        // comportement "s'étend pour remplir l'espace disponible" dès que
        // les contraintes entrantes sont bornées (même très grandes) — voir
        // la hauteur fixe posée dans [ModernBottomNav.build]. Le centrage
        // horizontal/vertical du contenu est déjà assuré par le
        // [FittedBox] ci-dessous (alignment centré par défaut).
        padding: EdgeInsets.symmetric(horizontal: active ? 16 : 13, vertical: 12),
        decoration: BoxDecoration(
          // Pilule vitrée elle-même (demande explicite : "le container de
          // ces éléments doit avoir un effet plus glass") — un dégradé
          // translucide clair→plus doux plutôt qu'un aplat uni, avec un
          // liseré lumineux comme un vrai reflet de verre.
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(isDarkMode ? 0.22 : 0.55),
                    AppColors.greenMid.withOpacity(isDarkMode ? 0.28 : 0.30),
                  ],
                )
              : null,
          border: active
              ? Border.all(
                  color: Colors.white.withOpacity(isDarkMode ? 0.18 : 0.65),
                  width: 1)
              : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          // FittedBox : garde-fou anti-débordement — quel que soit le
          // libellé (ex. "Portefeuille"/"Wallet", plus long que
          // "Accueil"/"Home") ou la largeur réellement allouée par onglet,
          // le contenu se réduit plutôt que déborder.
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Icône active en dégradé de marque (plus "riche"/coloré
                  // qu'un simple aplat — demande explicite : "les logos...
                  // doivent être plus beaux") plutôt qu'un vert uni.
                  if (active)
                    ShaderMask(
                      shaderCallback: (rect) =>
                          AppColors.buttonGradient.createShader(rect),
                      child: Icon(item.activeIcon, size: 28, color: Colors.white),
                    )
                  else
                    Icon(item.icon, size: 26, color: iconColor),
                  if (item.badge != null)
                    StreamBuilder<int>(
                      stream: item.badge,
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: -7,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.redAccent, shape: BoxShape.circle),
                            child: Text(count > 9 ? '9+' : '$count',
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
                ],
              ),
              // Le libellé n'apparaît que sur l'onglet actif — pas
              // d'AnimatedSize ici (incompatible avec le calcul de layout
              // "dry" que Scaffold utilise pour dimensionner
              // bottomNavigationBar : ça faisait occuper toute la hauteur de
              // l'écran à la barre, écrasant le contenu de la page en dessous).
              if (active) ...[
                const SizedBox(width: 7),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: labelColor,
                        shadows: [
                          Shadow(
                              color: Colors.white.withOpacity(0.6),
                              blurRadius: 2),
                        ])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
