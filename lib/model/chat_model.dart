import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> users;
  final String lastMessage;
  final Timestamp lastMessageTime;
  final String lastSenderId;

  ChatModel({
    required this.id,
    required this.users,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatModel(
      id: id,
      users: List<String>.from(map['users'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] ?? Timestamp.now(),
      lastSenderId: map['lastSenderId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'users': users,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastSenderId': lastSenderId,
    };
  }
}
