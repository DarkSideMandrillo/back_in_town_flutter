import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_handler.dart';
import 'metadata_handler.dart';
import '../models/radio_metadata.dart';

/*
 * radio service (orchestratore).
 * gestisce lo stato dell'app e coordina audio e metadati.
 * singleton accessibile da tutta la UI.
 */

class RadioService with WidgetsBindingObserver {
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;

  final AudioPlayerHandler _audio = AudioPlayerHandler();
  late final MetadataHandler _metadata;

  final ValueNotifier<RadioMetadata> metadataNotifier = ValueNotifier(
    RadioMetadata.empty(),
  );
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  RadioService._internal() {
    _metadata = MetadataHandler(
      apiUrl:
          "https://azuracast.backintown.it/api/nowplaying/radio_fossano_back_in_town",
    );
    WidgetsBinding.instance.addObserver(this);
    _listenToPlayer();
  }

  void _listenToPlayer() {
    _audio.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      isLoadingNotifier.value =
          state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gestione polling intelligente per risparmiare batteria/dati
    if (!isPlayingNotifier.value) return;

    if (state == AppLifecycleState.resumed) {
      _metadata.startPolling(const Duration(seconds: 10), _onMetadataUpdate);
    } else if (state == AppLifecycleState.paused) {
      _metadata.startPolling(const Duration(seconds: 30), _onMetadataUpdate);
    }
  }

  void _onMetadataUpdate(RadioMetadata data) {
    // 1. Aggiorna la UI (MiniPlayer, FullPlayer)
    metadataNotifier.value = data;

    // NOTA: Aggiornare la notifica Android su uno stream live attivo
    // senza interrompere l'audio è complesso con just_audio_background
    // su singola URI source. Per ora ci accontentiamo che l'App UI sia corretta.
  }

  Future<void> play() async {
    // Avviamo il player con i metadati che abbiamo ATTUALMENTE (potrebbero essere default)
    const streamUrl =
        "https://azuracast.backintown.it/listen/radio_fossano_back_in_town/radio.mp3";

    await _audio.loadAndPlay(streamUrl, metadataNotifier.value);

    // Facciamo partire subito il polling per prendere titolo/autore reali
    _metadata.startPolling(const Duration(seconds: 10), _onMetadataUpdate);
  }

  Future<void> pause() async {
    await _audio.stop();
    _metadata.stopPolling();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.dispose();
  }
}
