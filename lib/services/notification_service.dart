import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

/// Centre de notifications **in-app**, stocké dans
/// `notifications/{uid}/items/{id}` (voir firestore.rules : chacun ne lit
/// que les siennes). Chaque appel à [notify] correspond à un événement réel
/// qui vient de se produire côté données (règle métier #22) — jamais générée
/// "pour faire joli".
///
/// La livraison **push** (bandeau système même app fermée) nécessiterait une
/// Cloud Function déclenchée à la création d'un document ici, ce qui suppose
/// le plan payant Firebase (Blaze) — voir AuthService pour la même
/// contrainte sur le SMS. Ces documents alimentent déjà tout ce qui ne
/// dépend pas de ça : le centre de notifications et son badge non-lus.
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _items(String uid) => _firestore
      .collection('notifications')
      .doc(uid)
      .collection('items');

  Future<void> notify({
    required String uid,
    required NotificationType type,
    required String title,
    required String body,
    String? relatedRequestId,
  }) {
    return _items(uid).add({
      'type': type.name,
      'title': title,
      'body': body,
      'read': false,
      'relatedRequestId': relatedRequestId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotification>> watch(String uid) => _items(uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((q) => q.docs.map(AppNotification.fromDoc).toList());

  Stream<int> watchUnreadCount(String uid) => _items(uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((q) => q.docs.length);

  Future<void> markRead(String uid, String id) =>
      _items(uid).doc(id).update({'read': true});

  Future<void> markAllRead(String uid) async {
    final unread = await _items(uid).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
