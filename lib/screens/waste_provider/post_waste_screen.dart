import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/ai_classifier.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/stockimg_client.dart';
import '../../services/geo_helper.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/osm_map_preview.dart';
import '../../widgets/wp_common.dart';
import 'request_status_screen.dart';

/// Flux de déclaration d'un déchet, en 4 étapes :
/// 0. Photo
/// 1. Description, catégorie, quantité
/// 2. Analyse IA (optionnelle, voir AiClassifier — un assistant, jamais une
///    vérité : l'utilisateur confirme ou corrige toujours la suggestion)
/// 3. Adresse (GPS réel ou adresse tapée — voir GeoHelper) puis récapitulatif
///    et envoi.
class PostWasteScreen extends StatefulWidget {
  const PostWasteScreen({super.key});

  @override
  State<PostWasteScreen> createState() => _PostWasteScreenState();
}

class _PostWasteScreenState extends State<PostWasteScreen> {
  static const _totalSteps = 4;
  int _step = 0;

  final _authService = AuthService();
  final _collectionService = CollectionService();
  final _geocodingService = GeocodingService();
  final _descriptionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();

  File? _imageFile;
  String? _imageError;

  WasteCategory? _category;

  /// Aucun clavier physique/tactile ni webcam de "vraie" caméra n'existe sur
  /// Linux/Windows via `image_picker` (pas d'implémentation fédérée pour ces
  /// plateformes) — le bouton "Caméra" y serait un bouton mort qui échoue en
  /// silence. Masqué sur desktop plutôt que simulé.
  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  bool _useAi = false;
  bool _aiRunning = false;
  AiClassificationResult? _aiResult;
  String? _aiError;

  bool _useGps = true;
  ResolvedLocation? _location;
  bool _locating = false;
  String? _locationError;
  bool _geocoding = false;

  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  bool _fr(BuildContext context) => appLanguage.value == AppLanguage.fr;

  /// Quantité tapée par l'utilisateur (kg) — `null` si vide ou non numérique
  /// (voir [_canGoNext]/[_submit], qui bloquent toujours avant Firestore si
  /// c'est le cas : demande explicite "le système vérifie toujours les
  /// entrées de l'utilisateur avant de poursuivre").
  double? get _parsedQuantityKg =>
      double.tryParse(_quantityCtrl.text.trim().replaceAll(',', '.'));

