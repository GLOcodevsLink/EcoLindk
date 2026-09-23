import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Bouton pilule avec dégradé vert, utilisé pour toutes les actions
/// principales (Commencer, Se connecter, S'inscrire...).
class GradientPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? trailingIcon;
  final bool outlined;
  /// Dégradé de remplacement — utilisé par Connexion/Inscription pour un
  /// vert moins pastel que le reste de l'app (demande explicite), laissé à
  /// `null` partout ailleurs pour garder [AppColors.buttonGradient].
  final Gradient? gradient;

  const GradientPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon = Icons.arrow_forward,
    this.outlined = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.heading,
            side: const BorderSide(color: AppColors.greenMid, width: 1.6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18),
              ],
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, color: Colors.white, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
