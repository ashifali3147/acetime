import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? phone;
  final String? userName;
  final String? fcmToken;
  final String? voipToken;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.uid,
    this.phone,
    this.userName,
    this.fcmToken,
    this.voipToken,
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
      voipToken: data["voipToken"],
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
      "voipToken": voipToken,
      "createdAt": createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      "lastLogin": lastLogin != null
          ? Timestamp.fromDate(lastLogin!)
          : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "phone": phone,
      "userName": userName,
      "fcmToken": fcmToken,
      "voipToken": voipToken,
      "createdAt": createdAt?.toIso8601String(),
      "lastLogin": lastLogin?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? phone,
    String? userName,
    String? fcmToken,
    String? voipToken,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      userName: userName ?? this.userName,
      fcmToken: fcmToken ?? this.fcmToken,
      voipToken: voipToken ?? this.voipToken,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
