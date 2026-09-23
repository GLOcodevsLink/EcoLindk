import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'home_screen.dart';

/// Dernière étape pour un Collecteur : zone de collecte + statut
/// (indépendant ou en entreprise). Finalise le compte (vérifié
/// immédiatement, voir AuthService.completeCollectorRegistration) puis
/// ouvre le dashboard. La zone de collecte est aussi géocodée (voir
/// GeocodingService) et enregistrée comme point de référence du collecteur
/// (voir CollectionService.setCollectorLocation) — sert au filtre "Près de
/// moi" et aux notifications de nouveaux posts proches ; jamais bloquant
/// pour la création du compte si le géocodage échoue.
class CollectorSetupScreen extends StatefulWidget {
  final String uid;
  final String firstName;
  const CollectorSetupScreen(
      {super.key, required this.uid, required this.firstName});

  @override
  State<CollectorSetupScreen> createState() => _CollectorSetupScreenState();
}

class _CollectorSetupScreenState extends State<CollectorSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _collectionZoneCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  WorkStatus _workStatus = WorkStatus.independent;
  bool _isLoading = false;

  final _authService = AuthService();
  final _collectionService = CollectionService();
  final _geocodingService = GeocodingService();

  @override
  void dispose() {
    _collectionZoneCtrl.dispose();
    _companyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish(AppStrings s) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.completeCollectorRegistration(
        widget.uid,
        collectionZone: _collectionZoneCtrl.text,
        workStatus: _workStatus,
        companyName: _companyNameCtrl.text,
      );
      await _geocodeAndSaveLocation();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.authError('unknown'))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Best-effort : un échec de géocodage (adresse introuvable, réseau) ne
  /// doit jamais empêcher la création du compte — le collecteur pourra
  /// toujours réessayer plus tard en modifiant sa zone depuis son profil.
  Future<void> _geocodeAndSaveLocation() async {
    try {
      final result = await _geocodingService.geocode(_collectionZoneCtrl.text);
      await _collectionService.setCollectorLocation(
          widget.uid, result.latitude, result.longitude);
    } catch (_) {
      // Silencieux — voir doc ci-dessus.
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
            return PopScope(
              canPop: false,
              child: Scaffold(
                body: Stack(
                  children: [
                    const DecorativeLeaves(subtle: true),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            children: [
                              const SizedBox(height: 12),
                              Text(s.collectorSetupTitle,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.mainText)),
                              const SizedBox(height: 4),
                              Text(s.collectorSetupSubtitle,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textGray)),
                              const SizedBox(height: 22),
                              _field(_collectionZoneCtrl, s.collectionZone,
                                  Icons.location_on_outlined, s),
                              const SizedBox(height: 18),
                              Text(s.workStatusQuestion,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mainText)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _choiceChip(
                                      s.workStatusIndependent,
                                      _workStatus == WorkStatus.independent,
                                      () => setState(() =>
                                          _workStatus = WorkStatus.independent),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _choiceChip(
                                      s.workStatusCompany,
                                      _workStatus == WorkStatus.company,
                                      () => setState(() =>
                                          _workStatus = WorkStatus.company),
                                    ),
                                  ),
                                ],
                              ),
                              if (_workStatus == WorkStatus.company) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _companyNameCtrl,
                                  decoration: InputDecoration(
                                    labelText: s.companyNameOptional,
                                    hintText: s.companyNameHint,
                                    prefixIcon: const Icon(
                                        Icons.apartment_outlined,
                                        size: 19),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              _infoBanner(s.collectorPendingNote),
                              const SizedBox(height: 22),
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.greenMid,
                                          strokeWidth: 2.4))
                                  : GradientPillButton(
                                      label: s.finish,
                                      onPressed: () => _finish(s)),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field(
      TextEditingController c, String label, IconData icon, AppStrings s) {
    return TextFormField(
      controller: c,
      decoration:
          InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
      validator: (v) => (v == null || v.isEmpty) ? s.requiredField : null,
    );
  }

  Widget _choiceChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.greenMid.withOpacity(0.12)
              : AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? AppColors.greenMid : AppColors.line, width: 1.4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.heading : AppColors.textGray,
          ),
        ),
      ),
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenBright.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greenMid.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 17, color: AppColors.greenMid),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11.5, color: AppColors.mainText, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
