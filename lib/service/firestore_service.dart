import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> getOrCreateUser({
    required String? fcmToken,
    required String userName,
    required VoidCallback onSuccess,
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
        // ✅ Update FCM token
        await userRef.update({
          "fcmToken": fcmToken,
          "userName": userName,
          "lastLogin": FieldValue.serverTimestamp(),
        });
      } else {
        // ✅ Create new user doc
        await userRef.set({
          "phone": user.phoneNumber,
          "fcmToken": fcmToken,
          "userName": userName,
          "createdAt": FieldValue.serverTimestamp(),
          "lastLogin": FieldValue.serverTimestamp(),
        });
      }

      onSuccess();
    } catch (e) {
      onError("Something went wrong: $e");
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

}
