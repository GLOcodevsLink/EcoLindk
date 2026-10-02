import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/l10n/app_language.dart';
import '../core/theme.dart';
import '../services/contact_service.dart';

/// Opens the phone's native dialer pre-filled with [otherUid]'s number
/// (read from `userContacts/{otherUid}`, see ContactService). No in-app
/// calling: the user still presses "call" in the dialer.
class CallButton extends StatefulWidget {
  final String otherUid;

  /// Injected in tests; defaults to Firestore / url_launcher.
  final ContactService? contactService;
  final Future<bool> Function(Uri uri)? launcher;

  const CallButton({
    super.key,
    required this.otherUid,
    this.contactService,
    this.launcher,
  });

  @override
  State<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<CallButton> {
  bool _busy = false;

  Future<bool> _launch(Uri uri) async {
    if (widget.launcher != null) return widget.launcher!(uri);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }

  Future<void> _call() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bool fr = appLanguage.value == AppLanguage.fr;
    String? error;
    try {
      final ContactService service = widget.contactService ?? ContactService();
      final String? phone = await service.fetchPhone(widget.otherUid);
      if (phone == null) {
        error = fr
            ? "Aucun numéro de téléphone disponible pour ce contact."
            : "No phone number available for this contact.";
      } else {
        final bool opened = await _launch(Uri(scheme: 'tel', path: phone));
        if (!opened) {
          error = fr
              ? "Impossible d'ouvrir le composeur sur cet appareil."
              : "Couldn't open the dialer on this device.";
        }
      }
    } catch (e) {
      debugPrint('CallButton._call failed: $e');
      error = fr
          ? "Impossible de récupérer le numéro. Vérifiez votre connexion."
          : "Couldn't get the number. Check your connection.";
    }
    // State.mounted is this widget's context.mounted (still in the tree).
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fr = appLanguage.value == AppLanguage.fr;
    return IconButton(
      tooltip: fr ? "Appeler" : "Call",
      onPressed: _busy ? null : _call,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: AppColors.greenMid, strokeWidth: 2.2))
          : Icon(Icons.phone, color: AppColors.heading),
    );
  }
}
