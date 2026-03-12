import 'package:acetime/model/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallStatus {
  static const String ringing = 'ringing';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String missed = 'missed';
  static const String cancelled = 'cancelled';
  static const String ended = 'ended';
}

class CallService {
  CallService._internal();

  static final CallService _instance = CallService._internal();

  factory CallService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _callRef(String callId) {
    return _firestore.collection('calls').doc(callId);
  }

  Future<void> createOutgoingCall({
    required String callId,
    required UserModel caller,
    required UserModel receiver,
  }) async {
    await _callRef(callId).set({
      'callId': callId,
      'meetingId': callId,
      'status': CallStatus.ringing,
      'callerId': caller.uid,
      'callerName': caller.userName,
      'receiverId': receiver.uid,
      'receiverName': receiver.userName,
      'participants': [caller.uid, receiver.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCall(String callId) {
    return _callRef(callId).snapshots();
  }

  Future<void> updateStatus({
    required String callId,
    required String status,
    String? actorId,
    String? reason,
  }) async {
    await _callRef(callId).set({
      'status': status,
      'actorId': actorId ?? FirebaseAuth.instance.currentUser?.uid,
      if (reason != null) 'reason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == CallStatus.accepted)
        'acceptedAt': FieldValue.serverTimestamp(),
      if (status == CallStatus.ended) 'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAccepted(String callId, {String? actorId}) async {
    await updateStatus(
      callId: callId,
      status: CallStatus.accepted,
      actorId: actorId,
    );
  }

  Future<bool> markAcceptedIfStillRinging(
    String callId, {
    String? actorId,
  }) async {
    var accepted = false;

    await _firestore.runTransaction((transaction) async {
      final ref = _callRef(callId);
      final snap = await transaction.get(ref);
      if (!snap.exists) return;

      final currentStatus = snap.data()?['status'] as String?;
      if (currentStatus != CallStatus.ringing) return;

      transaction.set(ref, {
        'status': CallStatus.accepted,
        'actorId': actorId ?? FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      accepted = true;
    });

    return accepted;
  }

  Future<void> markRejected(String callId, {String? actorId}) async {
    await updateStatus(
      callId: callId,
      status: CallStatus.rejected,
      actorId: actorId,
    );
  }

  Future<void> markCancelled(String callId, {String? actorId}) async {
    await updateStatus(
      callId: callId,
      status: CallStatus.cancelled,
      actorId: actorId,
    );
  }

  Future<void> markEnded(String callId, {String? actorId}) async {
    await updateStatus(
      callId: callId,
      status: CallStatus.ended,
      actorId: actorId,
    );
  }

  Future<void> markMissedIfStillRinging(
    String callId, {
    String? actorId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final ref = _callRef(callId);
      final snap = await transaction.get(ref);
      if (!snap.exists) return;

      final currentStatus = snap.data()?['status'] as String?;
      if (currentStatus != CallStatus.ringing) return;

      transaction.set(ref, {
        'status': CallStatus.missed,
        'actorId': actorId ?? FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
