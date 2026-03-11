import 'dart:async';

import 'package:acetime/model/user_model.dart';
import 'package:acetime/service/call_service.dart';
import 'package:acetime/service/ios_voip_service.dart';
import 'package:acetime/service/notification_service.dart';
import 'package:acetime/utils/storage_helper.dart';
import 'package:daakia_vc_flutter_sdk/daakia_vc_flutter_sdk.dart';
import 'package:daakia_vc_flutter_sdk/model/daakia_meeting_configuration.dart';
import 'package:daakia_vc_flutter_sdk/model/participant_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callId;
  final UserModel receiver;

  const OutgoingCallScreen({
    super.key,
    required this.callId,
    required this.receiver,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  StreamSubscription? _callSubscription;
  Timer? _timeoutTimer;
  bool _joining = false;
  bool _handledTerminalStatus = false;
  bool _isClosing = false;

  void _closeOutgoingScreenSafely() {
    if (!mounted || _isClosing) return;
    _isClosing = true;
    _callSubscription?.cancel();
    _timeoutTimer?.cancel();

    Future.microtask(() {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.go('/home');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _listenCallState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 30), () async {
      await CallService().markMissedIfStillRinging(
        widget.callId,
        actorId: FirebaseAuth.instance.currentUser?.uid,
      );
      await _sendCallEndedPush('missed');
      if (mounted && !_joining) _closeOutgoingScreenSafely();
    });
  }

  void _listenCallState() {
    _callSubscription = CallService().watchCall(widget.callId).listen((
      snapshot,
    ) async {
      final data = snapshot.data();
      final status = data?['status'] as String?;

      if (status == null) return;

      if (status == CallStatus.accepted && !_joining) {
        _joining = true;
        _timeoutTimer?.cancel();
        await _joinMeetingAsCaller();
        return;
      }

      if (_handledTerminalStatus) return;
      if (status == CallStatus.rejected ||
          status == CallStatus.missed ||
          status == CallStatus.cancelled) {
        _handledTerminalStatus = true;
        if (mounted) _closeOutgoingScreenSafely();
      }
    });
  }

  Future<void> _joinMeetingAsCaller() async {
    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DaakiaVideoConferenceWidget(
          meetingId: widget.callId,
          secretKey: dotenv.env['LICENSE_KEY'] ?? "",
          isHost: true,
          configuration: DaakiaMeetingConfiguration(
            participantNameConfig: ParticipantNameConfig(
              name: StorageHelper().getUserName(),
              isEditable: true,
            ),
            skipPreJoinPage: true,
          ),
        ),
      ),
    );

    await CallService().markEnded(
      widget.callId,
      actorId: FirebaseAuth.instance.currentUser?.uid,
    );
    await IOSVoipService().endCall(widget.callId);
    if (mounted) _closeOutgoingScreenSafely();
  }

  Future<void> _cancelCall() async {
    await CallService().markCancelled(
      widget.callId,
      actorId: FirebaseAuth.instance.currentUser?.uid,
    );
    await IOSVoipService().endCall(widget.callId);
    await _sendCallEndedPush('cancelled');
    if (mounted) _closeOutgoingScreenSafely();
  }

  Future<void> _sendCallEndedPush(String reason) async {
    final token = widget.receiver.fcmToken;
    if (token == null || token.isEmpty) return;

    await NotificationService().sendPushNotification(
      deviceToken: token,
      title: 'Call ended',
      body: 'Call $reason',
      data: {'type': 'call_ended', 'callId': widget.callId, 'reason': reason},
    );
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receiver = widget.receiver;

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
                    receiver.userName?.substring(0, 1).toUpperCase() ?? "U",
                    style: const TextStyle(
                      fontSize: 44,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  receiver.userName ?? "Unknown",
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
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Ringing...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  "Waiting for receiver to accept",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 20),
                FloatingActionButton(
                  heroTag: "cancel-outgoing",
                  onPressed: _cancelCall,
                  backgroundColor: const Color(0xFFE53935),
                  elevation: 6,
                  child: const Icon(Icons.call_end, color: Colors.white),
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
