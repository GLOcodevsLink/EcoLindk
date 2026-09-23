import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/decorative_leaves.dart';
import '../widgets/gradient_pill_button.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';

/// Modification du profil, ouverte en tapant l'avatar sur SettingsScreen.
///
/// Modifiable : prénom, nom, et adresse (Ménage) ou zone de collecte /
/// entreprise (Collecteur). Email et téléphone sont affichés en lecture
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
  final _addressController = TextEditingController();
  final _collectionZoneController = TextEditingController();
  final _companyNameController = TextEditingController();

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
    _addressController.dispose();
    _collectionZoneController.dispose();
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
    _addressController.text = (data['address'] as String?) ?? '';
    _collectionZoneController.text = (data['collectionZone'] as String?) ?? '';
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
    if (_role == UserRole.household) {
      fields['address'] = _addressController.text.trim();
    } else {
      fields['collectionZone'] = _collectionZoneController.text.trim();
      final company = _companyNameController.text.trim();
      fields['companyName'] = company.isEmpty ? null : company;
    }

    try {
      await _authService.updateProfileFields(uid, fields);
      // Re-géocode le point de référence du collecteur si sa zone a changé —
      // best-effort, voir CollectorSetupScreen (même logique à la création).
      if (_role == UserRole.collector) {
        await _geocodeAndSaveLocation(uid);
      }
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

  Future<void> _geocodeAndSaveLocation(String uid) async {
    try {
      final result = await GeocodingService().geocode(_collectionZoneController.text);
      await CollectionService().setCollectorLocation(uid, result.latitude, result.longitude);
    } catch (_) {
      // Silencieux — voir CollectorSetupScreen._geocodeAndSaveLocation.
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
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          shape: BoxShape.circle),
                      child: Center(
                        child: Text(_initials(),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _field(_firstNameController, s.firstName, Icons.person_outline),
                  const SizedBox(height: 12),
                  _field(_lastNameController, s.lastName, Icons.person_outline),
                  const SizedBox(height: 12),
                  _readOnlyField(s.email, _email, Icons.email_outlined),
                  const SizedBox(height: 12),
                  _readOnlyField(s.phoneLabel, _phone, Icons.phone_outlined),
                  const SizedBox(height: 12),
                  if (_role == UserRole.household)
                    _field(_addressController, s.address, Icons.home_outlined)
                  else ...[
                    _field(_collectionZoneController, s.collectionZone,
                        Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    _field(_companyNameController, s.companyNameOptional,
                        Icons.apartment_outlined,
                        required: false),
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

  String _initials() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty && last.isEmpty) return '?';
    final a = first.isNotEmpty ? first.substring(0, 1) : '';
    final b = last.isNotEmpty ? last.substring(0, 1) : '';
    return (a + b).toUpperCase();
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {bool required = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
              ? AppStrings.of(appLanguage.value).requiredField
              : null
          : null,
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
