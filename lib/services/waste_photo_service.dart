import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Erreur d'envoi d'une photo — [code] vaut `invalid-image` (fichier
/// illisible), `too-large` (impossible de la faire tenir sous la limite) ou
/// `upload-failed` (écriture Firestore refusée ou réseau).
class WastePhotoException implements Exception {
  final String code;
  const WastePhotoException(this.code);

  @override
  String toString() => 'WastePhotoException($code)';
}

/// Photos des déchets postés, stockées **dans Firestore** (collection
/// `wastePhotos`), sans Firebase Storage ni hébergeur externe : Firebase
/// Storage exige désormais le plan payant Blaze, alors que Firestore reste
/// gratuit. Un document Firestore étant limité à 1 Mo, chaque photo est
/// d'abord réduite et recompressée en JPEG (voir [compressForFirestore]) —
/// environ 150 à 400 Ko, largement suffisant pour identifier un déchet.
///
/// La demande de collecte ne garde qu'une référence `firestore://wastePhotos/<id>`
/// dans `imageUrl` ; les anciennes URL http (photos StockImg) restent
/// affichées telles quelles (voir WastePhotoImage).
class WastePhotoService {
  WastePhotoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const refPrefix = 'firestore://wastePhotos/';

  /// Taille maximale d'une photo compressée (marge sous la limite de 1 Mo
  /// d'un document Firestore, pour les autres champs).
  static const maxBytes = 900 * 1024;

  /// Les photos déjà lues restent en mémoire : les listes ne relisent pas
  /// Firestore à chaque défilement.
  static final Map<String, Uint8List> _cache = {};

  CollectionReference<Map<String, dynamic>> get _photos => _firestore.collection('wastePhotos');

  static bool isFirestoreRef(String url) => url.startsWith(refPrefix);

  /// Compresse puis enregistre la photo de [uid] ; renvoie la référence à
  /// mettre dans `imageUrl`.
  Future<String> upload(String uid, File file) async {
    final Uint8List original;
    try {
      original = await file.readAsBytes();
    } catch (_) {
      throw const WastePhotoException('invalid-image');
    }
    return uploadBytes(uid, original);
  }

  Future<String> uploadBytes(String uid, Uint8List original) async =>
      uploadCompressed(uid, await compress(original));

  /// Compresse une photo pour Firestore (voir [compressForFirestore]), dans
  /// un isolat : l'écran reste fluide. Lève [WastePhotoException].
  static Future<Uint8List> compress(Uint8List original) => compute(compressForFirestore, original);

  /// Enregistre une photo DÉJÀ compressée par [compress] ; renvoie la
  /// référence à mettre dans `imageUrl`.
  Future<String> uploadCompressed(String uid, Uint8List jpeg) async {
    if (jpeg.length > maxBytes) throw const WastePhotoException('too-large');
    final doc = _photos.doc();
    try {
      await doc.set({
        'ownerUid': uid,
        'data': Blob(jpeg),
        'contentType': 'image/jpeg',
        'sizeBytes': jpeg.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('WastePhotoService.upload failed: $e');
      throw const WastePhotoException('upload-failed');
    }
    _cache[doc.id] = jpeg;
    return '$refPrefix${doc.id}';
  }

  /// Octets JPEG de la photo référencée par [ref], `null` si introuvable.
  Future<Uint8List?> load(String ref) async {
    final id = ref.substring(refPrefix.length);
    final cached = _cache[id];
    if (cached != null) return cached;
    final snap = await _photos.doc(id).get();
    final data = snap.data()?['data'];
    if (data is! Blob) return null;
    return _cache[id] = data.bytes;
  }
}

/// Réduit la photo (côté le plus long : 1280 px, puis moins si besoin) et
/// la réencode en JPEG, qualité décroissante, jusqu'à passer sous
/// [WastePhotoService.maxBytes]. Fonction de premier niveau pour pouvoir
/// tourner dans un isolat (`compute`).
Uint8List compressForFirestore(Uint8List input) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    // Fichier corrompu ou qui n'est pas une image : la bibliothèque lève
    // une erreur au lieu de renvoyer null.
    decoded = null;
  }
  if (decoded == null) throw const WastePhotoException('invalid-image');
  // Applique l'orientation EXIF (photos prises en portrait).
  final oriented = img.bakeOrientation(decoded);

  for (final side in const [1280, 1024, 800, 640]) {
    final longest = math.max(oriented.width, oriented.height);
    final resized = longest <= side
        ? oriented
        : img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? side : null,
            height: oriented.height > oriented.width ? side : null,
            interpolation: img.Interpolation.average,
          );
    for (final quality in const [80, 70, 60, 50, 40]) {
      final jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      if (jpeg.length <= WastePhotoService.maxBytes) return jpeg;
    }
  }
  throw const WastePhotoException('too-large');
}
