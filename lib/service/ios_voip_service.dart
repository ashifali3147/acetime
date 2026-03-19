import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/storage_helper.dart';
import 'firestore_service.dart';

class IOSVoipEvent {
  IOSVoipEvent({required this.method, required this.payload});

  final String method;
  final Map<String, dynamic> payload;
}

class IOSVoipService {
  IOSVoipService._internal();

  static final IOSVoipService _instance = IOSVoipService._internal();

  factory IOSVoipService() => _instance;

  static const MethodChannel _channel = MethodChannel('acetime/voip');
  final StreamController<IOSVoipEvent> _events =
      StreamController<IOSVoipEvent>.broadcast();
  bool _initialized = false;

  Stream<IOSVoipEvent> get events => _events.stream;

  Future<void> initialize() async {
    if (!Platform.isIOS || _initialized) return;

    _channel.setMethodCallHandler(_handleNativeCall);
    _initialized = true;

    try {
      await _channel.invokeMethod<void>('register');
      final token = await _channel.invokeMethod<String>('getVoipToken');
      if (token != null && token.isNotEmpty) {
        await _persistVoipToken(token);
      }
    } catch (e) {
      log('[IOSVoipService] Failed to initialize: $e');
    }
  }

  Future<void> endCall(String? callId) async {
    if (!Platform.isIOS || callId == null || callId.isEmpty) return;

    try {
      await _channel.invokeMethod<void>('endCall', {'callId': callId});
    } catch (e) {
      log('[IOSVoipService] Failed to end CallKit call: $e');
    }
  }

  Future<void> setCallConnected(String? callId) async {
    if (!Platform.isIOS || callId == null || callId.isEmpty) return;

    try {
      await _channel.invokeMethod<void>('setCallConnected', {'callId': callId});
    } catch (e) {
      log('[IOSVoipService] Failed to mark CallKit call connected: $e');
    }
  }

  Future<void> _persistVoipToken(String token) async {
    StorageHelper().setVoipToken(token);
    StorageHelper().updateCachedUserTokens(voipToken: token);
    await FirestoreService().updateVoipToken(voipToken: token);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'voipTokenUpdated':
        final token = call.arguments?.toString();
        if (token != null && token.isNotEmpty) {
          await _persistVoipToken(token);
        }
        return null;
      case 'incomingCall':
        if (call.arguments is Map) {
          _events.add(
            IOSVoipEvent(
              method: call.method,
              payload: Map<String, dynamic>.from(
                call.arguments as Map<dynamic, dynamic>,
              ),
            ),
          );
        }
        return null;
      case 'callAccepted':
        if (call.arguments is Map) {
          _events.add(
            IOSVoipEvent(
              method: call.method,
              payload: Map<String, dynamic>.from(
                call.arguments as Map<dynamic, dynamic>,
              ),
            ),
          );
        }
        return null;
      case 'callDeclined':
        if (call.arguments is Map) {
          _events.add(
            IOSVoipEvent(
              method: call.method,
              payload: Map<String, dynamic>.from(
                call.arguments as Map<dynamic, dynamic>,
              ),
            ),
          );
        }
        return null;
      case 'callEnded':
        if (call.arguments is Map) {
          _events.add(
            IOSVoipEvent(
              method: call.method,
              payload: Map<String, dynamic>.from(
                call.arguments as Map<dynamic, dynamic>,
              ),
            ),
          );
        }
        return null;
      default:
        return null;
    }
  }
}
