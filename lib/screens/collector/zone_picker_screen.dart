import 'dart:async';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_zone.dart';
import '../../services/place_search_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/wp_common.dart';

/// Choix d'UNE zone de collecte, en 3 étapes, avec des résultats
/// OpenStreetMap (voir PlaceSearchService) plutôt qu'un texte libre — pas
/// de fautes d'orthographe, et les coordonnées du quartier sont gardées :
/// 1. Pays — prérempli depuis l'indicatif du téléphone ([initialCountry]),
///    modifiable.
/// 2. Ville — recherche au fil de la frappe ("Yaou…" → Yaoundé).
/// 3. Quartier — recherché dans la ville choisie ("Bas…" → Bastos).
///
/// Se ferme avec la [CollectionZone] choisie, ou `null` si annulé.
class ZonePickerScreen extends StatefulWidget {
  final Country? initialCountry;

  /// Zone à modifier (préremplit le pays), `null` pour un ajout.
  final CollectionZone? editing;

  const ZonePickerScreen({super.key, this.initialCountry, this.editing});

  @override
  State<ZonePickerScreen> createState() => _ZonePickerScreenState();
}

class _ZonePickerScreenState extends State<ZonePickerScreen> {
  final _search = PlaceSearchService();
  final _cityCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();

  /// Pause dans la frappe avant d'interroger l'API (service gratuit : pas
  /// une requête par lettre).
  static const _debounce = Duration(milliseconds: 450);

  Country? _country;
  PlaceResult? _city;
  PlaceResult? _neighborhood;

