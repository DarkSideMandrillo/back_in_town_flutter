import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import 'package:audio_session/audio_session.dart';
import '../models/radio_metadata.dart';

/*
 * core logic dell'audio. singleton.
 * gestisce 3 cose critiche:
 * 1. stream audio (just_audio)
 * 2. recupero metadati (sse realtime in foreground, polling lento in background)
 * 3. gestione stato app (pausa/resume) per risparmiare batteria.
 */

class RadioService with WidgetsBindingObserver {
  // singleton. ne esiste solo uno, accessibile ovunque.
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  // stato connessioni
  http.Client? _sseClient; // canale realtime (costoso)
  StreamSubscription? _sseStream;
  Timer? _backgroundTimer; // polling lento (economico)

  // config endpoint
  final String _shortcode = "radio_fossano_back_in_town";
  final String _baseUrl = "https://azuracast.backintown.it";
  String get _streamUrl => "$_baseUrl/listen/$_shortcode/radio.mp3";
  String get _apiUrl => "$_baseUrl/api/nowplaying/$_shortcode";

  // notifiers per la ui. usiamo valuenotifier per semplicità.
  final ValueNotifier<RadioMetadata> metadataNotifier = ValueNotifier(
    RadioMetadata.empty(),
  );
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  RadioService._internal() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  // hook ciclo di vita app.
  // decide quale strategia di update usare.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // app visibile -> serve reattività massima.
      // spegni timer, accendi socket/sse.
      print("🚀 mode: active. switch to sse.");
      _stopBackgroundTimer();
      _fetchMetadata();
      _connectSSE();
    } else if (state == AppLifecycleState.paused) {
      // app nascosta -> risparmia batteria e banda.
      // spegni sse, accendi polling lento.
      print("🌙 mode: background. switch to polling.");
      _disconnectSSE();
      _startBackgroundTimer();
    }
  }

  Future<void> _init() async {
    // config sessione audio android/ios
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // ascolta stato player
    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      isLoadingNotifier.value =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      // se l'audio muore, uccidiamo anche le connessioni dati.
      // inutile scaricare json se nessuno ascolta.
      if (!state.playing) {
        _disconnectSSE();
        _stopBackgroundTimer();
      } else {
        // se riparte, riaggancia la strategia corretta in base allo stato app.
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.paused) {
          _startBackgroundTimer();
        } else {
          _connectSSE();
        }
      }
    });

    // boot iniziale
    _fetchMetadata();
    _connectSSE();
  }

  // --- strategia 1: sse (real time) ---

  void _connectSSE() async {
    _disconnectSSE(); // pulizia preventiva

    try {
      print("🔗 sse connect...");
      final request = http.Request('GET', Uri.parse("$_apiUrl/sse"));
      request.headers['User-Agent'] =
          'Mozilla/5.0'; // fingiamo di essere un browser

      _sseClient = http.Client();
      final response = await _sseClient!.send(request);

      _sseStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.startsWith('data:')) {
              final jsonString = line.substring(5).trim();
              if (jsonString.isNotEmpty) _parseSSEMessage(jsonString);
            }
          }, onError: (e) => print('sse error: $e'));
    } catch (e) {
      print('sse failed. retry logic pending.');
    }
  }

  void _disconnectSSE() {
    _sseStream?.cancel();
    _sseClient?.close();
    _sseStream = null;
    _sseClient = null;
  }

  void _parseSSEMessage(String jsonString) {
    try {
      final data = json.decode(jsonString);
      dynamic songData;

      // parsing infernale del json di azuracast.
      // la struttura cambia a seconda se è live, playlist o autoodj.
      if (data['now_playing'] != null) {
        songData = data['now_playing']['song'];
      } else if (data['pub'] != null && data['pub']['data'] != null) {
        final inner = data['pub']['data'];
        songData =
            inner['now_playing']?['song'] ??
            inner['np']?['now_playing']?['song'];
      }

      if (songData != null) _updateMetadata(songData);
    } catch (_) {
      // json malformato o inatteso. ignoriamo silenziosamente.
    }
  }

  // --- strategia 2: polling (background) ---

  void _startBackgroundTimer() {
    if (_backgroundTimer != null && _backgroundTimer!.isActive) return;

    print("⏱️ timer start (20s)");
    _fetchMetadata(); // check immediato

    // check ogni 20s. bilanciamento tra freschezza dati e drain batteria.
    _backgroundTimer = Timer.periodic(const Duration(seconds: 20), (t) {
      if (_player.playing) {
        _fetchMetadata();
      } else {
        _stopBackgroundTimer(); // sicurezza: se non suona, non polla.
      }
    });
  }

  void _stopBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  // --- helper condivisi ---

  Future<void> _fetchMetadata() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['now_playing']?['song'] != null) {
          _updateMetadata(data['now_playing']['song']);
        }
      }
    } catch (e) {
      print("fetch error: $e");
    }
  }

  void _updateMetadata(dynamic song) {
    final newMeta = RadioMetadata(
      title: song['title'] ?? "Diretta",
      artist: song['artist'] ?? "Radio Fossano",
      artUrl: song['art'] ?? "",
    );

    // aggiorna solo se cambiato. evita rebuild inutili della ui.
    if (metadataNotifier.value.title != newMeta.title) {
      print("🎵 new track: ${newMeta.title}");
      metadataNotifier.value = newMeta;

      // nota: su android l'aggiornamento lockscreen senza stop/start
      // dello stream è instabile. per ora ci accontentiamo dell'aggiornamento in-app.
    }
  }

  // --- controlli player ---

  Future<void> play() async {
    if (_player.playing) return;
    try {
      // setup sorgente audio con metadati per notifica sistema
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(_streamUrl),
          tag: MediaItem(
            id: '1',
            album: "Radio Fossano",
            title: metadataNotifier.value.title,
            artist: metadataNotifier.value.artist,
            artUri: Uri.tryParse(metadataNotifier.value.artUrl),
          ),
        ),
      );
      _player.play();
      _connectSSE(); // assume foreground al play
    } catch (e) {
      print("play error: $e");
    }
  }

  Future<void> pause() async {
    await _player.stop();
    _disconnectSSE();
    _stopBackgroundTimer();
  }
}
