import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:remixicon/remixicon.dart';
import '../../core/l10n/app_language.dart';
import '../../core/rewards_config.dart';
import '../../core/theme.dart';
import '../../models/collection_request.dart';
import '../../services/ai_classifier.dart';
import '../../services/auth_service.dart';
import '../../services/collection_service.dart';
import '../../services/waste_photo_service.dart';
import '../../services/geo_helper.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';
import '../../widgets/osm_map_preview.dart';
import '../../widgets/waste_category_picker.dart';
import '../../widgets/wp_common.dart';
import 'request_status_screen.dart';

/// Poster un déchet, en 3 étapes :
/// 0. **Votre déchet** — photo et description OBLIGATOIRES ; catégorie et
///    poids FACULTATIFS (l'utilisateur peut laisser l'IA décider).
/// 1. **Analyse IA** (voir AiClassifier) — le résultat s'affiche avec
///    "Accepter" (les valeurs de l'IA deviennent automatiquement celles du
///    post) ou "Refuser" (l'utilisateur corrige les valeurs proposées, et ce
///    sont ses corrections qui sont enregistrées). Si l'analyse échoue, il
///    peut réessayer ou continuer avec ses propres valeurs.
/// 2. **Adresse et envoi** — GPS réel ou adresse tapée (voir GeoHelper),
///    récapitulatif, envoi.
class PostWasteScreen extends StatefulWidget {
  const PostWasteScreen({super.key});

  @override
  State<PostWasteScreen> createState() => _PostWasteScreenState();
}

enum _AiDecision { none, accepted, refused, unavailable }

class _PostWasteScreenState extends State<PostWasteScreen> {
  int _step = 0;

  final _authService = AuthService();
  final _collectionService = CollectionService();
  final _geocodingService = GeocodingService();
  final _descriptionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Étape 0 — saisie initiale (catégorie/poids facultatifs).
  File? _imageFile;

  /// Version compressée de la photo (voir WastePhotoService.compress),
  /// préparée en arrière-plan DÈS le choix de la photo, puis réutilisée pour
  /// l'analyse IA et pour l'enregistrement : une seule compression, et
  /// quelques centaines de Ko à envoyer au lieu de plusieurs Mo.
  Future<Uint8List>? _compressed;
  int? _compressedSize; // `null` tant que la compression est en cours
  WasteCategory? _userCategory;
  final _userWeightCtrl = TextEditingController();
  bool _triedStep0 = false;

  // Étape 1 — IA puis valeurs retenues pour le post.
  bool _aiRunning = false;
  AiClassificationResult? _aiResult;
  String? _aiError;
  _AiDecision _decision = _AiDecision.none;
  WasteCategory? _finalCategory;
  final _finalWeightCtrl = TextEditingController();

  /// Résultat accepté mais sans poids (ni estimé par l'IA, ni saisi avant) :
  /// on le demande. Figé au moment d'accepter, pour que le champ ne
  /// disparaisse pas dès le premier chiffre tapé.
  bool _askWeight = false;

  // Étape 2 — adresse.
  bool _useGps = true;
  ResolvedLocation? _location;
  bool _locating = false;
  String? _locationError;
  bool _geocoding = false;

  bool _submitting = false;
  String? _submitError;

