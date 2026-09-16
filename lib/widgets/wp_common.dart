import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/collection_request.dart';

/// Petits widgets partagés par les écrans du module Fournisseur de déchets
/// (dashboard, suivi de collecte, historique, portefeuille…) — gardés ici
/// pour éviter de dupliquer les mêmes cartes/badges/états vides dans chaque
/// écran.

/// Le "logo" utilisé par TOUTE petite boîte de l'app (action rapide,
/// statistique, réglage, ligne de liste…) — boîte blanche (squircle, carré
/// très arrondi) avec une icône dans le même vert en dégradé que la carte
/// "Mes points" ([AppColors.buttonGradient]) : la couleur est portée par
/// l'icône, pas par la boîte. Un seul et même widget partagé garantit que
/// ce traitement reste identique partout, plutôt que redessiné légèrement
/// différemment dans chaque écran.
class BoxLogo extends StatelessWidget {
  final IconData icon;
  final double size;
  /// Couleur pleine à la place du dégradé vert par défaut — seul cas
  /// d'usage : les cartes "Convertir mes points" (vert/jaune uniquement,
  /// demande explicite), jamais une autre couleur ailleurs.
  final Color? color;
  const BoxLogo(this.icon, {super.key, this.size = 42, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        // Icône à 0.6 de la boîte (au lieu de 0.5) — "logos plus grands"
        // demandé explicitement, appliqué ici une seule fois pour que
        // TOUTE l'app en profite (BoxLogo est le seul logo partagé).
        child: color != null
            ? Icon(icon, size: size * 0.6, color: color)
            : ShaderMask(
                shaderCallback: (rect) => AppColors.buttonGradient.createShader(rect),
                child: Icon(icon, size: size * 0.6, color: Colors.white),
              ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// État vide générique (aucune demande, aucun historique, aucune
/// notification…) — jamais un écran silencieusement blanc.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  /// Couleur d'accent du badge — chaque écran choisit la sienne (voir ses
  /// appels) plutôt que de toujours retomber sur le même vert : un état vide
  /// répété partout à l'identique finit par rendre toute l'app uniforme.
  final Color color;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.color = AppColors.greenMid,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textGray, height: 1.4, fontWeight: FontWeight.w700)),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Petite pastille d'erreur/réseau réutilisable (état d'erreur générique).
class InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  const InlineErrorBanner(
      {super.key, required this.message, this.onRetry, this.retryLabel = "Retry"});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: Colors.redAccent, height: 1.4, fontWeight: FontWeight.w700)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(retryLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

Color statusColor(RequestStatus status) => switch (status) {
      RequestStatus.pending => const Color(0xFFB07E00),
      RequestStatus.accepted => const Color(0xFF2094C4),
      RequestStatus.inProgress => AppColors.greenBright,
      RequestStatus.completed => AppColors.greenDeep,
      RequestStatus.cancelled => Colors.redAccent,
    };

class RequestStatusBadge extends StatelessWidget {
  final RequestStatus status;
  final bool fr;
  const RequestStatusBadge({super.key, required this.status, required this.fr});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(status.label(fr),
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// Aperçu de position "carte" — tant qu'aucune vraie API de cartes n'est
/// branchée (voir la suite du projet), affiche un pin sur un fond quadrillé
/// stylisé plutôt qu'une fausse carte réaliste. Indique honnêtement quand la
/// position est approximative (adresse tapée, pas de GPS réel — voir
/// GeoHelper).
class MiniMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool approximate;
  final bool fr;
  const MiniMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.approximate,
    this.fr = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        color: AppColors.inputFill,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size.infinite, painter: _GridPainter()),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.topCenter,
              child: Icon(Icons.location_on, color: AppColors.greenDeep, size: 34),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
                  '${approximate ? "  •  ${fr ? "approximatif" : "approximate"}" : ""}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    const step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
