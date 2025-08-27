import 'package:acetime/utils/storage_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../model/user_model.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> getOrCreateUser({
    required String? fcmToken,
    required String userName,
    required Function() onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        onError("No authenticated user found");
        return;
      }

      final userRef = _firestore.collection("users").doc(user.uid);
      final doc = await userRef.get();

      if (doc.exists) {
        // ✅ Update
        await userRef.update({
          "fcmToken": fcmToken,
          "userName": userName,
          "lastLogin": FieldValue.serverTimestamp(),
        });
      } else {
        // ✅ Create
        final newUser = UserModel(
          uid: user.uid,
          phone: user.phoneNumber,
          userName: userName,
          fcmToken: fcmToken,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );
        await userRef.set(newUser.toMap());
      }
      StorageHelper().setUserName(userName);
      onSuccess();
    } catch (e) {
      onError("Something went wrong: $e");
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.id, doc.data()!);
  }

  /// Update current user's FCM token in Firestore
  Future<void> updateFcmToken({
    required String fcmToken,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("No authenticated user found");
        return;
      }

      final userRef = _firestore.collection('users').doc(user.uid);

      await userRef.update({
        'fcmToken': fcmToken,
        'lastLogin': FieldValue.serverTimestamp(), // optional: update lastLogin
      });
    } catch (e) {
      debugPrint("Failed to update FCM token: $e");
    }
  }


  /// Fetch cached contacts for the current user
  Future<List<UserModel>> getUserContacts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Sync contacts to Firestore under current user's 'contacts' subcollection
  Future<void> syncContactsToFirestore(List<UserModel> contacts) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();
    final userContactsRef =
    _firestore.collection('users').doc(currentUser.uid).collection('contacts');

    for (var contact in contacts) {
      final docRef = userContactsRef.doc(contact.uid);
      batch.set(docRef, contact.toMap());
    }

    await batch.commit();
  }
}
