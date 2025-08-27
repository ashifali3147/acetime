import 'package:acetime/utils/storage_helper.dart';
import 'package:daakia_vc_flutter_sdk/daakia_vc_flutter_sdk.dart';
import 'package:daakia_vc_flutter_sdk/model/daakia_meeting_configuration.dart';
import 'package:daakia_vc_flutter_sdk/model/participant_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../model/user_model.dart';

class IncomingCallScreen extends StatelessWidget {
  final String? callId;
  final UserModel caller;

  const IncomingCallScreen({
    super.key,
    this.callId,
    required this.caller,
  });

  @override
  Widget build(BuildContext context) {
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
                // Reject Button
                FloatingActionButton(
                  heroTag: "reject",
                  onPressed: () {
                    Navigator.pop(context); // Close incoming call screen
                    // Optionally: send "rejected" event to caller via Firestore/FCM
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end),
                ),
                // Accept Button
                FloatingActionButton(
                  heroTag: "accept",
                  onPressed: () async {
                    var meetingId = callId;
                    if (meetingId != null) {
                      print("Meeting created: $meetingId");
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
