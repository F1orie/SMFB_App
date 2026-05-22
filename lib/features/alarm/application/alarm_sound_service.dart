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

  Future<void> dispose() async {
    await _player.dispose();
  }
}