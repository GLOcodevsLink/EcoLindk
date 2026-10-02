import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'waste_photo_image.dart';

/// Avatar d'un utilisateur : sa photo de profil si elle existe
/// (`users/{uid}.photoUrl`, voir ProfileScreen), sinon ses initiales sur un
/// cercle en dégradé, sinon une icône.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String fullName;
  final double size;

  const UserAvatar({super.key, required this.photoUrl, this.fullName = '', this.size = 40});

  static String initialsOf(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return ClipOval(
        child: WastePhotoImage(url: url, width: size, height: size, placeholderIcon: Icons.person_rounded),
      );
    }
    final initials = initialsOf(fullName);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: AppColors.buttonGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, color: Colors.white, size: size * 0.55)
          : Text(initials,
              style: TextStyle(color: Colors.white, fontSize: size * 0.34, fontWeight: FontWeight.w800)),
    );
  }
}
