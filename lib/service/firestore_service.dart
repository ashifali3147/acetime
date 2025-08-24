import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}
