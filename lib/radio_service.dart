import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

class RadioService {
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  http.Client? _client;

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

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      isLoadingNotifier.value =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        print('Errore Stream Audio: $e');
      },
    );

    // 1. Carica SUBITO i dati (per non vedere "In attesa")
    _fetchInitialMetadata();

    // 2. Poi attiva il canale REAL TIME per gli aggiornamenti futuri
    _connectSSE();
  }

  Future<void> play() async {
    if (_player.playing) return;
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(_streamUrl),
          tag: MediaItem(
            id: '1',
            album: "Radio Fossano",
            title: metadataNotifier.value.title,
            artist: metadataNotifier.value.artist,
            artUri: metadataNotifier.value.artUrl.isNotEmpty
                ? Uri.parse(metadataNotifier.value.artUrl)
                : null,
          ),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
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

  // --- 1. CHIAMATA SINGOLA INIZIALE (Per sbloccare "In attesa") ---
  Future<void> _fetchInitialMetadata() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['now_playing'] != null &&
            data['now_playing']['song'] != null) {
          _updateMetadata(data['now_playing']['song']);
        }
      }
    } catch (e) {
      print("Errore fetch iniziale: $e");
    }
  }

  // --- 2. CANALE REAL TIME (SSE) ---
  void _connectSSE() async {
    try {
      final request = http.Request('GET', Uri.parse("$_apiUrl/sse"));
      request.headers['User-Agent'] =
          'Mozilla/5.0'; // Importante per non farsi bloccare

      _client = http.Client();
      final response = await _client!.send(request);

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('data:')) {
                final jsonString = line.substring(5).trim();
                if (jsonString.isNotEmpty) {
                  _parseSSEMessage(jsonString);
                }
              }
            },
            onError: (e) {
              print('SSE Disconnesso, riprovo tra 5s...');
              Future.delayed(const Duration(seconds: 5), _connectSSE);
            },
            onDone: () {
              Future.delayed(const Duration(seconds: 5), _connectSSE);
            },
          );
    } catch (e) {
      print('Errore connessione SSE: $e');
      Future.delayed(const Duration(seconds: 5), _connectSSE);
    }
  }

  void _parseSSEMessage(String jsonString) {
    try {
      final data = json.decode(jsonString);
      dynamic songData;

      // Logica per trovare i dati della canzone dentro la struttura SSE di AzuraCast
      if (data['now_playing'] != null) {
        songData = data['now_playing']['song'];
      } else if (data['pub'] != null && data['pub']['data'] != null) {
        // A volte arrivano dentro 'pub' -> 'data'
        final innerData = data['pub']['data'];
        if (innerData['now_playing'] != null) {
          songData = innerData['now_playing']['song'];
        } else if (innerData['np'] != null) {
          songData = innerData['np']['now_playing']['song'];
        }
      } else if (data['connect'] != null && data['connect']['data'] != null) {
        // Messaggio di prima connessione
        final innerData = data['connect']['data'];
        if (innerData.isNotEmpty && innerData[0]['now_playing'] != null) {
          songData = innerData[0]['now_playing']['song'];
        }
      }

      if (songData != null) {
        _updateMetadata(songData);
      }
    } catch (e) {
      // Ignora errori di parsing su messaggi keep-alive
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
      // Aggiorna notifica se in play
      if (_player.playing && _player.audioSource != null) {
        // Non forziamo il reload per evitare glitch audio,
        // al prossimo play si aggiornerà anche la notifica Android
      }
    }
  }
}
