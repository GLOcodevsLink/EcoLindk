import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme.dart';
import '../../services/collection_service.dart';
import '../../widgets/wp_common.dart';
import 'request_status_screen.dart';

/// Bouton "Scan" central de la barre de navigation (voir WasteProviderShell)
/// — lit un QR code EcoLindk (`ecolindk:collection:<id>`, voir
/// RequestStatusScreen) et ouvre directement le suivi de la collecte
/// correspondante. Signale clairement les codes non reconnus plutôt que de
/// ne rien faire.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController();
  final _collectionService = CollectionService();
  bool _handling = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String raw, bool fr) async {
    if (_handling) return;
    const prefix = 'ecolindk:collection:';
    if (!raw.startsWith(prefix)) {
      setState(() => _error = fr ? "QR code non reconnu." : "Unrecognized QR code.");
      return;
    }
    final requestId = raw.substring(prefix.length);
    setState(() {
      _handling = true;
      _error = null;
    });
    try {
      final request = await _collectionService.watchRequest(requestId).first;
      if (!mounted) return;
      if (request == null) {
        setState(() {
          _handling = false;
          _error = fr ? "Cette demande n'existe plus." : "This request no longer exists.";
        });
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RequestStatusScreen(requestId: request.id)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _handling = false;
        _error = fr ? "Lecture impossible. Réessayez." : "Couldn't read this code. Try again.";
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
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  final code = barcodes.isEmpty ? null : barcodes.first.rawValue;
                  if (code != null) _handleCode(code, fr);
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      ),
                      const Spacer(),
                      Text(fr ? "Scanner un QR code" : "Scan a QR code",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.greenBright, width: 2.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_handling)
                        const CircularProgressIndicator(color: AppColors.greenBright)
                      else
                        Text(
                          fr
                              ? "Cadrez le QR code de la collecte."
                              : "Frame the collection's QR code.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        InlineErrorBanner(message: _error!),
                      ],
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
}