  Timer? _timer;
  int _requestId = 0; // ignore les réponses d'une frappe dépassée
  bool _loading = false;
  String? _error;
  List<PlaceResult> _results = const [];
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    final editingCode = widget.editing?.countryCode ?? '';
    _country = (editingCode.isNotEmpty ? CountryService().findByCode(editingCode) : null) ??
        widget.initialCountry;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cityCtrl.dispose();
    _neighborhoodCtrl.dispose();
    super.dispose();
  }

  bool get _fr => appLanguage.value == AppLanguage.fr;

  void _onQueryChanged(String value) {
    _timer?.cancel();
    final q = value.trim();
    setState(() {
      _error = null;
      if (q.length < 2) {
        _results = const [];
        _loading = false;
      }
    });
    if (q.length < 2) return;
    _timer = Timer(_debounce, () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _lastQuery = q;
    });
    try {
      final results = _city == null
          ? await _search.searchCities(q, countryCode: _country?.countryCode)
          : await _search.searchNeighborhoods(q, city: _city!);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on PlaceSearchException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _results = const [];
        _error = switch (e.code) {
          'timeout' => _fr ? "La recherche a pris trop de temps." : "The search took too long.",
          'network' => _fr ? "Pas de connexion internet." : "No internet connection.",
          _ => _fr ? "Recherche indisponible pour le moment." : "Search unavailable right now.",
        };
      });
    }
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      favorite: const ['CM'],
      showPhoneCode: false,
      onSelect: (c) => setState(() {
        _country = c;
        _city = null;
        _neighborhood = null;
        _cityCtrl.clear();
        _neighborhoodCtrl.clear();
        _results = const [];
      }),
    );
  }

  void _selectCity(PlaceResult city) {
    FocusScope.of(context).unfocus();
    setState(() {
      _city = city;
      _neighborhood = null;
      _cityCtrl.text = city.name;
      _neighborhoodCtrl.clear();
      _results = const [];
      _error = null;
    });
  }

  void _selectNeighborhood(PlaceResult n) {
    FocusScope.of(context).unfocus();
    setState(() {
      _neighborhood = n;
      _neighborhoodCtrl.text = n.name;
      _results = const [];
      _error = null;
    });
  }

  void _resetCity() => setState(() {
        _city = null;
        _neighborhood = null;
        _cityCtrl.clear();
        _neighborhoodCtrl.clear();
        _results = const [];
      });

  void _resetNeighborhood() => setState(() {
        _neighborhood = null;
        _neighborhoodCtrl.clear();
        _results = const [];
      });

  void _confirm() {
    final city = _city, n = _neighborhood;
    if (city == null || n == null) return;
    Navigator.of(context).pop(CollectionZone(
      country: _country?.name ?? city.country,
      countryCode: _country?.countryCode ?? city.countryCode,
      city: city.name,
      neighborhood: n.name,
      latitude: n.latitude,
      longitude: n.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final fr = lang == AppLanguage.fr;
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              const DecorativeLeaves(subtle: true),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Text(
                              widget.editing == null
                                  ? (fr ? "Ajouter une zone" : "Add a zone")
                                  : (fr ? "Modifier la zone" : "Edit zone"),
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        children: [
                          _stepTitle(1, fr ? "Pays" : "Country", done: _country != null),
                          const SizedBox(height: 8),
                          _countryTile(fr),
                          const SizedBox(height: 20),
                          _stepTitle(2, fr ? "Ville" : "City", done: _city != null),
                          const SizedBox(height: 8),
                          _searchField(
                            controller: _cityCtrl,
                            hint: fr ? "Rechercher une ville (ex. Yaoundé)" : "Search a city (e.g. Yaoundé)",
                            icon: Icons.location_city_rounded,
                            locked: _city != null,
                            onReset: _resetCity,
                          ),
                          if (_city == null) _resultsList(fr, onTap: _selectCity),
                          if (_city != null) ...[
                            const SizedBox(height: 20),
                            _stepTitle(3, fr ? "Quartier" : "Neighborhood", done: _neighborhood != null),
                            const SizedBox(height: 8),
                            _searchField(
                              controller: _neighborhoodCtrl,
                              hint: fr ? "Rechercher un quartier (ex. Bastos)" : "Search a neighborhood (e.g. Bastos)",
                              icon: Icons.holiday_village_rounded,
                              locked: _neighborhood != null,
                              onReset: _resetNeighborhood,
                              autofocus: true,
                            ),
                            if (_neighborhood == null) _resultsList(fr, onTap: _selectNeighborhood),
                          ],
                          if (_neighborhood != null) ...[
                            const SizedBox(height: 22),
                            _summary(fr),
                          ],
                          const SizedBox(height: 16),
                          Text(
                              fr
                                  ? "Données © contributeurs OpenStreetMap"
                                  : "Data © OpenStreetMap contributors",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                        ],
                      ),
                    ),
                    if (_neighborhood != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: GradientPillButton(
                          label: fr ? "Enregistrer cette zone" : "Save this zone",
                          trailingIcon: Icons.check_rounded,
                          onPressed: _confirm,
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
  }

  Widget _stepTitle(int n, String title, {required bool done}) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            gradient: done ? AppColors.buttonGradient : null,
            color: done ? null : AppColors.line,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : Text("$n", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textGray)),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.mainText)),
      ],
    );
  }

  Widget _countryTile(bool fr) {
    final c = _country;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickCountry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Row(
            children: [
              Text(c?.flagEmoji ?? '🌍', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c?.name ?? (fr ? "Choisir un pays" : "Choose a country"),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                    if (c != null && widget.initialCountry?.countryCode == c.countryCode)
                      Text(fr ? "D'après l'indicatif de votre téléphone" : "From your phone's country code",
                          style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                  ],
                ),
              ),
              Text(fr ? "Modifier" : "Change",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.greenMid)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool locked,
    required VoidCallback onReset,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: locked,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: locked ? null : _onQueryChanged,
      onSubmitted: locked ? null : (v) {
        _timer?.cancel();
        if (v.trim().length >= 2) _runSearch(v.trim());
      },
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        suffixIcon: locked
            ? IconButton(
                tooltip: _fr ? "Changer" : "Change",
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: onReset,
              )
            : null,
      ),
    );
  }

  Widget _resultsList(bool fr, {required ValueChanged<PlaceResult> onTap}) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: InlineErrorBanner(
          message: _error!,
          retryLabel: fr ? "Réessayer" : "Retry",
          onRetry: () => _runSearch(_lastQuery),
        ),
      );
    }
    final activeCtrl = _city == null ? _cityCtrl : _neighborhoodCtrl;
    if (_results.isEmpty) {
      if (activeCtrl.text.trim().length < 2) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(fr ? "Tapez au moins 2 lettres." : "Type at least 2 letters.",
              style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
            _city == null
                ? (fr ? "Aucune ville trouvée${_country == null ? '' : ' dans ce pays'}." : "No city found.")
                : (fr ? "Aucun quartier trouvé dans ${_city!.name}." : "No neighborhood found in ${_city!.name}."),
            style: TextStyle(fontSize: 12, color: AppColors.textGray)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.2),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _results.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.line),
            ListTile(
              dense: true,
              leading: Icon(_city == null ? Icons.location_city_rounded : Icons.place_rounded,
                  color: AppColors.greenMid, size: 20),
              title: Text(_results[i].name,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
              subtitle: Text(
                  _city == null
                      ? _results[i].country
                      : "${_results[i].city}, ${_results[i].country}",
                  style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
              onTap: () => onTap(_results[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(bool fr) {
    final zone = "${_country?.name ?? _city!.country} → ${_city!.name} → ${_neighborhood!.name}";
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenMid.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.greenMid.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.greenDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(zone,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          ),
        ],
      ),
    );
  }
}
