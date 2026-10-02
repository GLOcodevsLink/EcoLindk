import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/phone_country.dart';

/// Phone numbers shared between chat participants, kept in
/// `userContacts/{uid}` (a single `phone` field).
///
/// Firestore rules secure whole documents, not single fields: opening
/// `users/{uid}` to the other participant would also expose their email,
/// address, etc. This separate document holds only the phone number, and
/// firestore.rules lets someone read it only if they share a conversation
/// with its owner.
class ContactService {
  ContactService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _contact(String uid) =>
      _firestore.collection('userContacts').doc(uid);

  /// Publishes the current user's own [phone] (from `users/{uid}`), in
  /// E.164. Called on every app open (see HomeScreen), which also backfills
  /// accounts created before this feature. Does nothing for an unusable
  /// number.
  Future<void> publishOwnPhone(String uid, String? phone) async {
    final String? normalized = normalizePhoneE164(phone);
    if (normalized == null) return;
    await _contact(uid).set(<String, dynamic>{'phone': normalized});
  }

  /// The other participant's phone number in E.164, or `null` when they
  /// have none or the rules refuse the read (no shared conversation).
  Future<String?> fetchPhone(String otherUid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _contact(otherUid).get();
      return normalizePhoneE164(snap.data()?['phone'] as String?);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Removes the published number (account deletion).
  Future<void> deleteOwnPhone(String uid) => _contact(uid).delete();
}
