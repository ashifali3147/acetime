import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> users;
  final String lastMessage;
  final String? lastMessageSenderId;
  final Timestamp lastMessageTime;
  final Map<String, int>? unreadCounts;
  final bool lastMessageSeen;

  ChatModel({
    required this.id,
    required this.users,
    required this.lastMessage,
    this.lastMessageSenderId,
    required this.lastMessageTime,
    this.unreadCounts,
    this.lastMessageSeen = false,
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> data) {
    final rawCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    final counts = rawCounts.map(
          (key, value) => MapEntry(key, (value as num).toInt()), // always safe
    );

    // Determine if the last message is seen by all except sender
    bool seen = false;
    if (data['lastMessageSenderId'] != null && counts.isNotEmpty) {
      final tempCounts = Map<String, int>.from(counts);
      tempCounts.remove(data['lastMessageSenderId']); // exclude sender
      seen = tempCounts.values.every((int count) => count == 0);
    }

    return ChatModel(
      id: id,
      users: List<String>.from(data['users'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'],
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      unreadCounts: counts,
      lastMessageSeen: seen,
    );
  }


}
