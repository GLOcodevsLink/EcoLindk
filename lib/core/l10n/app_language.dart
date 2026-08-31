import 'package:flutter/material.dart';

/// Langues disponibles dans l'application.
enum AppLanguage { fr, en }

/// Langue actuellement sélectionnée, observable dans toute l'application.
/// Changer cette valeur (ex: appLanguage.value = AppLanguage.en) met à jour
/// tous les écrans qui écoutent via ValueListenableBuilder.
final ValueNotifier<AppLanguage> appLanguage = ValueNotifier(AppLanguage.fr);
