import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// Représente un pays sélectionnable pour l'indicatif téléphonique.
class CountryDialCode {
  final String name;
  final String flag;
  final String dialCode; // ex: "+237"
  final int nationalLength; // nombre de chiffres attendu après l'indicatif

  const CountryDialCode({
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.nationalLength,
  });
}

/// Liste de pays proposée au choix (Cameroun en premier / par défaut).
/// Ajoute d'autres pays ici si besoin (Tchad, Gabon, RCA, Congo, Nigeria...).
const List<CountryDialCode> kSupportedCountries = [
  CountryDialCode(name: "Cameroun", flag: "🇨🇲", dialCode: "+237", nationalLength: 9),
  CountryDialCode(name: "Tchad", flag: "🇹🇩", dialCode: "+235", nationalLength: 8),
  CountryDialCode(name: "Gabon", flag: "🇬🇦", dialCode: "+241", nationalLength: 8),
  CountryDialCode(name: "Congo", flag: "🇨🇬", dialCode: "+242", nationalLength: 9),
  CountryDialCode(name: "Nigeria", flag: "🇳🇬", dialCode: "+234", nationalLength: 10),
];

/// Champ téléphone avec sélecteur de pays (indicatif + validation de longueur).
/// Par défaut : Cameroun +237, numéro à 9 chiffres.
class PhoneField extends StatefulWidget {
  final TextEditingController controller;

  /// Appelé avec le numéro complet au format E.164 (ex: "+237650123456")
  /// à chaque changement d'indicatif ou de numéro national.
  final ValueChanged<String>? onChanged;

  const PhoneField({super.key, required this.controller, this.onChanged});

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  CountryDialCode _selected = kSupportedCountries.first; // Cameroun par défaut

  void _notifyChanged() {
    widget.onChanged?.call('${_selected.dialCode}${widget.controller.text}');
  }

  void _openCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text("Choisir un pays",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...kSupportedCountries.map((c) => ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 20)),
                    title: Text(c.name),
                    trailing: Text(c.dialCode,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() => _selected = c);
                      widget.controller.clear();
                      _notifyChanged();
                      Navigator.pop(ctx);
                    },
                  )),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("NUMÉRO DE TÉLÉPHONE",
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.greenDark)),
        const SizedBox(height: 6),
        Row(
          children: [
            // Sélecteur d'indicatif pays
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line, width: 1.4),
                ),
                child: Row(
                  children: [
                    Text(_selected.flag, style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 6),
                    Text(_selected.dialCode,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Champ numéro national (validé selon le pays choisi)
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_selected.nationalLength),
                ],
                onChanged: (_) => _notifyChanged(),
                decoration: InputDecoration(
                  hintText: "6XX XXX XXX".substring(
                      0, (_selected.nationalLength + 2).clamp(0, 11)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Numéro requis";
                  }
                  if (value.length != _selected.nationalLength) {
                    return "Le numéro ${_selected.name} doit contenir ${_selected.nationalLength} chiffres";
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
