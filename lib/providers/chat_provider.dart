import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../model/message_model.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  List<MessageModel> _messages = [];
  bool _isLoading = false;

  String? _error;

  List<MessageModel> get messages => _messages;

  bool get isLoading => _isLoading;

  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? get error => _error;

  // Generate consistent chatId for 1-on-1 chat
  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return sorted.join('_');
  }

  // Listen messages in real-time
  void listenMessages(String chatId) {
    _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          _messages = snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList();
          notifyListeners();
        });
  }

  // Send message
  Future<void> sendMessage(String chatId, String text) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final message = MessageModel(
      id: '',
      senderId: currentUser.uid,
      text: text,
      timestamp: Timestamp.now(),
    );

    final chatRef = _firestore.collection('chats').doc(chatId);

    // Add message
    await chatRef.collection('messages').add(message.toMap());

    // Update last message
    await chatRef.set({
      'users': chatId.split('_'),
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUser.uid,
    }, SetOptions(merge: true));
  }
}
