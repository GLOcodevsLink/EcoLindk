import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../core/phone_country.dart';
import '../core/theme.dart';
import '../models/collection_zone.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/collector_zone_service.dart';
import '../widgets/collection_zones_editor.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/decorative_leaves.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/strings.dart';
import 'home_screen.dart';

/// Dernière étape pour un Collecteur : zones de collecte (1 à 5, choisies
/// dans OpenStreetMap, pays prérempli depuis l'indicatif du téléphone) +
/// statut (indépendant ou en entreprise). Finalise le compte (voir
/// AuthService.completeCollectorRegistration), enregistre les zones (voir
/// CollectorZoneService — elles servent au ciblage des notifications de
/// nouveaux posts) puis ouvre le dashboard.
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
  final _companyNameCtrl = TextEditingController();
  List<CollectionZone> _zones = const [];
  Country? _phoneCountry;
  WorkStatus _workStatus = WorkStatus.independent;
  bool _isLoading = false;

  final _authService = AuthService();
  final _zoneService = CollectorZoneService();

  @override
  void initState() {
    super.initState();
    // Pays des zones prérempli depuis l'indicatif du numéro d'inscription.
    _authService.fetchUserDocument(widget.uid).then((doc) {
      if (mounted) setState(() => _phoneCountry = countryFromPhone(doc.data()?['phone'] as String?));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish(AppStrings s) async {
    if (!_formKey.currentState!.validate()) return;
    if (_zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(appLanguage.value == AppLanguage.fr
              ? "Ajoutez au moins une zone de collecte."
              : "Add at least one collection zone.")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.completeCollectorRegistration(
        widget.uid,
        workStatus: _workStatus,
        companyName: _companyNameCtrl.text,
      );
      await _zoneService.save(widget.uid, _zones);
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
                              CollectionZonesEditor(
                                zones: _zones,
                                phoneCountry: _phoneCountry,
                                fr: lang == AppLanguage.fr,
                                busy: _isLoading,
                                // Liste en mémoire : enregistrée à "Terminer".
                                onChanged: (zones) async {
                                  CollectorZoneService.validate(zones);
                                  setState(() => _zones = zones);
                                  return true;
                                },
                              ),
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
