import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/radio_metadata.dart';

/*
 * api fetcher & polling logic.
 * recupera i metadati da azuracast.
 */
class MetadataHandler {
  final String apiUrl;
  Timer? _timer;

  MetadataHandler({required this.apiUrl});

  void startPolling(Duration interval, Function(RadioMetadata) onUpdate) {
    _timer?.cancel();
    // Eseguiamo subito una fetch iniziale
    _fetch(onUpdate);
    _timer = Timer.periodic(interval, (_) => _fetch(onUpdate));
  }

  void stopPolling() => _timer?.cancel();

  Future<void> _fetch(Function(RadioMetadata) onUpdate) async {
    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        Map<String, dynamic>? songData;

        // Azuracast può restituire una Lista (se endpoint globale) o una Map (se endpoint stazione)
        if (data is List && data.isNotEmpty) {
          songData = data[0]['now_playing']['song'];
        } else if (data is Map<String, dynamic>) {
          songData = data['now_playing']?['song'];
        }

        if (songData != null) {
          String artUrl = songData['art'] ?? "";

          // Fix URL relativo
          if (artUrl.isNotEmpty && !artUrl.startsWith('http')) {
            artUrl = "https://azuracast.backintown.it$artUrl";
          }

          final newMeta = RadioMetadata(
            title: songData['title'] ?? "Back In Town",
            artist: songData['artist'] ?? "Radio Fossano",
            artUrl: artUrl,
          );

          onUpdate(newMeta);
        }
      } else {
        print("⚠️ API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Metadata fetch error: $e");
    }
  }
}
