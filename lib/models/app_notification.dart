import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Chaque valeur correspond à un événement réel du système (voir règle
/// métier : "Notifications must correspond to actual system events") —
/// jamais générée sans un fait qui vient de se produire côté données.
enum NotificationType {
  requestSubmitted,
  requestAccepted,
  statusChanged,
  requestCompleted,
  pointsCredited,
  referralCompleted,
  accountStatus,
  announcement,
}

extension NotificationTypeX on NotificationType {
  IconData get icon => switch (this) {
        NotificationType.requestSubmitted => Icons.upload_outlined,
        NotificationType.requestAccepted => Icons.local_shipping_outlined,
        NotificationType.statusChanged => Icons.sync_outlined,
        NotificationType.requestCompleted => Icons.check_circle_outline,
        NotificationType.pointsCredited => Icons.emoji_events_outlined,
        NotificationType.referralCompleted => Icons.card_giftcard_outlined,
        NotificationType.accountStatus => Icons.verified_user_outlined,
        NotificationType.announcement => Icons.campaign_outlined,
      };

  /// Couleur d'accent par type — le centre de notifications ne doit pas se
  /// lire comme une liste uniformément verte.
  Color get color => switch (this) {
        NotificationType.requestSubmitted => const Color(0xFF2094C4),
        NotificationType.requestAccepted => const Color(0xFF7C5CBF),
        NotificationType.statusChanged => const Color(0xFFB07E00),
        NotificationType.requestCompleted => const Color(0xFF0B622F),
        NotificationType.pointsCredited => const Color(0xFFC98A00),
        NotificationType.referralCompleted => const Color(0xFFE08E2C),
        NotificationType.accountStatus => const Color(0xFF17A398),
        NotificationType.announcement => const Color(0xFFB5792B),
      };
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool read;
  final String? relatedRequestId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.relatedRequestId,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: NotificationType.values.firstWhere((t) => t.name == d['type'],
          orElse: () => NotificationType.announcement),
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      read: d['read'] as bool? ?? false,
      relatedRequestId: d['relatedRequestId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
