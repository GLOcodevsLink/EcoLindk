import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../models/collection_rating.dart';
import '../../models/collection_request.dart';
import '../../services/auth_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/decorative_leaves.dart';
import '../../widgets/gradient_pill_button.dart';

/// Note + commentaire laissés au Collecteur — uniquement disponible après
/// une collecte "completed" (voir règle métier #15/#22 : une seule note par
/// collecte, jamais avant que l'interaction soit terminée).
class RatingScreen extends StatefulWidget {
  final CollectionRequest request;
  const RatingScreen({super.key, required this.request});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final _authService = AuthService();
  final _ratingService = RatingService();
  final _commentCtrl = TextEditingController();
  int _stars = 0;
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(bool fr) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _stars == 0 || widget.request.collectorUid == null) return;
    setState(() => _submitting = true);
    try {
      await _ratingService.submit(CollectionRating(
        requestId: widget.request.id,
        householdUid: uid,
        collectorUid: widget.request.collectorUid!,
        stars: _stars,
        comment: _commentCtrl.text.trim(),
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(fr ? "Une erreur est survenue. Réessayez." : "Something went wrong. Please try again.")));
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
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.arrow_back, color: AppColors.heading),
                          ),
                          Text(fr ? "Évaluer le collecteur" : "Rate the collector",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.heading)),
                        ],
                      ),
                      Expanded(
                        child: _done ? _thanksView(fr) : _formView(fr),
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

  Widget _formView(bool fr) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: CircleAvatar(radius: 30, backgroundColor: AppColors.line, child: Icon(Icons.person, size: 28, color: AppColors.textGray)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(widget.request.collectorName ?? '—',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          ),
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return IconButton(
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber, size: 34),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          Text(fr ? "Commentaire (optionnel)" : "Comment (optional)",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.mainText)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: fr ? "Comment s'est passée la collecte ?" : "How did the collection go?",
            ),
          ),
          const SizedBox(height: 22),
          _submitting
              ? const Center(child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.4))
              : GradientPillButton(
                  label: fr ? "Envoyer" : "Submit",
                  onPressed: () {
                    if (_stars == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(fr ? "Choisissez une note." : "Choose a rating.")));
                      return;
                    }
                    _submit(fr);
                  },
                ),
        ],
      ),
    );
  }

  Widget _thanksView(bool fr) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, color: AppColors.greenMid, size: 46),
          const SizedBox(height: 14),
          Text(fr ? "Merci pour votre retour !" : "Thanks for your feedback!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.mainText)),
          const SizedBox(height: 20),
          GradientPillButton(label: fr ? "Terminé" : "Done", onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
