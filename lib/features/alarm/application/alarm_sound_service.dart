import 'package:audioplayers/audioplayers.dart';

class AlarmSoundService {
  AlarmSoundService();

  final AudioPlayer _player = AudioPlayer();

  Future<void> play() async {
    // STREAM_ALARM を使うことで、端末の音量ボタンがアラーム音量を直接制御する
    await _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.music,
          stayAwake: true,
        ),
      ),
    );
    await _player.setVolume(1.0);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alarm.mp3'));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}