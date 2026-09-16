import 'package:flutter/material.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import '../core/theme.dart';

/// Icône globe permettant de basculer l'application entre français et anglais.
/// Placée en haut à droite du Landing (et réutilisable sur d'autres écrans).
class LanguageSwitcher extends StatelessWidget {
  final Color? iconColor;
  const LanguageSwitcher({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final s = AppStrings.of(lang);
        return PopupMenuButton<AppLanguage>(
          icon: Icon(Icons.language, color: iconColor ?? AppColors.heading),
          color: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) => appLanguage.value = value,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: AppLanguage.fr,
              child: Row(
                children: [
                  if (lang == AppLanguage.fr)
                    Icon(Icons.check, size: 16, color: AppColors.heading)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(s.french),
                ],
              ),
            ),
            PopupMenuItem(
              value: AppLanguage.en,
              child: Row(
                children: [
                  if (lang == AppLanguage.en)
                    Icon(Icons.check, size: 16, color: AppColors.heading)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(s.english),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
