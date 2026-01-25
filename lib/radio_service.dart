import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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

class RadioService {
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal();

  final AudioPlayer _player = AudioPlayer();
  http.Client? _client; // Client HTTP persistente per lo stream SSE

  // Parametri di riconnessione
  bool _isRetrying = false;

  // --- CONFIGURAZIONE ---
  final String _shortcode = "radio_fossano_back_in_town";
  final String _baseUrl = "https://azuracast.backintown.it";

  // URL Stream Audio
  String get _streamUrl => "$_baseUrl/listen/$_shortcode/radio.mp3";

  // URL API Standard (per il primo caricamento rapido)
  String get _apiUrl => "$_baseUrl/api/nowplaying/$_shortcode";

  // --- NOTIFIERS ---
  final ValueNotifier<RadioMetadata> metadataNotifier = ValueNotifier(
    RadioMetadata(title: "In attesa...", artist: "Connessione...", artUrl: ""),
  );

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier(false);

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          _player.setVolume(0.5);
        } else {
          _player.pause();
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            _player.play();
            break;
          default:
            break;
        }
      }
    });

    // 1. Carichiamo subito i dati via API standard (per non lasciare l'utente a vuoto)
    _fetchInitialData();

    // 2. Avviamo la connessione "Live" (SSE)
    _connectSSE();

    // 3. Setup Audio
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(_streamUrl)),
        preload: false,
      );
    } catch (e) {
      print("Errore Audio Init: $e");
    }

    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _reloadStream();
      }
    });

    _player.processingStateStream.listen((state) {
      isBufferingNotifier.value =
          (state == ProcessingState.buffering ||
          state == ProcessingState.loading);
    });
  }

  // --- 1. PRIMO CARICAMENTO CLASSICO ---
  Future<void> _fetchInitialData() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['now_playing'] != null) {
          _updateMetadata(data['now_playing']['song']);
        }
      }
    } catch (e) {
      print("Errore fetch iniziale: $e");
    }
  }

  // --- 2. CONNESSIONE SSE (IL "WEBSOCKET" DI AZURACAST) ---
  void _connectSSE() async {
    _client?.close();
    _client = http.Client();
    _isRetrying = false;

    try {
      // Costruiamo l'URL SSE esattamente come fa il browser
      // La "magia" è nel parametro cf_connect che contiene la sottoscrizione
      final sseUri = Uri.parse("$_baseUrl/api/live/nowplaying/sse").replace(
        queryParameters: {
          "cf_connect": jsonEncode({
            "subs": {
              "station:$_shortcode": {},
              "global": {}, // A volte serve anche questo
            },
          }),
        },
      );

      print("📡 Connessione SSE a: $sseUri");

      final request = http.Request('GET', sseUri);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);

      print("✅ SSE Connesso! Status: ${response.statusCode}");

      // Ascoltiamo lo stream di dati riga per riga
      response.stream
          .toStringStream()
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith("data:")) {
                // Abbiamo ricevuto un dato!
                final jsonString = line
                    .substring(5)
                    .trim(); // Rimuoviamo "data:"
                if (jsonString.isNotEmpty) {
                  _parseSSEMessage(jsonString);
                }
              }
            },
            onError: (e) {
              print("❌ Errore stream SSE: $e");
              _scheduleReconnect();
            },
            onDone: () {
              print("⚠️ Stream SSE chiuso dal server");
              _scheduleReconnect();
            },
          );
    } catch (e) {
      print("❌ Errore connessione SSE: $e");
      _scheduleReconnect();
    }
  }

  void _parseSSEMessage(String jsonString) {
    try {
      final data = json.decode(jsonString);

      // SSE di AzuraCast manda un oggetto con "pub" -> "data" -> "np"
      // Oppure direttamente l'oggetto a seconda della versione.
      // Cerchiamo i dati in modo ricorsivo sicuro.

      dynamic songData;

      // Caso 1: Aggiornamento diretto stazione
      if (data['now_playing'] != null) {
        songData = data['now_playing']['song'];
      }
      // Caso 2: Aggiornamento incapsulato (pub/sub)
      else if (data['pub'] != null && data['pub']['data'] != null) {
        final innerData = data['pub']['data'];
        if (innerData['now_playing'] != null) {
          songData = innerData['now_playing']['song'];
        } else if (innerData['np'] != null) {
          songData = innerData['np']['now_playing']['song'];
        }
      }

      if (songData != null) {
        _updateMetadata(songData);
      }
    } catch (e) {
      // Ignoriamo errori di parsing su messaggi di keep-alive
    }
  }

  void _updateMetadata(dynamic song) {
    final newMeta = RadioMetadata(
      title: song['title'] ?? "Diretta",
      artist: song['artist'] ?? "Back In Town",
      artUrl: song['art'] ?? "",
    );

    // Aggiorna solo se cambiato
    if (metadataNotifier.value.title != newMeta.title) {
      metadataNotifier.value = newMeta;
      print("🎵 NUOVO TITOLO (LIVE): ${newMeta.title}");
    }
  }

  void _scheduleReconnect() {
    if (_isRetrying) return;
    _isRetrying = true;
    print("🔄 Riconnessione Live tra 5 secondi...");
    Future.delayed(const Duration(seconds: 5), () {
      _connectSSE();
    });
  }

  // --- AUDIO CONTROLS ---
  Future<void> play() async {
    if (_player.audioSource == null) {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(_streamUrl)));
    }
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> _reloadStream() async {
    await _player.stop();
    await _player.setAudioSource(AudioSource.uri(Uri.parse(_streamUrl)));
    await _player.play();
  }

  void dispose() {
    _client?.close();
    _player.dispose();
  }
}
