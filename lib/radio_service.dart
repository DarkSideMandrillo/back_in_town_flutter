import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import 'package:audio_session/audio_session.dart';

class RadioMetadata {
  final String title;
  final String artist;
  final String artUrl;

  RadioMetadata({
    required this.title,
    required this.artist,
    required this.artUrl,
  });
}

class RadioService with WidgetsBindingObserver {
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;

  RadioService._internal() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  Timer? _pollingTimer;

  // --- CONFIGURAZIONE ---
  final String _shortcode = "radio_fossano_back_in_town";
  final String _baseUrl = "https://azuracast.backintown.it";

  String get _streamUrl => "$_baseUrl/listen/$_shortcode/radio.mp3";
  String get _apiUrl => "$_baseUrl/api/nowplaying/$_shortcode";

  // Notifiers
  final ValueNotifier<RadioMetadata> metadataNotifier = ValueNotifier(
    RadioMetadata(title: "Back In Town", artist: "Radio Fossano", artUrl: ""),
  );
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  // --- GESTIONE RISVEGLIO ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Appena apri l'app: aggiorna titolo e riparti col controllo
      print("💡 App risvegliata: Aggiorno dati.");
      _fetchMetadata();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      // Schermo spento: stop controlli (risparmio batteria)
      // Nota: La musica continua, e il titolo sulla lockscreen
      // resterà quello dell'ultimo aggiornamento (comportamento standard Android per le web radio)
      print("💤 App in background: Pausa aggiornamento titoli.");
      _stopPolling();
    }
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      isLoadingNotifier.value =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
    });

    // Avvio
    _fetchMetadata();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Controllo ogni 15 secondi quando l'app è aperta
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchMetadata();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchMetadata() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        dynamic songData;
        if (data['now_playing'] != null &&
            data['now_playing']['song'] != null) {
          songData = data['now_playing']['song'];
        }

        if (songData != null) {
          _updateMetadata(songData);
        }
      }
    } catch (e) {
      print("Errore fetch: $e");
    }
  }

  void _updateMetadata(dynamic song) {
    final newMeta = RadioMetadata(
      title: song['title'] ?? "Diretta",
      artist: song['artist'] ?? "Radio Fossano",
      artUrl: song['art'] ?? "",
    );

    if (metadataNotifier.value.title != newMeta.title) {
      metadataNotifier.value = newMeta;
      // Abbiamo aggiornato i dati interni.
      // Al prossimo Play/Pausa o Riconnessione, la notifica prenderà questi dati.
    }
  }

  Future<void> play() async {
    if (_player.playing) return;
    try {
      // ECCO LA MODIFICA: Ora usiamo i dati VERI nei metadati audio
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(_streamUrl),
          tag: MediaItem(
            id: '1',
            album: "Radio Fossano",
            // Qui prendiamo il titolo e l'artista attuali
            title: metadataNotifier.value.title.isNotEmpty
                ? metadataNotifier.value.title
                : "Back In Town",
            artist: metadataNotifier.value.artist.isNotEmpty
                ? metadataNotifier.value.artist
                : "Diretta Radio",
            artUri: metadataNotifier.value.artUrl.isNotEmpty
                ? Uri.parse(metadataNotifier.value.artUrl)
                : null,
          ),
        ),
      );
      _player.play();
    } catch (e) {
      print("Errore Play: $e");
    }
  }

  Future<void> pause() async {
    await _player.stop();
  }
}
