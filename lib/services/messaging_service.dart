import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation.dart';

/// Messagerie directe entre un Fournisseur de déchets et un Collecteur, une
/// fois qu'une demande de collecte les a mis en relation (voir
/// CollectionRequest.householdUid/collectorUid). Stockée dans
/// `conversations/{conversationId}` (+ sous-collection `messages`) — voir
/// firestore.rules pour les permissions : seuls les deux participants
/// peuvent lire/écrire une conversation donnée.
///
/// [conversationIdFor] est déterministe (les deux uid triés, joints par
/// "_") : les deux côtés retrouvent le même document sans recherche
/// préalable, même paire d'utilisateurs = même conversation pour toujours
/// (même principe que WalletService.claimCollectionPoints qui utilise l'id
/// de la demande comme id de document déterministe).
class MessagingService {
  MessagingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  String conversationIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Toutes les conversations de [uid], la plus récente d'abord.
  Stream<List<ConversationSummary>> watchConversations(String uid) => _conversations
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map((d) => ConversationSummary.fromDoc(d, uid)).toList());

  /// Messages d'une conversation, du plus récent au plus ancien (l'écran de
  /// discussion les affiche dans un ListView inversé).
  Stream<List<ChatMessage>> watchMessages(String conversationId) => _conversations
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((q) => q.docs.map(ChatMessage.fromDoc).toList());

  /// Compte total de messages non lus de [uid], toutes conversations
  /// confondues — pour le badge de l'onglet Messages.
  Stream<int> watchTotalUnread(String uid) => _conversations
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((q) => q.docs.fold<int>(
          0,
          (total, d) =>
              total + (((d.data()['unread'] as Map?)?[uid] as num?)?.toInt() ?? 0)));

  /// Envoie [text] de [fromUid] à [toUid], crée la conversation si elle
  /// n'existe pas encore (`set(merge:true)`), et incrémente le compteur de
  /// non-lus du destinataire.
  ///
  /// `participants` est TOUJOURS écrit trié (mêmes deux id que
  /// [conversationIdFor], peu importe qui envoie) — sinon ce champ
  /// alternerait entre `[A, B]` et `[B, A]` selon l'expéditeur, et la règle
  /// Firestore qui interdit de le modifier après création (comparaison de
  /// liste, donc sensible à l'ordre) rejetterait alors le message de l'un
  /// des deux dès sa deuxième réponse.
  ///
  /// Un seul `set(merge:true)` sur la conversation (pas un `update()`
  /// séparé pour le compteur de non-lus) : sur une conversation qui vient
  /// tout juste d'être créée, un `update()` supplémentaire dans le même lot
  /// serait évalué par les règles Firestore comme si la conversation
  /// n'existait pas encore, et serait rejeté (voir firestore.rules).
  /// `participants` est aussi dupliqué sur le message lui-même, pour la même
  /// raison (voir la règle de `messages` dans firestore.rules).
  Future<String> sendMessage({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String toName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError('empty message');
    final participants = [fromUid, toUid]..sort();
    final id = '${participants[0]}_${participants[1]}';
    final convRef = _conversations.doc(id);
    final msgRef = convRef.collection('messages').doc();

    final batch = _firestore.batch();
    batch.set(
        convRef,
        {
          'participants': participants,
          'participantNames': {fromUid: fromName, toUid: toName},
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderUid': fromUid,
          'unread': {toUid: FieldValue.increment(1)},
        },
        SetOptions(merge: true));
    batch.set(msgRef, {
      'senderUid': fromUid,
      'participants': participants,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return id;
  }

  /// Remet à zéro les non-lus de [uid] pour cette conversation — à appeler à
  /// l'ouverture de l'écran de discussion. Ignore silencieusement le cas où
  /// la conversation n'existe pas encore (première visite, avant le tout
  /// premier message) : `update()` échouerait sur un document inexistant,
  /// mais il n'y a alors rien à marquer lu.
  Future<void> markRead(String conversationId, String uid) async {
    try {
      await _conversations.doc(conversationId).update({'unread.$uid': 0});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
  }
}
