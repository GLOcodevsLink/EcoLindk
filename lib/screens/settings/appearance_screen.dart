import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/language_switcher.dart';

/// Mode d'affichage : clair / sombre. Écrit directement dans [appThemeMode]
/// (voir core/theme.dart) — persisté automatiquement par main.dart, quel que
/// soit l'écran qui déclenche le changement.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: appLanguage,
          builder: (context, lang, _) {
            final s = AppStrings.of(lang);
            return Scaffold(
              backgroundColor: AppColors.surface,
              body: Stack(
                children: [
                  const DecorativeLeaves(subtle: true),
                  SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.arrow_back, color: AppColors.heading),
                            ),
                            Expanded(
                              child: Text(s.appearanceTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.heading)),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(s.appearanceDesc,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                  height: 1.5)),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.dark_mode_outlined,
                                  color: AppColors.greenDeep, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(s.settingDarkMode,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mainText)),
                              ),
                              Switch(
                                value: isDarkMode,
                                activeColor: AppColors.greenMid,
                                onChanged: (v) => appThemeMode.value =
                                    v ? ThemeMode.dark : ThemeMode.light,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.language,
                                  color: AppColors.greenDeep, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    lang == AppLanguage.fr ? "Langue" : "Language",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mainText)),
                              ),
                              Text(
                                  lang == AppLanguage.fr ? s.french : s.english,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textGray,
                                      fontWeight: FontWeight.w600)),
                              const LanguageSwitcher(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
