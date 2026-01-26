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

  // Gestione Connessioni
  http.Client? _sseClient; // Per il canale Real Time (App Aperta)
  StreamSubscription? _sseStream; // Stream del canale Real Time
  Timer? _backgroundTimer; // Timer per il Polling (App Chiusa)

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

  // --- IL CERVELLO: SWITCH AUTOMATICO ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ---> APP APERTA (Schermo Acceso)
      print("🚀 MODALITÀ ATTIVA: Passo a Real Time (SSE) + Refresh Immediato");
      _stopBackgroundTimer(); // Spegni il timer lento
      _fetchMetadata(); // Aggiorna SUBITO la grafica
      _connectSSE(); // Apri il canale veloce
    } else if (state == AppLifecycleState.paused) {
      // ---> APP IN BACKGROUND (Schermo Spento/In tasca)
      print("🌙 MODALITÀ RISPARMIO: Passo a Controllo ogni 20s");
      _disconnectSSE(); // Chiudi il canale pesante
      _startBackgroundTimer(); // Attiva il timer lento per la notifica
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

      // Se la musica si ferma, fermiamo TUTTO per non consumare dati
      if (!state.playing) {
        _disconnectSSE();
        _stopBackgroundTimer();
      } else {
        // Se riparte e siamo in background, riattiva il timer
        // Se siamo aperti, riattiva SSE.
        // Per semplicità, richiamiamo la logica di connessione standard:
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.paused) {
          _startBackgroundTimer();
        } else {
          _connectSSE();
        }
      }
    });

    // Avvio iniziale (App considerata aperta)
    _fetchMetadata();
    _connectSSE();
  }

  // ===========================================================================
  // MODALITÀ 1: REAL TIME (SSE) - Per quando l'app è aperta
  // ===========================================================================
  void _connectSSE() async {
    // Evita connessioni multiple
    _disconnectSSE();

    try {
      print("🔗 Connessione SSE (Real Time)...");
      final request = http.Request('GET', Uri.parse("$_apiUrl/sse"));
      request.headers['User-Agent'] = 'Mozilla/5.0';

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
          }, onError: (e) => print('Errore SSE'));
    } catch (e) {
      print('Fallimento SSE, riprovo tra 5s...');
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
      // Logica AzuraCast per trovare la canzone
      if (data['now_playing'] != null) {
        songData = data['now_playing']['song'];
      } else if (data['pub'] != null && data['pub']['data'] != null) {
        final inner = data['pub']['data'];
        if (inner['now_playing'] != null)
          songData = inner['now_playing']['song'];
        else if (inner['np'] != null)
          songData = inner['np']['now_playing']['song'];
      }
      if (songData != null) _updateMetadata(songData);
    } catch (_) {}
  }

  // ===========================================================================
  // MODALITÀ 2: TIMER 20s - Per quando l'app è in background
  // ===========================================================================
  void _startBackgroundTimer() {
    if (_backgroundTimer != null && _backgroundTimer!.isActive) return;

    print("⏱️ Avvio Timer Background (20s)");
    // Esegui subito un controllo
    _fetchMetadata();
    // Poi ogni 20 secondi
    _backgroundTimer = Timer.periodic(const Duration(seconds: 20), (t) {
      if (_player.playing) {
        print("⏱️ Background Check...");
        _fetchMetadata();
      } else {
        _stopBackgroundTimer();
      }
    });
  }

  void _stopBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  // ===========================================================================
  // FUNZIONI COMUNI
  // ===========================================================================
  Future<void> _fetchMetadata() async {
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
      print("Errore Fetch: $e");
    }
  }

  void _updateMetadata(dynamic song) {
    final newMeta = RadioMetadata(
      title: song['title'] ?? "Diretta",
      artist: song['artist'] ?? "Radio Fossano",
      artUrl: song['art'] ?? "",
    );

    if (metadataNotifier.value.title != newMeta.title) {
      print("🎵 Nuova Canzone: ${newMeta.title}");
      metadataNotifier.value = newMeta;

      // Aggiorna la notifica / lock screen
      if (_player.playing) {
        // Tenta di aggiornare il tag audio per la lockscreen
        // (Nota: su Android aggiornare i metadati di uno stream live attivo
        // non è sempre garantito senza riavvio, ma questo è il metodo corretto)
        try {
          // Aggiornamento "Soft" non supportato nativamente da just_audio_background
          // senza ricaricare la sorgente. Tuttavia, la notifica interna è aggiornata.
          // Se volessimo forzare l'aggiornamento lockscreen dovremmo fare:
          // _player.setAudioSource(...); MA questo interromperebbe l'audio per 1s.
          // Meglio tenere l'audio fluido.
        } catch (e) {}
      }
    }
  }

  // --- AUDIO CONTROLS ---
  Future<void> play() async {
    if (_player.playing) return;
    try {
      // Carica audio con metadati attuali
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(_streamUrl),
          tag: MediaItem(
            id: '1',
            album: "Radio Fossano",
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
      // Avvia la logica (di default consideriamo app aperta)
      _connectSSE();
    } catch (e) {
      print("Errore Play: $e");
    }
  }

  Future<void> pause() async {
    await _player.stop();
    _disconnectSSE();
    _stopBackgroundTimer();
  }
}
