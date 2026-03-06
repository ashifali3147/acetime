import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? phone;
  final String? userName;
  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.uid,
    this.phone,
    this.userName,
    this.fcmToken,
    this.createdAt,
    this.lastLogin,
  });

  // Convert Firestore → Model
  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      phone: data["phone"],
      userName: data["userName"],
      fcmToken: data["fcmToken"],
      createdAt: (data["createdAt"] as Timestamp?)?.toDate(),
      lastLogin: (data["lastLogin"] as Timestamp?)?.toDate(),
    );
  }

  // Convert Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      "phone": phone,
      "userName": userName,
      "fcmToken": fcmToken,
      "createdAt": createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      "lastLogin": lastLogin != null ? Timestamp.fromDate(lastLogin!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "phone": phone,
      "userName": userName,
      "fcmToken": fcmToken,
      "createdAt": createdAt?.toIso8601String(),
      "lastLogin": lastLogin?.toIso8601String(),
    };
  }

}
