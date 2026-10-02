import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/waste_photo_service.dart';
import 'collector/collection_zones_screen.dart';
import '../widgets/decorative_leaves.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/user_avatar.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';

/// Modification du profil, ouverte en tapant l'avatar sur SettingsScreen.
///
/// Modifiable : photo de profil (enregistrée aussitôt choisie), prénom,
/// nom, entreprise ; les zones de collecte du Collecteur se gèrent sur leur
/// propre écran (voir CollectionZonesScreen), enregistré à chaque
/// changement. Plus d'adresse : chaque post a la sienne. Email et téléphone sont affichés en lecture
/// seule : les changer nécessiterait une re-vérification côté Firebase Auth
/// (email) ou une ré-indexation de `phone_lookup` (téléphone), hors scope
/// actuel.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late final Future<DocumentSnapshot<Map<String, dynamic>>?> _userDocFuture;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyNameController = TextEditingController();

  /// Photo de profil (référence `firestore://wastePhotos/<id>`), `null` si
  /// aucune.
  String? _photoUrl;
  bool _photoBusy = false;

  UserRole _role = UserRole.household;
  bool _loaded = false;
  bool _isSaving = false;
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    _userDocFuture =
        uid == null ? Future.value(null) : _authService.fetchUserDocument(uid);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  /// Ne remplit les champs qu'une seule fois (le FutureBuilder rebuild à
  /// chaque frame tant que le futur n'est pas résolu) pour ne pas écraser ce
  /// que l'utilisateur est en train de saisir.
  void _populate(Map<String, dynamic>? data) {
    if (_loaded || data == null) return;
    _loaded = true;
    _firstNameController.text = (data['firstName'] as String?) ?? '';
    _lastNameController.text = (data['lastName'] as String?) ?? '';
    _photoUrl = data['photoUrl'] as String?;
    _companyNameController.text = (data['companyName'] as String?) ?? '';
    _role = (data['role'] as String?) == UserRole.collector.name
        ? UserRole.collector
        : UserRole.household;
    _email = (data['email'] as String?) ?? (_authService.currentUser?.email ?? '');
    _phone = (data['phone'] as String?) ?? '';
  }

  Future<void> _save(AppStrings s) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fields = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'fullName': '$firstName $lastName'.trim(),
    };
    // Entreprise : réservée au Collecteur.
    if (_role == UserRole.collector) {
      final company = _companyNameController.text.trim();
      fields['companyName'] = company.isEmpty ? null : company;
    }

    try {
      await _authService.updateProfileFields(uid, fields);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.profileUpdated)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.authError('unknown'))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _fr => appLanguage.value == AppLanguage.fr;

  bool get _isDesktop => !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// Choix de la photo : caméra (sauf sur ordinateur), galerie, ou retrait.
  Future<void> _changePhoto() async {
    final fr = _fr;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (!_isDesktop)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.greenDeep),
                title: Text(fr ? "Prendre une photo" : "Take a photo"),
                onTap: () => Navigator.of(ctx).pop('camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.greenDeep),
              title: Text(fr ? "Choisir dans la galerie" : "Choose from gallery"),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            if (_photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(fr ? "Supprimer la photo" : "Remove photo",
                    style: const TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    if (choice == 'remove') {
      await _savePhoto(uid, null);
      return;
    }
    String? path;
    try {
      if (choice == 'camera') {
        path = (await ImagePicker()
                .pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 90))
            ?.path;
      } else {
        const images = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
        path = (await openFile(acceptedTypeGroups: [images]))?.path;
      }
    } catch (_) {
      path = null;
    }
    if (path == null || !mounted) return;

    setState(() => _photoBusy = true);
    try {
      final ref = await WastePhotoService().uploadAvatar(uid, await File(path).readAsBytes());
      await _savePhoto(uid, ref);
    } catch (e) {
      debugPrint('ProfileScreen._changePhoto failed: $e');
      if (mounted) {
        setState(() => _photoBusy = false);
        _snack(fr ? "Photo illisible ou envoi impossible. Réessayez." : "Unreadable photo or upload failed. Try again.");
      }
    }
  }

  Future<void> _savePhoto(String uid, String? ref) async {
    final fr = _fr;
    setState(() => _photoBusy = true);
    try {
      await _authService.updateProfilePhoto(uid, ref);
      if (!mounted) return;
      setState(() {
        _photoUrl = ref;
        _photoBusy = false;
      });
      _snack(ref == null
          ? (fr ? "Photo supprimée." : "Photo removed.")
          : (fr ? "Photo de profil mise à jour." : "Profile photo updated."));
    } catch (_) {
      if (!mounted) return;
      setState(() => _photoBusy = false);
      _snack(fr ? "Enregistrement impossible. Vérifiez votre connexion." : "Couldn't save. Check your connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: appLanguage,
          builder: (context, lang, _) {
            final s = AppStrings.of(lang);
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: _userDocFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Scaffold(
                    backgroundColor: AppColors.surface,
                    body: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.greenMid)),
                  );
                }
                _populate(snapshot.data?.data());
                return _buildForm(s);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildForm(AppStrings s) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const DecorativeLeaves(subtle: true),
          SafeArea(
            child: Form(
              key: _formKey,
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
                        child: Text(s.editProfileTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.heading)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(child: _photoPicker()),
                  const SizedBox(height: 26),
                  _field(_firstNameController, s.firstName, Icons.person_outline,
                      validator: (v) => Validators.personName(v, fr: _fr)),
                  const SizedBox(height: 12),
                  _field(_lastNameController, s.lastName, Icons.person_outline,
                      validator: (v) => Validators.personName(v, fr: _fr)),
                  const SizedBox(height: 12),
                  _readOnlyField(s.email, _email, Icons.email_outlined),
                  const SizedBox(height: 12),
                  _readOnlyField(s.phoneLabel, _phone, Icons.phone_outlined),
                  const SizedBox(height: 12),
                  if (_role == UserRole.collector) ...[
                    _zonesTile(),
                    const SizedBox(height: 12),
                    _field(_companyNameController, s.companyNameOptional,
                        Icons.apartment_outlined,
                        required: false, validator: (v) => Validators.companyName(v, fr: _fr)),
                  ],
                  const SizedBox(height: 24),
                  _isSaving
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.greenMid, strokeWidth: 2.4))
                      : GradientPillButton(
                          label: s.saveChanges, onPressed: () => _save(s)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Accès à "Mes zones de collecte" (Collecteur).
  Widget _zonesTile() {
    final fr = appLanguage.value == AppLanguage.fr;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CollectionZonesScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 19, color: AppColors.greenMid),
              const SizedBox(width: 12),
              Expanded(
                child: Text(fr ? "Mes zones de collecte" : "My collection zones",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.mainText)),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textGray),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar touchable : photo (ou initiales) avec un badge appareil photo.
  Widget _photoPicker() {
    final fr = _fr;
    return Column(
      children: [
        GestureDetector(
          onTap: _photoBusy ? null : _changePhoto,
          child: Stack(
            children: [
              UserAvatar(
                photoUrl: _photoUrl,
                fullName: '${_firstNameController.text} ${_lastNameController.text}',
                size: 96,
              ),
              if (_photoBusy)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                    child: Center(
                      child: SizedBox(
                          width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.greenDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 3),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _photoBusy ? null : _changePhoto,
          child: Text(_photoUrl == null
              ? (fr ? "Ajouter une photo" : "Add a photo")
              : (fr ? "Changer la photo" : "Change photo")),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {bool required = true, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? AppStrings.of(appLanguage.value).requiredField
                  : null
              : null),
    );
  }

  Widget _readOnlyField(String label, String value, IconData icon) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
    );
  }
}
