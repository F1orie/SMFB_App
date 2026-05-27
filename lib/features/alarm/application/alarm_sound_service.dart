import 'package:audioplayers/audioplayers.dart';

class AlarmSoundService {
  AlarmSoundService();

  final AudioPlayer _player = AudioPlayer();

  Future<void> play() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(
      AssetSource('sounds/alarm.mp3'),
    );
  }

  Future<void> stop() async {
    await _player.stop();
  }

  /// アラーム音量を設定する（0.0〜1.0）
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}