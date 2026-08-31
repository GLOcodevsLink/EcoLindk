import 'package:flutter/material.dart';
import '../core/l10n/strings.dart';

/// Deux types d'acteurs peuvent s'inscrire sur EcoLindk : Ménage et Collecteur.
/// (La "Recycling Unit" a été fusionnée dans Collecteur : la plupart des
/// collecteurs travaillent pour une entreprise, qui peut aussi les inscrire
/// directement dans l'app — un seul acteur commun, avec juste une question
/// "indépendant ou en entreprise ?" pour distinguer les deux cas.)
enum UserRole { household, collector }

/// Pour un Collecteur : travaille seul, ou pour une entreprise.
enum WorkStatus { independent, company }

extension UserRoleLabel on UserRole {
  String label(AppStrings s) {
    switch (this) {
      case UserRole.household:
        return s.roleHousehold;
      case UserRole.collector:
        return s.roleCollector;
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.household:
        return Icons.home_outlined;
      case UserRole.collector:
        return Icons.local_shipping_outlined;
    }
  }
}
