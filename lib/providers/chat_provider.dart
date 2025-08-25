import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/user_model.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  StreamSubscription? _subscription;

  /// Generate a consistent chatId based on two user IDs
  String getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '$uid1\_$uid2' : '$uid2\_$uid1';
  }

  /// Listen for messages in real-time
  void listenMessages(String chatId) {
    _subscription?.cancel();
    isLoading = true;
    notifyListeners();

    _subscription = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'senderId': data['senderId'],
          'receiverId': data['receiverId'],
          'text': data['text'] ?? '',
          'timestamp': data['timestamp'],
          'seen': data['seen'] ?? false,
        };
      }).toList();
      isLoading = false;
      notifyListeners();
    });
  }

  /// Send a message
  Future<void> sendMessage(String chatId, UserModel receiver, String text) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();

    final messageData = {
      'senderId': currentUser.uid,
      'receiverId': receiver.uid,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'seen': false,
    };

    // Add message to Firestore
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(messageData);

    // Update last message, timestamp, sender, and unread count
    await _firestore.collection('chats').doc(chatId).set({
      'users': [currentUser.uid, receiver.uid],
      'lastMessage': text,
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'lastMessageSenderId': currentUser.uid,
      'unreadCounts': {
        receiver.uid: FieldValue.increment(1)
      }, // only increment receiver
    }, SetOptions(merge: true));
  }

  /// Mark all messages as seen when user opens the chat
  Future<void> markMessagesAsSeen(String chatId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('seen', isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'seen': true});
    }

    // Reset unread count for current user
    batch.update(_firestore.collection('chats').doc(chatId), {
      'unreadCounts.${currentUser.uid}': 0,
    });

    await batch.commit();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
