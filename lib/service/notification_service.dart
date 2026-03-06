import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:acetime/service/ringtone_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../model/user_model.dart';
import '../presentation/navigation/app_router.dart';

@pragma('vm:entry-point')
void onDidReceiveNotificationResponseBackground(NotificationResponse response) {
  NotificationService().handleNotificationResponse(response);
}

class NotificationService {
  // Singleton setup
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;
  bool _firebaseListenersInitialized = false;
  static const String _defaultChannelId = 'default_channel';
  static const String _callChannelId = 'call_channel';
  static const String _acceptCallActionId = 'accept_call';
  static const String _rejectCallActionId = 'reject_call';
  static final Int64List _callVibrationPattern = Int64List.fromList([
    0,
    700,
    500,
    900,
  ]);

  /// Initialize notifications (call this in main())
  Future<void> initialize() async {
    // Request notification permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('[NotificationService] Permission: ${settings.authorizationStatus}');

    await _initializeLocalNotifications(handleLaunchPayload: true);

    if (_firebaseListenersInitialized) return;
    _firebaseListenersInitialized = true;

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

    // Terminated state (FCM)
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

  /// Initialize only the local notification stack for background isolate.
  Future<void> initializeForBackgroundMessages() async {
    await _initializeLocalNotifications(handleLaunchPayload: false);
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      await showIncomingCallLocalNotificationFromData(data);
    }
  }

  Future<void> _initializeLocalNotifications({
    required bool handleLaunchPayload,
  }) async {
    if (_localNotificationsInitialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveNotificationResponseBackground,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        'General Notifications',
        description: 'Used for important notifications',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _callChannelId,
        'Calls',
        description: 'Incoming calls',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ringtone'),
        enableVibration: true,
        vibrationPattern: _callVibrationPattern,
      ),
    );

    if (handleLaunchPayload) {
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload != null) {
        try {
          final payload = jsonDecode(launchPayload) as Map<String, dynamic>;
          if (payload['type'] == 'incoming_call') {
            final senderMap = jsonDecode(payload['sender'] ?? '{}');
            final sender = UserModel(
              uid: senderMap['uid'],
              phone: senderMap['phone'],
              userName: senderMap['userName'],
              fcmToken: senderMap['fcmToken'],
            );
            appRouter.push('/incoming-call', extra: {
              'callId': payload['callId'],
              'caller': sender,
            });
          }
        } catch (e) {
          log('[NotificationService] Failed to parse launch payload: $e');
        }
      }
    }

    _localNotificationsInitialized = true;
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    if (response.payload == null) return;

    try {
      final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
      if (payload['type'] != 'incoming_call') return;

      final actionId = response.actionId;
      final notificationId = _callNotificationIdFromData(payload);

      if (actionId == _rejectCallActionId) {
        await _localNotifications.cancel(notificationId);
        await RingtoneService().stopRinging();
        return;
      }

      if (actionId == _acceptCallActionId || actionId == null) {
        await _localNotifications.cancel(notificationId);
        _openIncomingCallScreen(payload);
      }
    } catch (e) {
      log('[NotificationService] Failed to parse notification payload: $e');
    }
  }

  int _callNotificationIdFromData(Map<String, dynamic> data) {
    final callId = data['callId']?.toString();
    if (callId != null && callId.isNotEmpty) return callId.hashCode;
    return data.hashCode;
  }

  void _openIncomingCallScreen(Map<String, dynamic> payload) {
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
          _defaultChannelId,
          'General Notifications',
          channelDescription: 'Used for important notifications',
          importance: Importance.high,
          priority: Priority.high,
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
    await showIncomingCallLocalNotificationFromData(message.data);
  }

  /// Show a full-screen incoming-call local notification from data payload.
  Future<void> showIncomingCallLocalNotificationFromData(
    Map<String, dynamic> data,
  ) async {
    // Use fullScreenIntent on Android so OS shows full-screen activity for calls
    final payload = jsonEncode(data);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _callChannelId,
      'Calls',
      channelDescription: 'Incoming calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true, // critical to show full screen for incoming calls
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ringtone'),
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      enableVibration: true,
      vibrationPattern: _callVibrationPattern,
      ongoing: true,
      autoCancel: false,
      ticker: 'Incoming call',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _rejectCallActionId,
          'Reject',
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _acceptCallActionId,
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      _callNotificationIdFromData(data),
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

      final payloadData = (data ?? {}).map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      final isIncomingCall = payloadData['type'] == 'incoming_call';

      final message = {
        'message': {
          'token': deviceToken,
          'data': {
            ...payloadData,
            'title': title,
            'body': body,
          },
          'android': {'priority': 'high'},
          if (!isIncomingCall) 'notification': {'title': title, 'body': body},
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