  /// Pas de caméra via `image_picker` sur Linux/Windows/macOS : bouton masqué
  /// plutôt que laissé inerte.
  bool get _isDesktop => !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    _userWeightCtrl.dispose();
    _finalWeightCtrl.dispose();
    super.dispose();
  }

  bool get _fr => appLanguage.value == AppLanguage.fr;

  static double? _parseKg(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  static String _fmtNumber(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  static String _fmtKg(double v) => '${_fmtNumber(v)} kg';

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // ---------------------------------------------------------------- photo
  void _setImage(File file) {
    final compressed = file.readAsBytes().then(WastePhotoService.compress);
    setState(() {
      _imageFile = file;
      _compressed = compressed;
      _compressedSize = null;
      // Nouvelle photo : l'ancienne analyse ne vaut plus rien.
      _aiResult = null;
      _aiError = null;
      _decision = _AiDecision.none;
    });
    compressed.then((jpeg) {
      if (mounted && _compressed == compressed) setState(() => _compressedSize = jpeg.length);
    }, onError: (Object e) {
      if (!mounted || _compressed != compressed) return;
      setState(() {
        _imageFile = null;
        _compressed = null;
      });
      _snack(e is WastePhotoException && e.code == 'too-large'
          ? (_fr ? "Photo trop lourde, même compressée. Choisissez-en une autre." : "Photo too heavy, even compressed. Pick another one.")
          : (_fr ? "Photo illisible. Choisissez une autre image (JPEG, PNG ou WEBP)." : "Unreadable photo. Pick another image (JPEG, PNG or WEBP)."));
    });
  }

  Future<void> _pickFromCamera() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
      if (picked != null) _setImage(File(picked.path));
    } catch (_) {
      _snack(_fr ? "Image invalide. Réessayez." : "Invalid image. Please try again.");
    }
  }

  /// Vrai sélecteur de fichiers du système sur toutes les plateformes
  /// (`image_picker` n'a pas de galerie sur desktop).
  Future<void> _pickFromFiles() async {
    try {
      const typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
      final picked = await openFile(acceptedTypeGroups: [typeGroup]);
      if (picked != null) _setImage(File(picked.path));
    } catch (_) {
      _snack(_fr ? "Image invalide. Réessayez." : "Invalid image. Please try again.");
    }
  }

  // ---------------------------------------------------------------- étapes
  bool get _userWeightInvalid => _userWeightCtrl.text.trim().isNotEmpty && _parseKg(_userWeightCtrl) == null;

  void _goToAnalysis() {
    setState(() => _triedStep0 = true);
    if (_imageFile == null || _descriptionCtrl.text.trim().isEmpty) {
      _snack(_fr
          ? "Ajoutez une photo et une description avant l'analyse."
          : "Add a photo and a description before the analysis.");
      return;
    }
    if (_userWeightInvalid) {
      _snack(_fr ? "Le poids doit être un nombre de kg." : "The weight must be a number of kg.");
      return;
    }
    setState(() => _step = 1);
    if (_aiResult == null && !_aiRunning) _runAi();
  }

  Future<void> _runAi() async {
    setState(() {
      _aiRunning = true;
      _aiError = null;
      _decision = _AiDecision.none;
    });
    try {
      final compressed = _compressed;
      if (compressed == null) throw const AiClassificationException('no-image');
      final Uint8List jpeg;
      try {
        jpeg = await compressed;
      } catch (_) {
        throw const AiClassificationException('invalid-image');
      }
      final result = await AiClassifier.classifyBytes(jpeg, 'image/jpeg');
      if (!mounted) return;
      setState(() {
        _aiResult = result;
        _aiRunning = false;
      });
    } on AiClassificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiRunning = false;
        _aiError = _aiErrorMessage(e.code, _fr);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiRunning = false;
        _aiError = _fr ? "Échec de l'analyse. Réessayez." : "Analysis failed. Please retry.";
      });
    }
  }

  String _aiErrorMessage(String code, bool fr) => switch (code) {
        'no-image' => fr ? "Aucune image à analyser." : "No image to analyze.",
        'invalid-image' => fr ? "Image invalide." : "Invalid image.",
        'unsupported' => fr
            ? "L'IA ne reconnaît pas de déchet recyclable sur cette photo."
            : "The AI doesn't recognize recyclable waste in this photo.",
        'network' => fr ? "Problème de connexion réseau." : "Network connection problem.",
        'not-configured' => fr
            ? "L'IA n'est pas encore activée dans le projet Firebase (Firebase AI Logic)."
            : "AI isn't enabled in the Firebase project yet (Firebase AI Logic).",
        _ => fr ? "Échec de l'analyse." : "Analysis failed.",
      };

  /// Accepter : les valeurs de l'IA deviennent celles du post. Si l'IA n'a
  /// pas estimé le poids, on garde celui saisi par l'utilisateur (sinon il
  /// devra l'indiquer).
  void _accept() {
    final ai = _aiResult!;
    setState(() {
      _decision = _AiDecision.accepted;
      _finalCategory = ai.category;
      final w = ai.estimatedWeightKg ?? _parseKg(_userWeightCtrl);
      _finalWeightCtrl.text = w == null ? '' : _fmtNumber(w);
      _askWeight = w == null;
    });
  }

  /// Refuser : formulaire de correction prérempli avec les valeurs de l'IA.
  void _refuse() {
    final ai = _aiResult!;
    setState(() {
      _decision = _AiDecision.refused;
      _finalCategory = ai.category;
      final w = ai.estimatedWeightKg ?? _parseKg(_userWeightCtrl);
      _finalWeightCtrl.text = w == null ? '' : _fmtNumber(w);
    });
  }

  /// Analyse impossible : l'utilisateur continue avec ses propres valeurs.
  void _continueWithoutAi() {
    setState(() {
      _decision = _AiDecision.unavailable;
      _finalCategory = _userCategory;
      final w = _parseKg(_userWeightCtrl);
      _finalWeightCtrl.text = w == null ? '' : _fmtNumber(w);
    });
  }

  void _goToAddress() {
    if (_decision == _AiDecision.none) {
      _snack(_fr ? "Acceptez ou refusez le résultat de l'IA." : "Accept or reject the AI result.");
      return;
    }
    if (_finalCategory == null || _parseKg(_finalWeightCtrl) == null) {
      _snack(_fr
          ? "Choisissez une catégorie et indiquez le poids, en kg."
          : "Choose a category and enter the weight, in kg.");
      return;
    }
    setState(() => _step = 2);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  // ---------------------------------------------------------------- adresse
  Future<void> _useDeviceGps() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final (location, result) = await GeoHelper.currentDeviceLocation();
    if (!mounted) return;
    final fr = _fr;
    if (location == null) {
      setState(() {
        _locating = false;
        _locationError = switch (result) {
          LocationPermissionResult.deniedOnce => fr ? "Permission de localisation refusée." : "Location permission denied.",
          LocationPermissionResult.deniedForever => fr
              ? "Localisation bloquée — activez-la dans les réglages du téléphone."
              : "Location blocked — enable it in your phone settings.",
          LocationPermissionResult.serviceDisabled =>
            fr ? "Le GPS est désactivé sur cet appareil." : "GPS is turned off on this device.",
          _ => fr ? "Impossible d'obtenir la position." : "Couldn't get your location.",
        };
      });
      return;
    }
    setState(() {
      _location = location;
      _locating = false;
      _addressCtrl.text = fr ? "Position actuelle (GPS)" : "Current location (GPS)";
    });
  }

  /// Géocode l'adresse tapée via Nominatim — une seule fois, au tap.
  Future<void> _useTypedAddress() async {
    final fr = _fr;
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
        _location = ResolvedLocation(latitude: result.latitude, longitude: result.longitude, isApproximate: true);
        _geocoding = false;
      });
    } on GeocodingException catch (e) {
      if (!mounted) return;
      setState(() {
        _geocoding = false;
        _locationError = switch (e.code) {
          'not-found' => fr ? "Adresse introuvable. Précisez-la et réessayez." : "Address not found. Refine it and try again.",
          'timeout' => fr ? "La recherche a pris trop de temps." : "The search took too long.",
          'network' => fr ? "Problème de connexion réseau." : "Network connection problem.",
          _ => fr ? "Géocodage impossible. Réessayez." : "Couldn't locate this address. Try again.",
        };
      });
    }
  }

  // ---------------------------------------------------------------- envoi
  Future<void> _submit() async {
    final fr = _fr;
    final uid = _authService.currentUser?.uid;
    final weight = _parseKg(_finalWeightCtrl);
    // Revérifié juste avant d'écrire quoi que ce soit.
    if (uid == null ||
        _imageFile == null ||
        _compressed == null ||
        _descriptionCtrl.text.trim().isEmpty ||
        _finalCategory == null ||
        weight == null ||
        _decision == _AiDecision.none) {
      _snack(fr ? "Des informations manquent. Revenez aux étapes précédentes." : "Some details are missing. Go back to the previous steps.");
      return;
    }
    if (_location == null || _addressCtrl.text.trim().isEmpty) {
      _snack(fr ? "Choisissez une adresse ou votre position GPS." : "Choose an address or your GPS position.");
      return;
    }

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

      final imageUrl = await _collectionService.uploadCompressedWastePhoto(uid, await _compressed!);

      final request = await _collectionService.createRequest(
        householdUid: uid,
        householdName: name,
        imageUrl: imageUrl,
        description: _descriptionCtrl.text.trim(),
        category: _finalCategory!,
        quantityRange: _fmtKg(weight),
        aiRequested: true,
        aiSuggestedCategory: _aiResult?.category,
        aiConfidence: _aiResult?.confidence,
        aiEstimatedWeightKg: _aiResult?.estimatedWeightKg,
        aiDecision: _decision.name,
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
      debugPrint('PostWasteScreen._submit failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = switch (e) {
          WastePhotoException(code: 'invalid-image') =>
            fr ? "Photo illisible. Choisissez une autre image (JPEG, PNG ou WEBP)." : "Unreadable photo. Pick another image (JPEG, PNG or WEBP).",
          WastePhotoException(code: 'too-large') =>
            fr ? "Photo trop lourde, même compressée. Choisissez-en une autre." : "Photo too heavy, even compressed. Pick another one.",
          _ => fr ? "Envoi impossible. Vérifiez votre connexion et réessayez." : "Couldn't submit. Check your connection and try again.",
        };
      });
    }
  }

  // ================================================================ UI
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _submitting ? null : _back,
                                icon: Icon(Icons.arrow_back, color: AppColors.heading),
                              ),
                              Expanded(
                                child: Text(fr ? "Poster un déchet" : "Post waste",
                                    style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.heading)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                          child: _StepHeader(step: _step, fr: fr),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                                child: child,
                              ),
                            ),
                            child: SingleChildScrollView(
                              key: ValueKey(_step),
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                              child: switch (_step) {
                                0 => _wasteStep(fr),
                                1 => _analysisStep(fr),
                                _ => _addressStep(fr),
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: _bottomBar(fr),
                        ),
                      ],
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

  Widget _bottomBar(bool fr) {
    if (_submitting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_submitError != null) ...[
          InlineErrorBanner(message: _submitError!, retryLabel: fr ? "Réessayer" : "Retry", onRetry: _submit),
          const SizedBox(height: 10),
        ],
        switch (_step) {
          0 => GradientPillButton(
              label: fr ? "Analyser avec l'IA" : "Analyze with AI",
              trailingIcon: RemixIcons.sparkling_2_fill,
              onPressed: _goToAnalysis,
            ),
          1 => (_decision == _AiDecision.none)
              ? const SizedBox.shrink()
              : GradientPillButton(label: fr ? "Continuer" : "Continue", onPressed: _goToAddress),
          _ => GradientPillButton(
              label: fr ? "Publier le déchet" : "Post the waste",
              trailingIcon: Icons.send_rounded,
              onPressed: _submit,
            ),
        },
      ],
    );
  }

  // ---------------------------------------------------------------- étape 0
  Widget _wasteStep(bool fr) {
    final missingPhoto = _triedStep0 && _imageFile == null;
    final missingDescription = _triedStep0 && _descriptionCtrl.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(fr ? "Photo du déchet" : "Photo of the waste", required: true, fr: fr),
        const SizedBox(height: 10),
        _photoPicker(fr, error: missingPhoto),
        const SizedBox(height: 22),
        _sectionTitle(fr ? "Description" : "Description", required: true, fr: fr),
        const SizedBox(height: 10),
        _card(
          child: TextField(
            controller: _descriptionCtrl,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_triedStep0) setState(() {});
            },
            decoration: InputDecoration(
              hintText: fr
                  ? "Ex. Une vingtaine de bouteilles plastique, propres et écrasées"
                  : "E.g. About twenty clean, crushed plastic bottles",
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              errorText: missingDescription ? (fr ? "La description est obligatoire." : "A description is required.") : null,
            ),
          ),
        ),
        const SizedBox(height: 22),
        _sectionTitle(fr ? "Catégorie" : "Category", required: false, fr: fr),
        const SizedBox(height: 4),
        Text(
            fr
                ? "Facultatif : si vous hésitez, l'IA la déterminera à partir de la photo."
                : "Optional: if you're not sure, the AI will work it out from the photo.",
            style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
        const SizedBox(height: 10),
        WasteCategoryPicker(
          selected: _userCategory,
          fr: fr,
          allowDeselect: true,
          onChanged: (c) => setState(() => _userCategory = c),
        ),
        const SizedBox(height: 22),
        _sectionTitle(fr ? "Poids estimé" : "Estimated weight", required: false, fr: fr),
        const SizedBox(height: 4),
        Text(
            fr ? "Facultatif : une estimation ou le poids exact." : "Optional: an estimate or the exact weight.",
            style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
        const SizedBox(height: 10),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WeightInput(controller: _userWeightCtrl, fr: fr, onChanged: () => setState(() {})),
              if (_userWeightInvalid) ...[
                const SizedBox(height: 6),
                Text(fr ? "Entrez un nombre de kg valide." : "Enter a valid number of kg.",
                    style: const TextStyle(fontSize: 11.5, color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoPicker(bool fr, {required bool error}) {
    final file = _imageFile;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: error ? Colors.redAccent : (file == null ? AppColors.greenMid.withValues(alpha: 0.45) : AppColors.line),
            width: file == null ? 1.6 : 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null
          ? Stack(
              children: [
                Image.file(file, height: 220, width: double.infinity, fit: BoxFit.cover),
                Positioned(top: 12, left: 12, child: _optimizedBadge(fr)),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      if (!_isDesktop) ...[
                        Expanded(child: _glassButton(Icons.photo_camera_rounded, fr ? "Reprendre" : "Retake", _pickFromCamera)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: _glassButton(Icons.photo_library_rounded, fr ? "Changer" : "Change", _pickFromFiles)),
                    ],
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.greenMid.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Icon(RemixIcons.camera_3_fill, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(fr ? "Ajoutez une photo nette du déchet" : "Add a clear photo of the waste",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                  const SizedBox(height: 4),
                  Text(
                      fr
                          ? "Bien cadrée et éclairée : l'IA et le collecteur s'en serviront."
                          : "Well framed and lit: the AI and the collector will rely on it.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!_isDesktop) ...[
                        Expanded(child: _softButton(Icons.photo_camera_rounded, fr ? "Caméra" : "Camera", _pickFromCamera)),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: _softButton(Icons.photo_library_rounded, fr ? "Galerie" : "Gallery", _pickFromFiles)),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  /// Pastille sur la photo : « Optimisation… » puis poids final.
  Widget _optimizedBadge(bool fr) {
    final size = _compressedSize;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (size == null)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white))
          else
            const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
              size == null
                  ? (fr ? "Optimisation…" : "Optimizing…")
                  : (fr ? "Photo optimisée · ${(size / 1024).round()} Ko" : "Optimized photo · ${(size / 1024).round()} KB"),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _softButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: AppColors.greenMid.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.greenDeep),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.greenDeep)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- étape 1
  Widget _analysisStep(bool fr) {
    if (_aiRunning) return _analyzing(fr);
    final ai = _aiResult;
    if (ai == null) return _aiFailed(fr);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _aiResultCard(ai, fr),
        const SizedBox(height: 16),
        if (_decision == _AiDecision.none)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _refuse,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                    label: Text(fr ? "Refuser" : "Reject",
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientPillButton(
                  label: fr ? "Accepter" : "Accept",
                  trailingIcon: Icons.check_rounded,
                  onPressed: _accept,
                ),
              ),
            ],
          )
        else
          _decisionPanel(fr),
      ],
    );
  }

  Widget _analyzing(bool fr) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const _PulsingAiOrb(),
          const SizedBox(height: 22),
          Text(fr ? "L'IA analyse votre photo…" : "The AI is analyzing your photo…",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          const SizedBox(height: 6),
          Text(fr ? "Catégorie et poids estimé, en quelques secondes." : "Category and estimated weight, in a few seconds.",
              style: TextStyle(fontSize: 12, color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _aiFailed(bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineErrorBanner(
          message: _aiError ?? (fr ? "Analyse impossible." : "Analysis unavailable."),
          retryLabel: fr ? "Réessayer" : "Retry",
          onRetry: _runAi,
        ),
        const SizedBox(height: 14),
        if (_decision == _AiDecision.none)
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _continueWithoutAi,
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(fr ? "Continuer avec mes valeurs" : "Continue with my values"),
            ),
          )
        else
          _editForm(fr),
      ],
    );
  }

  Widget _aiResultCard(AiClassificationResult ai, bool fr) {
    final c = ai.category;
    final confidence = (ai.confidence * 100).round();
    final w = ai.estimatedWeightKg;
    final userC = _userCategory;
    final userW = _parseKg(_userWeightCtrl);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.color.withValues(alpha: 0.35), width: 1.4),
        boxShadow: [BoxShadow(color: c.color.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(gradient: c.gradient),
            child: Row(
              children: [
                const Icon(RemixIcons.sparkling_2_fill, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(fr ? "Résultat de l'analyse IA" : "AI analysis result",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
                  child: Text(fr ? "Confiance $confidence %" : "Confidence $confidence%",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    WasteCategoryBadge(category: c, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label(fr),
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                          const SizedBox(height: 2),
                          Text(
                              w == null
                                  ? (fr ? "Poids non estimé" : "Weight not estimated")
                                  : (fr ? "Environ ${_fmtKg(w)}" : "About ${_fmtKg(w)}"),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.color)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ai.confidence,
                    minHeight: 6,
                    color: c.color,
                    backgroundColor: c.color.withValues(alpha: 0.12),
                  ),
                ),
                if (userC != null || userW != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textGray),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              fr ? "Vous aviez indiqué :" : "You entered:",
                              if (userC != null) userC.label(fr),
                              if (userW != null) _fmtKg(userW),
                            ].join(' '),
                            style: TextStyle(fontSize: 12, color: AppColors.textGray),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Après Accepter ou Refuser : rappel du choix + valeurs retenues.
  Widget _decisionPanel(bool fr) {
    final accepted = _decision == _AiDecision.accepted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(accepted ? Icons.check_circle_rounded : Icons.edit_rounded,
                size: 18, color: accepted ? AppColors.greenDeep : const Color(0xFFB07E00)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  accepted
                      ? (fr ? "Résultat de l'IA accepté : ce sont les données du post." : "AI result accepted: these are the post's details.")
                      : (fr ? "Corrigez les valeurs : ce sont elles qui seront enregistrées." : "Correct the values: these will be saved."),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.mainText)),
            ),
            TextButton(
              onPressed: () => setState(() => _decision = _AiDecision.none),
              child: Text(fr ? "Changer" : "Change"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (accepted && !_askWeight)
          _finalSummary(fr)
        else if (accepted) ...[
          Text(fr ? "L'IA n'a pas pu estimer le poids : indiquez-le." : "The AI couldn't estimate the weight: please enter it.",
              style: TextStyle(fontSize: 12, color: AppColors.textGray)),
          const SizedBox(height: 10),
          _card(child: WeightInput(controller: _finalWeightCtrl, fr: fr, onChanged: () => setState(() {}))),
        ] else
          _editForm(fr),
      ],
    );
  }

  Widget _finalSummary(bool fr) {
    final c = _finalCategory!;
    final w = _parseKg(_finalWeightCtrl)!;
    final points = RewardsConfig.pointsForCollection(c, w).round();
    return _card(
      child: Row(
        children: [
          WasteCategoryBadge(category: c, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${c.label(fr)} · ${_fmtKg(w)}",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                Text(fr ? "≈ $points points à la collecte" : "≈ $points points on pickup",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.greenDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formulaire de correction (refus de l'IA ou analyse indisponible).
  Widget _editForm(bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(fr ? "Catégorie" : "Category", required: true, fr: fr),
        const SizedBox(height: 10),
        WasteCategoryPicker(
          selected: _finalCategory,
          fr: fr,
          onChanged: (c) => setState(() => _finalCategory = c),
        ),
        const SizedBox(height: 18),
        _sectionTitle(fr ? "Poids" : "Weight", required: true, fr: fr),
        const SizedBox(height: 10),
        _card(child: WeightInput(controller: _finalWeightCtrl, fr: fr, onChanged: () => setState(() {}))),
      ],
    );
  }

  // ---------------------------------------------------------------- étape 2
  Widget _addressStep(bool fr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(fr ? "Adresse de collecte" : "Collection address", required: true, fr: fr),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _modeChip(Icons.my_location_rounded, fr ? "GPS de l'appareil" : "Device GPS", _useGps,
                  () => setState(() => _useGps = true)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _modeChip(Icons.edit_location_alt_rounded, fr ? "Adresse tapée" : "Typed address", !_useGps,
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
              : _softButton(Icons.my_location_rounded, fr ? "Utiliser ma position" : "Use my location", _useDeviceGps)
        else ...[
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              hintText: fr ? "Ex. Rue 123, Bonamoussadi, Douala" : "E.g. Street 123, Bonamoussadi, Douala",
              prefixIcon: const Icon(Icons.edit_location_alt_outlined, size: 19),
            ),
          ),
          const SizedBox(height: 10),
          _geocoding
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4)),
                )
              : _softButton(Icons.travel_explore_rounded, fr ? "Localiser cette adresse" : "Locate this address",
                  _useTypedAddress),
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
        const SizedBox(height: 24),
        _sectionTitle(fr ? "Récapitulatif" : "Summary", required: false, fr: fr, showOptional: false),
        const SizedBox(height: 10),
        _recap(fr),
      ],
    );
  }

  Widget _recap(bool fr) {
    final c = _finalCategory;
    final w = _parseKg(_finalWeightCtrl);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_imageFile!, width: 58, height: 58, fit: BoxFit.cover),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_descriptionCtrl.text.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppColors.mainText, height: 1.35)),
              ),
            ],
          ),
          const Divider(height: 22),
          _recapRow(fr ? "Catégorie" : "Category", c?.label(fr) ?? '—'),
          _recapRow(fr ? "Poids" : "Weight", w == null ? '—' : _fmtKg(w)),
          _recapRow(
              fr ? "Analyse IA" : "AI analysis",
              switch (_decision) {
                _AiDecision.accepted => fr ? "Acceptée" : "Accepted",
                _AiDecision.refused => fr ? "Refusée, valeurs corrigées" : "Rejected, values corrected",
                _AiDecision.unavailable => fr ? "Indisponible" : "Unavailable",
                _AiDecision.none => '—',
              }),
          if (c != null && w != null)
            _recapRow(fr ? "Points estimés" : "Estimated points",
                "≈ ${RewardsConfig.pointsForCollection(c, w).round()} P",
                highlight: true),
        ],
      ),
    );
  }

  Widget _recapRow(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: highlight ? AppColors.greenDeep : AppColors.mainText)),
          ],
        ),
      );

  Widget _modeChip(IconData icon, String label, bool active, VoidCallback onTap) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: active ? AppColors.buttonGradient : null,
        color: active ? null : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? Colors.transparent : AppColors.line, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: active ? Colors.white : AppColors.textGray),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : AppColors.textGray)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- commun
  Widget _sectionTitle(String title, {required bool required, required bool fr, bool showOptional = true}) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
        const SizedBox(width: 8),
        if (required)
          const Text("*", style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.redAccent))
        else if (showOptional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(999)),
            child: Text(fr ? "facultatif" : "optional",
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textGray)),
          ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// En-tête des 3 étapes : pastilles numérotées reliées, libellé sous chacune.
