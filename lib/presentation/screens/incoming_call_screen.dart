import 'package:daakia_vc_flutter_sdk/daakia_vc_flutter_sdk.dart';
import 'package:daakia_vc_flutter_sdk/model/daakia_meeting_configuration.dart';
import 'package:daakia_vc_flutter_sdk/model/participant_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../model/user_model.dart';
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
  @override
  void initState() {
    super.initState();
    // start ringtone (RingtoneService)
    RingtoneService().startRinging();
    // start auto-timeout as a safety too (in case NotificationService didn't)
    RingtoneService().startAutoTimeout(() {
      // auto-decline behavior: pop screen and stop ringtone
      if (mounted) Navigator.of(context).pop();
      RingtoneService().stopRinging();
      // optionally notify caller about missed call (via Firestore)
    }, const Duration(seconds: 30));
  }

  @override
  void dispose() {
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
                  onPressed: () {
                    // stop ringtone and close
                    RingtoneService().stopRinging();
                    Navigator.pop(context); // Close incoming call screen
                    // optionally send "rejected" event to caller via Firestore/FCM
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  heroTag: "accept",
                  onPressed: () async {
                    RingtoneService().stopRinging();
                    final meetingId = widget.callId;
                    if (meetingId != null) {
                      Navigator.pop(context);
                      // join meeting as participant
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
                            ),
                          ),
                        ),
                      );
                    } else {
                      // show error (no meeting id)
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
