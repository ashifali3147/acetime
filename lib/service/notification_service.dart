import 'dart:convert';
import 'dart:developer';

import 'package:acetime/service/ringtone_service.dart';
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
        // When tapped the app will receive this. Parse the payload and route.
        if (response.payload != null) {
          try {
            final payload = jsonDecode(response.payload!);
            if (payload['type'] == 'incoming_call') {
              final senderMap = jsonDecode(payload['sender'] ?? '{}');
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
              appRouter.push('/incoming-call', extra: {
                'callId': payload['callId'],
                'caller': sender,
              });
            }
          } catch (e) {
            // ignore parse errors
          }
        }
      },
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        // Show the in-app incoming call screen immediately
        _handleIncomingCall(message);
      } else {
        _showLocalNotification(message); // existing behavior for chat
      }
    });

    // Background / app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        _handleTapIncomingCall(message);
      } else {
        // existing chat navigation logic
        final senderJson = data['sender'];
        if (senderJson != null) {
          final senderMap = jsonDecode(senderJson) as Map<String, dynamic>;
          // create UserModel and route to chat
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
          appRouter.push('/chat', extra: sender);
        }
      }
    });

    // Terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final data = initialMessage.data;
      if (data['type'] == 'incoming_call') {
        // route to incoming call
        _handleTapIncomingCall(initialMessage);
      } else {
        // existing code
      }
    }
  }

  // Called when message arrives and it's an incoming_call and the app is foreground
  void _handleIncomingCall(RemoteMessage message) {
    final data = message.data;
    final senderJson = data['sender'];
    final senderMap = senderJson != null ? jsonDecode(senderJson) : {};
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

    // Use appRouter to push incoming call screen
    appRouter.push('/incoming-call', extra: {
      'callId': data['callId'],
      'caller': sender,
    });

    // Start ringtone loop
    RingtoneService().startRinging();

    // Start auto-decline timer (e.g., 30 seconds)
    RingtoneService().startAutoTimeout(() {
      // On timeout: stop ringtone and pop incoming screen if present
      RingtoneService().stopRinging();
      appRouter.pop(); // carefully ensure route exists
      // Optionally send a "missed call" signal to caller via Firestore/Push
    }, Duration(seconds: 30));
  }

  // Called when user taps a notification to open the incoming call (background/terminated)
  void _handleTapIncomingCall(RemoteMessage message) {
    final data = message.data;
    final senderJson = data['sender'];
    final senderMap = senderJson != null ? jsonDecode(senderJson) : {};
    final sender = UserModel(
      uid: senderMap['uid'],
      phone: senderMap['phone'],
      userName: senderMap['userName'],
      fcmToken: senderMap['fcmToken'],
    );

    appRouter.push('/incoming-call', extra: {
      'callId': data['callId'],
      'caller': sender,
    });

    // start ringtone and timeout as well (the incoming-call screen will stop it when accepted/rejected)
    RingtoneService().startRinging();
    RingtoneService().startAutoTimeout(() {
      RingtoneService().stopRinging();
      appRouter.pop();
    }, Duration(seconds: 30));
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

  /// Show a full-screen incoming-call local notification (Android)
  Future<void> showIncomingCallLocalNotification(RemoteMessage message) async {
    // Use fullScreenIntent on Android so OS shows full-screen activity for calls
    final data = message.data;
    final payload = jsonEncode(data);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Calls',
      channelDescription: 'Incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // critical to show full screen for incoming calls
      ticker: 'Incoming call',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      data['title'] ?? 'Incoming Call',
      data['body'] ?? 'Tap to answer',
      platformDetails,
      payload: payload,
    );

    // Note: showIncomingCallLocalNotification should be called for background/terminated messages
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
