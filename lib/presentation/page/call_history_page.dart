import 'package:acetime/service/call_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CallHistoryPage extends StatelessWidget {
  const CallHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text("Login required"));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('calls')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No call history yet"));
        }

        final callDocs = [...snapshot.data!.docs];
        callDocs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTime = _toDateTime(aData['updatedAt']) ??
              _toDateTime(aData['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = _toDateTime(bData['updatedAt']) ??
              _toDateTime(bData['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        return ListView.separated(
          itemCount: callDocs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = callDocs[index].data();
            final callerId = data['callerId']?.toString() ?? '';
            final status = data['status']?.toString() ?? '';
            final isOutgoing = callerId == currentUser.uid;
            final displayName = isOutgoing
                ? (data['receiverName']?.toString() ?? 'Unknown')
                : (data['callerName']?.toString() ?? 'Unknown');

            final updatedAt = _toDateTime(data['updatedAt']);
            final createdAt = _toDateTime(data['createdAt']);
            final acceptedAt = _toDateTime(data['acceptedAt']);
            final endedAt = _toDateTime(data['endedAt']);
            final durationText = _durationText(
              acceptedAt: acceptedAt,
              endedAt: endedAt,
            );
            final timeText = DateFormat('dd MMM, hh:mm a').format(
              updatedAt ?? createdAt ?? DateTime.now(),
            );

            final isMissed = status == CallStatus.missed;
            final statusText = _statusLabel(status: status, isOutgoing: isOutgoing);
            final statusColor = isMissed ? Colors.red : Colors.grey.shade700;
            final directionIcon = isOutgoing ? Icons.call_made : Icons.call_received;
            final directionColor = isMissed ? Colors.red : Colors.green;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey.shade100,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                ),
              ),
              title: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Row(
                children: [
                  Icon(directionIcon, size: 16, color: directionColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      durationText.isEmpty ? statusText : '$statusText • $durationText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: statusColor),
                    ),
                  ),
                ],
              ),
              trailing: Text(
                timeText,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _durationText({
    required DateTime? acceptedAt,
    required DateTime? endedAt,
  }) {
    if (acceptedAt == null || endedAt == null) return '';
    final diff = endedAt.difference(acceptedAt);
    if (diff.inSeconds <= 0) return '';
    final min = diff.inMinutes;
    final sec = diff.inSeconds % 60;
    if (min > 0) return '${min}m ${sec}s';
    return '${sec}s';
  }

  String _statusLabel({required String status, required bool isOutgoing}) {
    switch (status) {
      case CallStatus.accepted:
      case CallStatus.ended:
        return 'Answered';
      case CallStatus.missed:
        return isOutgoing ? 'No answer' : 'Missed';
      case CallStatus.rejected:
        return isOutgoing ? 'Declined' : 'Rejected';
      case CallStatus.cancelled:
        return 'Cancelled';
      case CallStatus.ringing:
        return 'Ringing';
      default:
        return status;
    }
  }
}
