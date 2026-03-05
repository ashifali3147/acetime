// ringtone_service.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class RingtoneService {
  RingtoneService._internal();

  static final RingtoneService _instance = RingtoneService._internal();

  factory RingtoneService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  Timer? _timeoutTimer;

  Future<void> startRinging() async {
    try {
      // ensure you added /assets/ringtone.mp3 to pubspec
      await _player.setSourceAsset('assets/ringtone.mp3');
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.resume();
    } catch (e) {
      // fallback: system sound or ignore
    }
  }

  Future<void> stopRinging() async {
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
}
