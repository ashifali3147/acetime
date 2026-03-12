import 'dart:async';

import 'package:daakia_vc_flutter_sdk/daakia_vc_flutter_sdk.dart';
import 'package:daakia_vc_flutter_sdk/model/daakia_meeting_configuration.dart';
import 'package:daakia_vc_flutter_sdk/model/participant_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

import '../../model/user_model.dart';
import '../../service/call_service.dart';
import '../../service/ios_voip_service.dart';
import '../../service/notification_service.dart';
import '../../service/ringtone_service.dart';
import '../../utils/storage_helper.dart';

class IncomingCallScreen extends StatefulWidget {
  final String? callId;
  final UserModel caller;

  const IncomingCallScreen({super.key, this.callId, required this.caller});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  StreamSubscription? _callSubscription;
  bool _closedByState = false;
  bool _accepting = false;

  void _closeIncomingScreenSafely() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // Fallback to a stable route to avoid empty go_router configuration.
    context.go('/home');
  }

  @override
  void initState() {
    super.initState();
    _listenCallState();
    NotificationService().dismissIncomingCallNotification(widget.callId);
    // start ringtone (RingtoneService)
    RingtoneService().startRinging();
    // start auto-timeout as a safety too (in case NotificationService didn't)
    RingtoneService().startAutoTimeout(() {
      // auto-decline behavior: pop screen and stop ringtone
      if (widget.callId != null) {
        CallService().markMissedIfStillRinging(
          widget.callId!,
          actorId: _currentUid,
        );
      }
      if (!_closedByState) _closeIncomingScreenSafely();
      RingtoneService().stopRinging();
      // optionally notify caller about missed call (via Firestore)
    }, const Duration(seconds: 30));
  }

  void _listenCallState() {
    final callId = widget.callId;
    if (callId == null || callId.isEmpty) return;

    _callSubscription = CallService().watchCall(callId).listen((snapshot) {
      final status = snapshot.data()?['status'] as String?;
      if (status == null || _closedByState) return;

      final shouldClose =
          status == CallStatus.cancelled ||
          status == CallStatus.rejected ||
          status == CallStatus.missed ||
          status == CallStatus.ended;
      if (!shouldClose) return;

      _closedByState = true;
      RingtoneService().stopRinging();
      _closeIncomingScreenSafely();
    });
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    RingtoneService().stopRinging();
    RingtoneService().cancelAutoTimeout();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.caller;

    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.orange,
              child: Text(
                caller.userName?.substring(0, 1) ?? "A",
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              caller.userName ?? "Unknown",
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Incoming Call",
              style: TextStyle(fontSize: 20, color: Colors.white70),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "reject",
                  onPressed: () async {
                    _closedByState = true;
                    final callId = widget.callId;
                    if (callId != null && callId.isNotEmpty) {
                      await CallService().markRejected(
                        callId,
                        actorId: _currentUid,
                      );
                      await IOSVoipService().endCall(callId);
                    }
                    await RingtoneService().stopRinging();
                    unawaited(
                      NotificationService().dismissIncomingCallNotification(
                        callId,
                      ),
                    );
                    if (!context.mounted) return;
                    _closeIncomingScreenSafely();
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  heroTag: "accept",
                  onPressed: () async {
                    if (_accepting) return;
                    _accepting = true;
                    try {
                      RingtoneService().stopRinging();
                      final meetingId = widget.callId;
                      if (meetingId != null) {
                        final accepted = await CallService()
                            .markAcceptedIfStillRinging(
                              meetingId,
                              actorId: _currentUid,
                            );
                        if (!accepted) {
                          await IOSVoipService().endCall(meetingId);
                          if (context.mounted) {
                            _closeIncomingScreenSafely();
                          }
                          return;
                        }
                        await IOSVoipService().setCallConnected(meetingId);
                        if (!context.mounted) return;
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DaakiaVideoConferenceWidget(
                              meetingId: meetingId,
                              secretKey: dotenv.env['LICENSE_KEY'] ?? "",
                              isHost: false,
                              configuration: DaakiaMeetingConfiguration(
                                participantNameConfig: ParticipantNameConfig(
                                  name: StorageHelper().getUserName(),
                                  isEditable: false,
                                ),
                                skipPreJoinPage: true,
                              ),
                            ),
                          ),
                        );
                        await CallService().markEnded(
                          meetingId,
                          actorId: _currentUid,
                        );
                        await IOSVoipService().endCall(meetingId);
                        if (context.mounted) {
                          _closeIncomingScreenSafely();
                        }
                      } else {
                        // show error (no meeting id)
                      }
                    } finally {
                      _accepting = false;
                    }
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
