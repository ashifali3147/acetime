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
      body: Container(
        width: double.maxFinite,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121212), Color(0xFF0A2A43)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    color: Colors.blueGrey.shade700,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    caller.userName?.substring(0, 1).toUpperCase() ?? "U",
                    style: const TextStyle(
                      fontSize: 44,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  caller.userName ?? "Unknown",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Incoming Call",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  "Respond to join or decline the call",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                                NotificationService()
                                    .dismissIncomingCallNotification(callId),
                              );
                              if (!context.mounted) return;
                              _closeIncomingScreenSafely();
                            },
                            backgroundColor: const Color(0xFFE53935),
                            elevation: 6,
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Decline",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                                  await IOSVoipService().setCallConnected(
                                    meetingId,
                                  );
                                  if (!context.mounted) return;
                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DaakiaVideoConferenceWidget(
                                            meetingId: meetingId,
                                            secretKey:
                                                dotenv.env['LICENSE_KEY'] ?? "",
                                            isHost: false,
                                            configuration:
                                                DaakiaMeetingConfiguration(
                                                  participantNameConfig:
                                                      ParticipantNameConfig(
                                                        name: StorageHelper()
                                                            .getUserName(),
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
                            backgroundColor: const Color(0xFF43A047),
                            elevation: 6,
                            child: const Icon(Icons.call, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Accept",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
