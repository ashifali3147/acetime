import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:acetime/service/call_service.dart';
import 'package:acetime/service/ios_voip_service.dart';
import 'package:acetime/service/ringtone_service.dart';
import 'package:acetime/utils/storage_helper.dart';
import 'package:daakia_vc_flutter_sdk/daakia_vc_flutter_sdk.dart';
import 'package:daakia_vc_flutter_sdk/model/daakia_meeting_configuration.dart';
import 'package:daakia_vc_flutter_sdk/model/participant_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../model/user_model.dart';
import '../presentation/navigation/app_router.dart';
import '../utils/navigator.dart';

@pragma('vm:entry-point')
Future<void> onDidReceiveNotificationResponseBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initializeForBackgroundMessages();
  await NotificationService().handleNotificationResponse(
    response,
    fromBackground: true,
  );
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
  bool _voipListenersInitialized = false;
  static const String _defaultChannelId = 'default_channel';
  static const String _callChannelId = 'call_channel';
  static const String _acceptCallActionId = 'accept_call';
  static const String _rejectCallActionId = 'reject_call';
  String? _activeIncomingCallId;
  DateTime? _lastIncomingRouteOpenAt;
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
    _initializeVoipListeners();

    if (_firebaseListenersInitialized) return;
    _firebaseListenersInitialized = true;

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'incoming_call') {
        // Show the in-app incoming call screen immediately
        _handleIncomingCall(message);
      } else if (data['type'] == 'call_ended') {
        _localNotifications.cancel(_callNotificationIdFromData(data));
        RingtoneService().stopRinging();
        _closeIncomingCallRouteIfOpen();
        if (data['reason'] == 'missed') {
          _showMissedCallNotificationFromData(data);
        }
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
            voipToken: senderMap['voipToken'],
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

  void _initializeVoipListeners() {
    if (_voipListenersInitialized) return;
    _voipListenersInitialized = true;

    IOSVoipService().events.listen((event) {
      switch (event.method) {
        case 'incomingCall':
          handleNativeIncomingCall(event.payload);
          break;
        case 'callAccepted':
          handleNativeCallAccepted(event.payload);
          break;
        case 'callDeclined':
          handleNativeCallDeclined(event.payload);
          break;
        case 'callEnded':
          handleNativeCallEnded(event.payload);
          break;
      }
    });
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      await showIncomingCallLocalNotificationFromData(data);
      return;
    }
    if (data['type'] == 'call_ended') {
      await _localNotifications.cancel(_callNotificationIdFromData(data));
      await RingtoneService().stopRinging();
      if (data['reason'] == 'missed') {
        await _showMissedCallNotificationFromData(data);
      }
    }
  }

  Future<void> _initializeLocalNotifications({
    required bool handleLaunchPayload,
  }) async {
    if (_localNotificationsInitialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings darwinInit =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              _callChannelId,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  _rejectCallActionId,
                  'Reject',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.destructive,
                  },
                ),
                DarwinNotificationAction.plain(
                  _acceptCallActionId,
                  'Accept',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
              ],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.customDismissAction,
              },
            ),
          ],
        );
    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
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
      final launchResponse = launchDetails?.notificationResponse;
      final launchPayload = launchResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload != null) {
        try {
          final payload = jsonDecode(launchPayload) as Map<String, dynamic>;
          if (payload['type'] == 'incoming_call') {
            final actionId = launchResponse?.actionId;
            if (actionId == _rejectCallActionId) {
              final callId = payload['callId']?.toString();
              final actorId = _resolveActorId(payload);
              if (callId != null && callId.isNotEmpty) {
                await CallService().markRejected(callId, actorId: actorId);
              }
              await _localNotifications.cancel(
                _callNotificationIdFromData(payload),
              );
              await RingtoneService().stopRinging();
              _closeIncomingCallRouteIfOpen();
            } else if (actionId == _acceptCallActionId) {
              await _handleAcceptAction(payload, openMeeting: true);
            } else {
              _openIncomingCallScreen(payload);
            }
          }
        } catch (e) {
          log('[NotificationService] Failed to parse launch payload: $e');
        }
      }
    }

    _localNotificationsInitialized = true;
  }

  Future<void> handleNotificationResponse(
    NotificationResponse response, {
    bool fromBackground = false,
  }) async {
    if (response.payload == null) return;

    try {
      final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
      if (payload['type'] != 'incoming_call') return;

      final actionId = response.actionId;
      final notificationId = _callNotificationIdFromData(payload);

      if (actionId == _rejectCallActionId) {
        final callId = payload['callId']?.toString();
        final actorId = _resolveActorId(payload);
        if (callId != null && callId.isNotEmpty) {
          await CallService().markRejected(callId, actorId: actorId);
        }
        await _localNotifications.cancel(notificationId);
        await RingtoneService().stopRinging();
        _closeIncomingCallRouteIfOpen();
        return;
      }

      if (actionId == _acceptCallActionId || actionId == null) {
        await _localNotifications.cancel(notificationId);
        await _handleAcceptAction(payload, openMeeting: !fromBackground);
        if (actionId == null && fromBackground) {
          _openIncomingCallScreen(payload);
        }
        return;
      }

      await _localNotifications.cancel(notificationId);
      _openIncomingCallScreen(payload);
    } catch (e) {
      log('[NotificationService] Failed to parse notification payload: $e');
    }
  }

  int _callNotificationIdFromData(Map<String, dynamic> data) {
    final callId = data['callId']?.toString();
    if (callId != null && callId.isNotEmpty) return callId.hashCode;
    return data.hashCode;
  }

  Future<void> dismissIncomingCallNotification(String? callId) async {
    if (callId == null || callId.isEmpty) return;
    await _localNotifications.cancel(callId.hashCode);
  }

  Future<void> handleNativeIncomingCall(Map<String, dynamic> data) async {
    _openIncomingCallScreen(data);
    RingtoneService().startRinging();
    RingtoneService().startAutoTimeout(() {
      final callId = data['callId']?.toString();
      if (callId != null && callId.isNotEmpty) {
        CallService().markMissedIfStillRinging(callId);
      }
      RingtoneService().stopRinging();
      _closeIncomingCallRouteIfOpen();
    }, const Duration(seconds: 30));
  }

  Future<void> handleNativeCallAccepted(Map<String, dynamic> data) async {
    await _handleAcceptAction(data, openMeeting: true);
  }

  Future<void> handleNativeCallDeclined(Map<String, dynamic> data) async {
    final callId = data['callId']?.toString();
    final actorId = _resolveActorId(data);
    if (callId != null && callId.isNotEmpty) {
      await CallService().markRejected(callId, actorId: actorId);
    }
    await dismissIncomingCallNotification(callId);
    await RingtoneService().stopRinging();
    _closeIncomingCallRouteIfOpen();
  }

  Future<void> handleNativeCallEnded(Map<String, dynamic> data) async {
    final callId = data['callId']?.toString();
    await IOSVoipService().endCall(callId);
    await dismissIncomingCallNotification(callId);
    await RingtoneService().stopRinging();
    _closeIncomingCallRouteIfOpen();
  }

  void _closeIncomingCallRouteIfOpen() {
    try {
      final currentPath = appRouter.routeInformationProvider.value.uri.path;
      if (currentPath == '/incoming-call') {
        if (appRouter.canPop()) {
          appRouter.pop();
        } else {
          appRouter.go('/home');
        }
      }
      _activeIncomingCallId = null;
    } catch (_) {
      // ignore route state errors
    }
  }

  void _openIncomingCallScreen(Map<String, dynamic> payload) {
    final callId = payload['callId']?.toString();
    final now = DateTime.now();
    final openedRecently =
        _lastIncomingRouteOpenAt != null &&
        now.difference(_lastIncomingRouteOpenAt!).inSeconds < 2;
    if (callId != null && _activeIncomingCallId == callId && openedRecently) {
      return;
    }

    final currentPath = appRouter.routeInformationProvider.value.uri.path;
    if (currentPath == '/incoming-call') {
      if (callId != null && _activeIncomingCallId == callId) return;
      if (appRouter.canPop()) appRouter.pop();
    }

    final senderRaw = payload['sender'];
    final senderMap = senderRaw is String
        ? jsonDecode(senderRaw) as Map<String, dynamic>
        : Map<String, dynamic>.from(senderRaw as Map? ?? const {});
    final sender = UserModel(
      uid: senderMap['uid'],
      phone: senderMap['phone'],
      userName: senderMap['userName'],
      fcmToken: senderMap['fcmToken'],
      voipToken: senderMap['voipToken'],
      createdAt: senderMap['createdAt'] != null
          ? DateTime.parse(senderMap['createdAt'])
          : null,
      lastLogin: senderMap['lastLogin'] != null
          ? DateTime.parse(senderMap['lastLogin'])
          : null,
    );

    _activeIncomingCallId = callId;
    _lastIncomingRouteOpenAt = now;
    dismissIncomingCallNotification(callId);
    appRouter.push(
      '/incoming-call',
      extra: {'callId': callId, 'caller': sender},
    );
  }

  Future<void> _openMeetingDirectly(String meetingId) async {
    NavigatorState? navigator;
    for (var attempt = 0; attempt < 50; attempt++) {
      navigator = navigatorKey.currentState;
      if (navigator != null) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (navigator == null) return;

    await navigator.push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => DaakiaVideoConferenceWidget(
          meetingId: meetingId,
          secretKey: dotenv.env['LICENSE_KEY'] ?? "",
          isHost: false,
          configuration: DaakiaMeetingConfiguration(
            participantNameConfig: ParticipantNameConfig(
              name: StorageHelper().getUserName(),
              isEditable: false,
            ),
              skipPreJoinPage: true,
              enableCameraByDefault: true,
              enableMicrophoneByDefault: true
          ),
        ),
      ),
    );
    await CallService().markEnded(
      meetingId,
      actorId: FirebaseAuth.instance.currentUser?.uid,
    );
    await IOSVoipService().endCall(meetingId);
  }

  Future<void> _handleAcceptAction(
    Map<String, dynamic> payload, {
    required bool openMeeting,
  }) async {
    final callId = payload['callId']?.toString();
    if (callId == null || callId.isEmpty) return;
    final actorId = _resolveActorId(payload);

    await CallService().markAccepted(callId, actorId: actorId);
    await dismissIncomingCallNotification(callId);
    await RingtoneService().stopRinging();
    _closeIncomingCallRouteIfOpen();
    await IOSVoipService().setCallConnected(callId);

    if (openMeeting) {
      await _openMeetingDirectly(callId);
    }
  }

  String? _resolveActorId(Map<String, dynamic> payload) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;

    final receiverId = payload['receiverId']?.toString();
    if (receiverId != null && receiverId.isNotEmpty) return receiverId;

    final userId = payload['userId']?.toString();
    if (userId != null && userId.isNotEmpty) return userId;

    return null;
  }

  // Called when message arrives and it's an incoming_call and the app is foreground
  void _handleIncomingCall(RemoteMessage message) {
    final data = message.data;
    _openIncomingCallScreen(data);

    // Start ringtone loop
    RingtoneService().startRinging();

    // Start auto-decline timer (e.g., 30 seconds)
    RingtoneService().startAutoTimeout(() {
      // On timeout: stop ringtone and pop incoming screen if present
      final callId = data['callId']?.toString();
      if (callId != null && callId.isNotEmpty) {
        CallService().markMissedIfStillRinging(callId);
      }
      RingtoneService().stopRinging();
      _closeIncomingCallRouteIfOpen();
      // Optionally send a "missed call" signal to caller via Firestore/Push
    }, Duration(seconds: 30));
  }

  // Called when user taps a notification to open the incoming call (background/terminated)
  void _handleTapIncomingCall(RemoteMessage message) {
    final data = message.data;
    _openIncomingCallScreen(data);

    // start ringtone and timeout as well (the incoming-call screen will stop it when accepted/rejected)
    RingtoneService().startRinging();
    RingtoneService().startAutoTimeout(() {
      final callId = data['callId']?.toString();
      if (callId != null && callId.isNotEmpty) {
        CallService().markMissedIfStillRinging(callId);
      }
      RingtoneService().stopRinging();
      _closeIncomingCallRouteIfOpen();
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

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
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

  Future<void> _showMissedCallNotificationFromData(
    Map<String, dynamic> data,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _defaultChannelId,
          'General Notifications',
          channelDescription: 'Used for important notifications',
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      '${data['callId']}_missed'.hashCode,
      'Missed call',
      'You missed a call',
      platformDetails,
      payload: jsonEncode(data),
    );
  }

  /// Show a full-screen incoming-call local notification from data payload.
  Future<void> showIncomingCallLocalNotificationFromData(
    Map<String, dynamic> data,
  ) async {
    // Use fullScreenIntent on Android so OS shows full-screen activity for calls
    final payload = jsonEncode(data);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _callChannelId,
          'Calls',
          channelDescription: 'Incoming calls',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent:
              true, // critical to show full screen for incoming calls
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
              showsUserInterface: true,
              cancelNotification: true,
              titleColor: Colors.red,
            ),
            AndroidNotificationAction(
              _acceptCallActionId,
              'Accept',
              showsUserInterface: true,
              cancelNotification: true,
              titleColor: Colors.green,
            ),
          ],
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _callChannelId,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
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
      final type = payloadData['type'];
      final isCallSignal = type == 'incoming_call' || type == 'call_ended';

      final message = {
        'message': {
          'token': deviceToken,
          'data': {...payloadData, 'title': title, 'body': body},
          'android': {'priority': 'high'},
          if (!isCallSignal) 'notification': {'title': title, 'body': body},
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