  String _formatQtyNumber(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  String _formatQtyKg(double v) => '${_formatQtyNumber(v)} kg';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
          source: source, imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
      if (picked == null) return; // annulé par l'utilisateur, pas une erreur
      setState(() {
        _imageFile = File(picked.path);
        _imageError = null;
        _aiResult = null;
      });
    } catch (_) {
      setState(() => _imageError =
          _fr(context) ? "Image invalide. Réessayez." : "Invalid image. Please try again.");
    }
  }

  /// Ouvre le vrai sélecteur de fichiers du système (demande explicite : "la
  /// galerie doit ouvrir l'espace fichier de la machine") — `image_picker`
  /// n'a pas d'implémentation Linux/Windows (bouton mort sur desktop) ;
  /// `file_selector` est le plugin officiel Flutter avec un vrai panneau
  /// natif sur TOUTES les plateformes (Explorateur de fichiers/Finder/
  /// sélecteur Android inclus), donc utilisé ici pour "Galerie" partout.
  Future<void> _pickImageFromFiles() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'images',
        // Formats acceptés par StockImg (pas de HEIC).
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      final picked = await openFile(acceptedTypeGroups: [typeGroup]);
      if (picked == null) return; // annulé par l'utilisateur, pas une erreur
      setState(() {
        _imageFile = File(picked.path);
        _imageError = null;
        _aiResult = null;
      });
    } catch (_) {
      setState(() => _imageError =
          _fr(context) ? "Image invalide. Réessayez." : "Invalid image. Please try again.");
    }
  }

  bool _canGoNext(bool fr) {
    switch (_step) {
      case 0:
        if (_imageFile == null) {
          setState(() => _imageError = fr ? "Ajoutez une photo pour continuer." : "Add a photo to continue.");
          return false;
        }
        return true;
      case 1:
        if (_category == null || _descriptionCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(fr ? "Complétez tous les champs." : "Fill in all the fields.")));
          return false;
        }
        final qty = _parsedQuantityKg;
        if (qty == null || qty <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(fr
                  ? "Entrez une quantité valide, en kilogrammes."
                  : "Enter a valid quantity, in kilograms.")));
          return false;
        }
        return true;
      case 2:
        return true; // l'IA est optionnelle
      default:
        return true;
    }
  }

  Future<void> _runAi() async {
    setState(() {
      _aiRunning = true;
      _aiError = null;
    });
    try {
      final result = await AiClassifier.classify(_imageFile?.path);
      if (!mounted) return;
      setState(() {
        _aiResult = result;
        _aiRunning = false;
      });
    } on AiClassificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiRunning = false;
        _aiError = _aiErrorMessage(e.code, _fr(context));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiRunning = false;
        _aiError = _fr(context) ? "Échec de l'analyse. Réessayez." : "Analysis failed. Please retry.";
      });
    }
  }

  String _aiErrorMessage(String code, bool fr) {
    switch (code) {
      case 'no-image':
        return fr ? "Aucune image à analyser." : "No image to analyze.";
      case 'invalid-image':
        return fr ? "Image invalide." : "Invalid image.";
      case 'unsupported':
        return fr ? "Ce type de déchet n'est pas reconnu." : "This waste type isn't recognized.";
      case 'network':
        return fr ? "Problème de connexion réseau." : "Network connection problem.";
      default:
        return fr ? "Échec de la classification." : "Classification failed.";
    }
  }

  Future<void> _useDeviceGps() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final (location, result) = await GeoHelper.currentDeviceLocation();
    if (!mounted) return;
    if (location == null) {
      setState(() {
        _locating = false;
        _locationError = switch (result) {
          LocationPermissionResult.deniedOnce =>
            _fr(context) ? "Permission de localisation refusée." : "Location permission denied.",
          LocationPermissionResult.deniedForever => _fr(context)
              ? "Localisation bloquée — activez-la dans les réglages du téléphone."
              : "Location blocked — enable it in your phone settings.",
          LocationPermissionResult.serviceDisabled =>
            _fr(context) ? "Le GPS est désactivé sur cet appareil." : "GPS is turned off on this device.",
          _ => _fr(context) ? "Impossible d'obtenir la position." : "Couldn't get your location.",
        };
      });
      return;
    }
    setState(() {
      _location = location;
      _locating = false;
      _addressCtrl.text = _fr(context)
          ? "Position actuelle (GPS)"
          : "Current location (GPS)";
    });
  }

  /// Géocode l'adresse tapée via Nominatim (voir GeocodingService) — UNE
  /// SEULE fois, au tap sur "Localiser cette adresse", jamais à chaque
  /// frappe. Le résultat reste marqué [ResolvedLocation.isApproximate] :
  /// une adresse géocodée est moins précise qu'un point GPS direct.
  Future<void> _useTypedAddress() async {
    final fr = _fr(context);
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) return;
    setState(() {
      _geocoding = true;
      _locationError = null;
    });
    try {
      final result = await _geocodingService.geocode(address);
      if (!mounted) return;
      setState(() {
        _location = ResolvedLocation(
            latitude: result.latitude, longitude: result.longitude, isApproximate: true);
        _geocoding = false;
      });
    } on GeocodingException catch (e) {
      if (!mounted) return;
      setState(() {
        _geocoding = false;
        _locationError = switch (e.code) {
          'not-found' => fr
              ? "Adresse introuvable. Précisez-la et réessayez."
              : "Address not found. Refine it and try again.",
          'timeout' => fr ? "La recherche a pris trop de temps." : "The search took too long.",
          'network' => fr ? "Problème de connexion réseau." : "Network connection problem.",
          _ => fr ? "Géocodage impossible. Réessayez." : "Couldn't locate this address. Try again.",
        };
      });
    }
  }

  Future<void> _submit() async {
    final fr = _fr(context);
    final uid = _authService.currentUser?.uid;
    final qty = _parsedQuantityKg;
    // Revérifié ici (en plus de [_canGoNext] à chaque étape) juste avant
    // d'écrire quoi que ce soit sur Firestore — jamais confiance uniquement
    // dans un contrôle déjà passé plus tôt dans le flux.
    if (uid == null || _category == null || qty == null || qty <= 0 || _location == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final doc = await _authService.fetchUserDocument(uid);
      final data = doc.data();
      final name = ((data?['firstName'] as String?) ?? '').trim().isEmpty
          ? (data?['fullName'] as String? ?? '')
          : '${data?['firstName']} ${data?['lastName'] ?? ''}'.trim();

      final imageUrl = await _collectionService.uploadWastePhoto(uid, _imageFile!);

      final request = await _collectionService.createRequest(
        householdUid: uid,
        householdName: name,
        imageUrl: imageUrl,
        description: _descriptionCtrl.text.trim(),
        category: _category!,
        quantityRange: _formatQtyKg(qty),
        aiRequested: _useAi,
        aiSuggestedCategory: _aiResult?.category,
        aiConfidence: _aiResult?.confidence,
        address: _addressCtrl.text.trim(),
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        locationIsApproximate: _location!.isApproximate,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RequestStatusScreen(requestId: request.id)),
      );
    } catch (e, st) {
      // Ecrit la VRAIE cause dans les logs (console `flutter run`) — le
      // message affiché à l'utilisateur reste volontairement générique,
      // mais un échec silencieux sans aucune trace serait indiscernable
      // d'une simulation qui ne fait rien.
      debugPrint('PostWasteScreen._submit failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = switch (e) {
          StockImgException(code: 'rejected') => fr
              ? "Photo refusée (5 Mo max, JPEG/PNG/WEBP) ou espace de stockage plein."
              : "Photo rejected (5 MB max, JPEG/PNG/WEBP) or storage full.",
          StockImgException(code: 'rate-limited') => fr
              ? "Trop d'envois en peu de temps. Réessayez dans une minute."
              : "Too many uploads. Try again in a minute.",
          StockImgException(code: 'not-configured' || 'unauthorized') => fr
              ? "Hébergement des photos non configuré (clé StockImg)."
              : "Photo hosting not configured (StockImg key).",
          _ => fr
              ? "Envoi impossible. Vérifiez votre connexion et réessayez."
              : "Couldn't submit. Check your connection and try again.",
        };
      });
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
        final fr = lang == AppLanguage.fr;
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              const DecorativeLeaves(subtle: true),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _submitting
                                ? null
                                : () => _step == 0
                                    ? Navigator.of(context).pop()
                                    : setState(() => _step -= 1),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Expanded(
                            child: Text(fr ? "Poster un déchet" : "Post waste",
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(_totalSteps, (i) {
                          final active = i <= _step;
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: i == _totalSteps - 1 ? 0 : 6),
                              height: 4,
                              decoration: BoxDecoration(
                                color: active ? AppColors.greenMid : AppColors.line,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: SingleChildScrollView(
                          child: switch (_step) {
                            0 => _photoStep(fr),
                            1 => _detailsStep(fr),
                            2 => _aiStep(fr),
                            _ => _addressStep(fr),
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_submitError != null) ...[
                        InlineErrorBanner(message: _submitError!, retryLabel: fr ? "Réessayer" : "Retry", onRetry: _submit),
                        const SizedBox(height: 10),
                      ],
                      _submitting
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
                          : GradientPillButton(
                              label: _step == _totalSteps - 1
                                  ? (fr ? "Envoyer la demande" : "Submit request")
                                  : (fr ? "Suivant" : "Next"),
                              onPressed: () {
                                if (_step == _totalSteps - 1) {
                                  if (_location == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(fr
                                            ? "Choisissez une adresse ou votre position GPS."
                                            : "Choose an address or your GPS position.")));
                                    return;
                                  }
                                  _submit();
                                } else if (_canGoNext(fr)) {
                                  setState(() => _step += 1);
                                }
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
      },
    );
  }

  // ---- Étape 0 : Photo ----
  Widget _photoStep(bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fr ? "Photo du déchet" : "Photo of the waste",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.mainText)),
        const SizedBox(height: 4),
        Text(
            fr
                ? "Une photo claire aide le collecteur à identifier le déchet."
                : "A clear photo helps the collector identify the waste.",
            style: TextStyle(fontSize: 12, color: AppColors.textGray)),
        const SizedBox(height: 16),
        if (_imageFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(_imageFile!, height: 220, width: double.infinity, fit: BoxFit.cover),
          )
        else
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line, width: 1.4),
            ),
            child: Center(
              child: Icon(Icons.image_outlined, size: 44, color: AppColors.textGray),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Pas de webcam via image_picker sur desktop (Linux/Windows/
            // macOS n'ont pas d'implémentation caméra dans le plugin) — un
            // bouton "Caméra" y échouerait en silence, donc masqué plutôt
            // que laissé simulé (demande explicite : plus de simulations).
            if (!_isDesktop) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(fr ? "Caméra" : "Camera"),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImageFromFiles,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(fr ? "Galerie" : "Gallery"),
              ),
            ),
          ],
        ),
        if (_imageError != null) ...[
          const SizedBox(height: 12),
          InlineErrorBanner(message: _imageError!),
        ],
      ],
    );
  }

  // ---- Étape 1 : Description, catégorie, quantité ----
  Widget _detailsStep(bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          icon: Icons.notes_rounded,
          title: fr ? "Description" : "Description",
          child: TextField(
            controller: _descriptionCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: fr
                  ? "Ex. Bouteilles plastique et cartons d'emballage"
                  : "E.g. Plastic bottles and packaging boxes",
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          icon: Icons.category_outlined,
          title: fr ? "Catégorie" : "Category",
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WasteCategory.values.map((c) {
              final active = _category == c;
              return ChoiceChip(
                avatar: Icon(c.icon, size: 16, color: active ? Colors.white : c.color),
                label: Text(c.label(fr)),
                selected: active,
                labelStyle: TextStyle(color: active ? Colors.white : c.color, fontWeight: FontWeight.w700),
                selectedColor: c.color,
                backgroundColor: c.color.withOpacity(0.08),
                side: BorderSide(color: c.color.withOpacity(active ? 0 : 0.35)),
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          icon: Icons.scale_outlined,
          title: fr ? "Quantité" : "Quantity",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saisie libre (demande explicite : "ça ne doit pas proposer
              // à l'utilisateur, ça doit offrir un espace et laisser
              // l'utilisateur entrer une approximation ou une quantité
              // exacte") — plus de paliers fixes à choisir, un nombre de kg
              // tapé directement, qu'il soit approximatif ou précis au gramme.
              Text(
                fr
                    ? "Entrez une estimation ou le poids exact, en kilogrammes."
                    : "Enter an estimate or the exact weight, in kilograms.",
                style: TextStyle(fontSize: 11, color: AppColors.textGray),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _quantityCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  hintText: fr ? "Ex. 3.5" : "E.g. 3.5",
                  prefixIcon: const Icon(Icons.scale_outlined, size: 19),
                  suffixText: 'kg',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Carte partagée pour chaque section du formulaire (demande explicite :
  /// "rends le plus beau") — icône + titre + contenu, même traitement
  /// visuel que les cartes du reste de l'app plutôt que du texte brut posé
  /// sur le fond.
  Widget _sectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.greenDeep),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.mainText)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ---- Étape 2 : Analyse IA ----
  Widget _aiStep(bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: Color(0xFFEAF6FB), shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF2094C4), size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fr ? "Analyse IA" : "AI analysis",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.mainText)),
                    Text(
                        fr
                            ? "Optionnelle — une suggestion à confirmer, jamais une décision finale."
                            : "Optional — a suggestion to confirm, never a final decision.",
                        style: TextStyle(fontSize: 10.5, color: AppColors.textGray)),
                  ],
                ),
              ),
              Switch(
                value: _useAi,
                activeColor: AppColors.greenMid,
                onChanged: (v) => setState(() {
                  _useAi = v;
                  if (!v) {
                    _aiResult = null;
                    _aiError = null;
                  }
                }),
              ),
            ],
          ),
        ),
        if (_useAi) ...[
          const SizedBox(height: 16),
          if (_aiRunning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4)),
            )
          else if (_aiResult != null)
            _aiResultCard(fr)
          else if (_aiError != null)
            InlineErrorBanner(message: _aiError!, retryLabel: fr ? "Réessayer" : "Retry", onRetry: _runAi)
          else
            OutlinedButton.icon(
              onPressed: _runAi,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(fr ? "Lancer l'analyse" : "Run analysis"),
            ),
        ],
      ],
    );
  }

  Widget _aiResultCard(bool fr) {
    final result = _aiResult!;
    final matches = _category == result.category;
    final aiWeight = result.estimatedWeightKg;
    final currentQty = _parsedQuantityKg;
    final quantityMatches = aiWeight == null ||
        (currentQty != null && (currentQty - aiWeight).abs() < 0.05);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenBright.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greenBright.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(result.category.icon, color: AppColors.greenDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fr
                      ? "Suggestion : ${result.category.label(fr)}"
                      : "Suggestion: ${result.category.label(fr)}",
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.mainText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fr
                ? "Confiance : ${(result.confidence * 100).toStringAsFixed(0)} %"
                : "Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%",
            style: TextStyle(fontSize: 11.5, color: AppColors.textGray),
          ),
          if (aiWeight != null) ...[
            const SizedBox(height: 4),
            Text(
              fr
                  ? "Poids estimé : ${_formatQtyKg(aiWeight)}"
                  : "Estimated weight: ${_formatQtyKg(aiWeight)}",
              style: TextStyle(fontSize: 11.5, color: AppColors.textGray),
            ),
          ],
          const SizedBox(height: 12),
          if (!quantityMatches)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _quantityCtrl.text = _formatQtyNumber(aiWeight!)),
                  child: Text(fr
                      ? "Utiliser ce poids (${_formatQtyKg(aiWeight)})"
                      : "Use this weight (${_formatQtyKg(aiWeight)})"),
                ),
              ),
            ),
          if (!matches)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(fr
                            ? "Catégorie conservée : ${_category?.label(fr)}"
                            : "Category kept: ${_category?.label(fr)}"))),
                    child: Text(fr ? "Garder ${_category?.label(fr)}" : "Keep ${_category?.label(fr)}"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.greenMid, foregroundColor: Colors.white),
                    onPressed: () => setState(() => _category = result.category),
                    child: Text(fr ? "Utiliser cette catégorie" : "Use this category"),
                  ),
                ),
              ],
            )
          else
            Text(fr ? "Correspond à votre choix ✓" : "Matches your choice ✓",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.greenDeep)),
        ],
      ),
    );
  }

  // ---- Étape 3 : Adresse + récapitulatif ----
  Widget _addressStep(bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fr ? "Adresse de collecte" : "Collection address",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.mainText)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _addressModeChip(fr ? "GPS de l'appareil" : "Device GPS", _useGps,
                  () => setState(() => _useGps = true)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _addressModeChip(fr ? "Adresse tapée" : "Typed address", !_useGps,
                  () => setState(() => _useGps = false)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_useGps)
          _locating
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4)),
                )
              : OutlinedButton.icon(
                  onPressed: _useDeviceGps,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(fr ? "Utiliser ma position" : "Use my location"),
                )
        else ...[
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              hintText: fr ? "Ex. Rue 123, quartier Bonamoussadi, Douala" : "E.g. Street 123, Bonamoussadi, Douala",
              prefixIcon: const Icon(Icons.edit_location_alt_outlined, size: 19),
            ),
          ),
          const SizedBox(height: 10),
          _geocoding
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4)),
                )
              : OutlinedButton(
                  onPressed: _useTypedAddress,
                  child: Text(fr ? "Localiser cette adresse" : "Locate this address")),
        ],
        if (_locationError != null) ...[
          const SizedBox(height: 12),
          InlineErrorBanner(message: _locationError!),
        ],
        if (_location != null) ...[
          const SizedBox(height: 14),
          MiniMapPreview(
              latitude: _location!.latitude,
              longitude: _location!.longitude,
              approximate: _location!.isApproximate,
              fr: fr),
        ],
        const SizedBox(height: 22),
        Text(fr ? "Récapitulatif" : "Summary",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.mainText)),
        const SizedBox(height: 8),
        _summaryRow(fr ? "Catégorie" : "Category", _category?.label(fr) ?? '—'),
        _summaryRow(fr ? "Quantité" : "Quantity",
            _parsedQuantityKg == null ? '—' : _formatQtyKg(_parsedQuantityKg!)),
        _summaryRow(fr ? "Analyse IA" : "AI analysis", _useAi ? (fr ? "Activée" : "Enabled") : (fr ? "Désactivée" : "Disabled")),
      ],
    );
  }

  Widget _addressModeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppColors.greenMid.withOpacity(0.12) : AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.greenMid : AppColors.line, width: 1.4),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.heading : AppColors.textGray)),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textGray)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.mainText)),
        ],
      ),
    );
  }
}
