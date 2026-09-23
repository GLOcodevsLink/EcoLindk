import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import '../core/theme.dart';

/// Champ téléphone avec sélecteur de pays — le sélecteur (icône drapeau +
/// indicatif) ouvre désormais la liste COMPLÈTE des pays du monde (package
/// `country_picker`, avec recherche), plus seulement une poignée de pays
/// d'Afrique centrale codés en dur (demande explicite : proposer l'indicatif
/// de tous les pays, pas juste quelques-uns). Le Cameroun reste le pays par
/// défaut et remonte en tête de liste ("favori").
class PhoneField extends StatefulWidget {
  final TextEditingController controller;

  /// Appelé avec le numéro complet au format E.164 (ex: "+237650123456")
  /// à chaque changement d'indicatif ou de numéro national.
  final ValueChanged<String>? onChanged;

  /// Numéro complet (E.164) à pré-remplir, ex: numéro retenu d'une connexion
  /// précédente (voir SettingsService.loadLastPhone). Ignoré si son
  /// indicatif ne correspond à aucun pays connu.
  final String? initialValue;

  const PhoneField({
    super.key,
    required this.controller,
    this.onChanged,
    this.initialValue,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  static const _defaultCountryCode = 'CM'; // Cameroun

  late Country _selected;

  @override
  void initState() {
    super.initState();
    _selected = CountryService().findByCode(_defaultCountryCode) ??
        CountryService().getAll().first;

    final initial = widget.initialValue;
    if (initial != null && initial.startsWith('+')) {
      final digits = initial.substring(1);
      // Les indicatifs font 1 à 3 chiffres (E.164) — on cherche la
      // correspondance la plus longue pour éviter qu'un indicatif court
      // (ex. "1") ne masque un indicatif plus précis (ex. "237").
      for (var len = 3; len >= 1; len--) {
        if (digits.length < len) continue;
        final match = CountryService().findByPhoneCode(digits.substring(0, len));
        if (match != null) {
          _selected = match;
          widget.controller.text = digits.substring(len);
          break;
        }
      }
    }
  }

  void _notifyChanged() {
    widget.onChanged?.call('+${_selected.phoneCode}${widget.controller.text}');
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const [_defaultCountryCode],
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        textStyle: TextStyle(color: AppColors.mainText, fontSize: 15),
        searchTextStyle: TextStyle(color: AppColors.mainText),
        inputDecoration: InputDecoration(
          hintText: "Rechercher un pays",
          prefixIcon: const Icon(RemixIcons.search_line, size: 18),
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      onSelect: (country) {
        setState(() => _selected = country);
        widget.controller.clear();
        _notifyChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("NUMÉRO DE TÉLÉPHONE",
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mainText)),
        const SizedBox(height: 6),
        Row(
          children: [
            // Sélecteur d'indicatif pays — liste complète (voir doc de
            // la classe), pas limitée à quelques pays.
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openCountryPicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line, width: 1.4),
                ),
                child: Row(
                  children: [
                    Text(_selected.flagEmoji, style: TextStyle(fontSize: 17)),
                    const SizedBox(width: 6),
                    Text("+${_selected.phoneCode}",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(RemixIcons.arrow_down_s_fill, size: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Champ numéro national. Les indicatifs internationaux couvrent
            // des numéros nationaux de 4 à 14 chiffres selon le pays (norme
            // E.164) : on ne connaît plus une longueur exacte par pays (la
            // liste n'est plus figée à quelques pays), donc la validation
            // reste dans cette plage plutôt qu'une longueur unique imposée.
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                onChanged: (_) => _notifyChanged(),
                decoration: const InputDecoration(hintText: "6XX XXX XXX"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Numéro requis";
                  }
                  if (value.length < 4 || value.length > 14) {
                    return "Numéro de téléphone invalide";
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