class _StepHeader extends StatelessWidget {
  final int step;
  final bool fr;
  const _StepHeader({required this.step, required this.fr});

  @override
  Widget build(BuildContext context) {
    final labels = fr ? ["Votre déchet", "Analyse IA", "Adresse"] : ["Your waste", "AI analysis", "Address"];
    final icons = [RemixIcons.camera_3_fill, RemixIcons.sparkling_2_fill, RemixIcons.map_pin_2_fill];
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = i ~/ 2 < step;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: done ? AppColors.greenMid : AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          );
        }
        final index = i ~/ 2;
        final active = index == step;
        final done = index < step;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: active || done ? AppColors.buttonGradient : null,
                color: active || done ? null : AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: active || done ? Colors.transparent : AppColors.line, width: 1.4),
              ),
              child: Icon(done ? Icons.check_rounded : icons[index],
                  size: 16, color: active || done ? Colors.white : AppColors.textGray),
            ),
            const SizedBox(height: 4),
            Text(labels[index],
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? AppColors.greenDeep : AppColors.textGray)),
          ],
        );
      }),
    );
  }
}

/// Orbe animée affichée pendant l'analyse IA.
class _PulsingAiOrb extends StatefulWidget {
  const _PulsingAiOrb();

  @override
  State<_PulsingAiOrb> createState() => _PulsingAiOrbState();
}

class _PulsingAiOrbState extends State<_PulsingAiOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final offset in [0.0, 0.5])
                Builder(builder: (_) {
                  final p = (t + offset) % 1.0;
                  return Container(
                    width: 70 + 60 * p,
                    height: 70 + 60 * p,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.greenMid.withValues(alpha: 0.22 * (1 - p)),
                    ),
                  );
                }),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.greenMid.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                ),
                child: Transform.rotate(
                  angle: t * 6.283,
                  child: const Icon(RemixIcons.sparkling_2_fill, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
