import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/waste_photo_service.dart';

/// Affiche la photo d'un post, où qu'elle soit stockée : référence
/// Firestore (`firestore://wastePhotos/<id>`, voir WastePhotoService) ou
/// ancienne URL http (photos StockImg des posts antérieurs). Affiche une
/// icône neutre pendant le chargement, si la photo manque ou en cas
/// d'erreur — jamais un écran cassé.
class WastePhotoImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholderIcon;

  const WastePhotoImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
  });

  @override
  State<WastePhotoImage> createState() => _WastePhotoImageState();
}

class _WastePhotoImageState extends State<WastePhotoImage> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant WastePhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _prepare();
  }

  void _prepare() {
    _bytes = WastePhotoService.isFirestoreRef(widget.url)
        ? WastePhotoService().load(widget.url)
        : null;
  }

  Widget _placeholder() => Container(
        width: widget.width,
        height: widget.height,
        color: AppColors.inputFill,
        alignment: Alignment.center,
        child: Icon(widget.placeholderIcon, color: AppColors.textGray),
      );

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url.isEmpty) return _placeholder();
    if (_bytes == null) {
      return Image.network(url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return _placeholder();
        return Image.memory(bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _placeholder());
      },
    );
  }
}
