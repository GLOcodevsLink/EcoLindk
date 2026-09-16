import 'package:cloud_firestore/cloud_firestore.dart';

/// Résumé d'une conversation (`conversations/{id}`, voir MessagingService),
/// vu du point de vue de l'utilisateur courant — [otherUid]/[otherName]
/// désignent toujours L'AUTRE participant, jamais soi-même, pour que
/// l'écran liste ("Messages") n'ait qu'à afficher ces champs directement.
class ConversationSummary {
  final String id;
  final String otherUid;
  final String otherName;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationSummary({
    required this.id,
    required this.otherUid,
    required this.otherName,
    required this.lastMessage,
    required this.lastSenderUid,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ConversationSummary.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String currentUid) {
    final d = doc.data() ?? {};
    final participants = (d['participants'] as List?)?.cast<String>() ?? const [];
    final otherUid = participants.firstWhere((p) => p != currentUid, orElse: () => '');
    final names = (d['participantNames'] as Map?)?.cast<String, dynamic>() ?? const {};
    final unread = (d['unread'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ConversationSummary(
      id: doc.id,
      otherUid: otherUid,
      otherName: names[otherUid] as String? ?? '',
      lastMessage: d['lastMessage'] as String? ?? '',
      lastSenderUid: d['lastSenderUid'] as String? ?? '',
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: (unread[currentUid] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un message (`conversations/{id}/messages/{messageId}`).
class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderUid: d['senderUid'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
