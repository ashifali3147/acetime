import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';

import '../utils/storage_helper.dart';
import 'firestore_service.dart';

class FcmService {
  // Singleton setup
  FcmService._internal();

  static final FcmService _instance = FcmService._internal();

  factory FcmService() => _instance;

  String? _cachedToken;

  /// Call this early (e.g., during app startup or before login)
  Future<String?> getFcmToken() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      if (Platform.isIOS) {
        final settings = await messaging.requestPermission(provisional: true);

        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('[FCM] iOS permission denied');
          return null;
        }

        // First attempt to get APNs token
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('[FCM] APNs token not available yet, retrying in 3s...');
          await Future<void>.delayed(const Duration(seconds: 3));
          apnsToken = await messaging.getAPNSToken();
        }

        if (apnsToken == null) {
          debugPrint('[FCM] Failed to get APNs token after retry');
          return null;
        }
      }

      final token = await messaging.getToken();

      if (token != null) {
        _cachedToken = token;
      } else {
        debugPrint('[FCM] Failed to get FCM token');
      }

      return token;
    } catch (e) {
      debugPrint('[FCM] Error retrieving token: $e');
      return null;
    }
  }

  /// Listen for token refresh
  void listenForTokenRefresh({Function(String newToken)? onRefresh}) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _cachedToken = newToken;
      StorageHelper().setFCMToken(newToken);
      await FirestoreService().updateFcmToken(fcmToken: newToken);
      onRefresh?.call(newToken);
    });
  }

  /// Access the last fetched token (if cached)
  String? get cachedToken => _cachedToken;
}
