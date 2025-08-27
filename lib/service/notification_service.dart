import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../model/user_model.dart';
import '../presentation/navigation/app_router.dart';

class NotificationService {
  // Singleton setup
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notifications (call this in main())
  Future<void> initialize() async {
    // Request notification permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('[NotificationService] Permission: ${settings.authorizationStatus}');

    // Initialize local notifications
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        log('[NotificationService] Notification tapped: ${response.payload}');
      },
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('[NotificationService] Foreground message: ${message.data}');
      _showLocalNotification(message);
    });

    // Background / app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      log('[NotificationService] Notification clicked: ${message.data}');
      // Handle navigation here
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        final data = initialMessage.data;
        // final chatId = data['chatId'];
        final senderJson = data['sender'];

        final senderMap = jsonDecode(senderJson) as Map<String, dynamic>;
        final sender = UserModel(
          uid: senderMap['uid'],
          phone: senderMap['phone'],
          userName: senderMap['userName'],
          fcmToken: senderMap['fcmToken'],
          createdAt: senderMap['createdAt'] != null
              ? DateTime.parse(senderMap['createdAt'])
              : null,
          lastLogin: senderMap['lastLogin'] != null
              ? DateTime.parse(senderMap['lastLogin'])
              : null,
        );

        // Navigate to chat screen
        Future.delayed(Duration.zero, () {
          appRouter.go('/chat', extra: sender);
        });
      }
    });

    // Terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      log(
        '[NotificationService] App opened from terminated: ${initialMessage.data}',
      );
    }
  }

  /// Show local notification (for foreground)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel',
          'General Notifications',
          channelDescription: 'Used for important notifications',
          importance: Importance.low,
          priority: Priority.low,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// 🔹 Get access token using service account (OAuth2 flow)
  Future<AccessCredentials> _getAccessToken() async {
    final serviceAccountPath = dotenv.env['PATH_TO_SECRET'];
    String serviceAccountJson = await rootBundle.loadString(
      serviceAccountPath!,
    );

    final serviceAccount = ServiceAccountCredentials.fromJson(
      serviceAccountJson,
    );

    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await clientViaServiceAccount(serviceAccount, scopes);
    return client.credentials;
  }

  /// 🔹 Send push notification using FCM HTTP v1 API
  Future<bool> sendPushNotification({
    required String deviceToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (deviceToken.isEmpty) return false;

    try {
      final credentials = await _getAccessToken();
      final accessToken = credentials.accessToken.data;
      final projectId = dotenv.env['PROJECT_ID'];

      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
      );

      final message = {
        'message': {
          'token': deviceToken,
          'notification': {'title': title, 'body': body},
          'data': data ?? {},
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        log('[NotificationService] Notification sent successfully');
        return true;
      } else {
        log('[NotificationService] Failed: ${response.body}');
        return false;
      }
    } catch (e) {
      log('[NotificationService] Error sending notification: $e');
      return false;
    }
  }
}
