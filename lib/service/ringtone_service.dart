// ringtone_service.dart
import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class RingtoneService {
  RingtoneService._internal();

  static final RingtoneService _instance = RingtoneService._internal();

  factory RingtoneService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  Timer? _timeoutTimer;
  Timer? _vibrationTimer;
  bool _configured = false;
  bool _isRinging = false;

  Future<void> _configureAudio() async {
    if (_configured) return;

    await _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationRingtone,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
    await _player.setReleaseMode(ReleaseMode.loop);
    _configured = true;
  }

  Future<void> startRinging() async {
    try {
      _isRinging = true;
      await _configureAudio();
      await _player.stop();
      await _player.setSourceAsset('ringtone.mp3');
      await _player.setVolume(1.0);
      await _player.resume();
      _startVibrationLoop();
    } catch (e) {
      log('[RingtoneService] startRinging failed: $e');
    }
  }

  Future<void> stopRinging() async {
    _isRinging = false;
    _vibrationTimer?.cancel();
    await _player.stop();
    _timeoutTimer?.cancel();
  }

  void startAutoTimeout(void Function() onTimeout, Duration duration) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(duration, () {
      onTimeout.call();
    });
  }

  void cancelAutoTimeout() {
    _timeoutTimer?.cancel();
  }

  void _startVibrationLoop() {
    _vibrationTimer?.cancel();
    HapticFeedback.vibrate();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!_isRinging) return;
      HapticFeedback.vibrate();
    });
  }
}
