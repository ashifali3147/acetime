import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MeetingService {
  static final String _baseUrl = dotenv.env['API_URL'] ?? "";
  static final String _secretKey = dotenv.env['LICENSE_KEY'] ?? ""; // replace with your real key

  static Future<String?> createMeeting({
    required String hostName,
    required String hostEmail,
    required Function(String error) onError,
  }) async {
    try {
      // Ensure date is always at least 2 minutes in the future
      final int futureTime = DateTime.now()
          .add(const Duration(minutes: 2))
          .millisecondsSinceEpoch;

      final body = {
        "event_name": "Call Test",
        "host": hostName,
        "host_email": hostEmail,
        "date": futureTime,
        "duration": "5000",
        "time_zone_id": "Asia/Kolkata",
        "topic": "test only",
        "event_type": "Conference",
        "allow_common_password": false,
        "is_lobby_mode": false,
        "is_participant_mode": true,
        "allow_standard_password": false,
        "is_auto_start_recording": false,
        "invitee_email": []
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "secret": _secretKey,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == 1 && data["data"]?["meeting_id"] != null) {
          return data["data"]["meeting_id"];
        } else {
          onError(data["message"] ?? "Failed to connect call");
          return null;
        }
      } else {
        onError("HTTP ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      onError("Error connecting call: $e");
      return null;
    }
  }
}
