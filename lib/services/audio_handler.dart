import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/radio_metadata.dart';

/*
 * low-level audio handler.
 */
class AudioPlayerHandler {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool get isPlaying => _player.playing;

  Future<void> loadAndPlay(String url, RadioMetadata metadata) async {
    try {
      // Creiamo la sorgente audio con i tag iniziali
      final source = AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(
          id: 'radio_fossano_live',
          album: "Radio Fossano",
          title: metadata.title,
          artist: metadata.artist,
          artUri: metadata.artUrl.isNotEmpty
              ? Uri.tryParse(metadata.artUrl)
              : null,
        ),
      );

      await _player.setAudioSource(source);
      _player.play();
    } catch (e) {
      print("Audio load error: $e");
    }
  }

  Future<void> stop() async => await _player.stop();
  void dispose() => _player.dispose();
}
