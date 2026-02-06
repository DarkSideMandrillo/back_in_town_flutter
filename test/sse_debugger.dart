import 'dart:async';
import 'dart:convert';
import 'dart:io';

// CONFIGURAZIONE - Modifica qui se necessario
const String baseUrl = "https://azuracast.backintown.it";
const String shortcode = "radio_fossano_back_in_town";
const String ssePath = "/api/nowplaying/$shortcode/sse";

void main() async {
  print("🚀 Avvio Debugger SSE per AzuraCast");
  print("🔗 Target: $baseUrl$ssePath");
  print("--------------------------------------------------\n");

  final client = HttpClient();

  // Riduciamo il timeout per il test iniziale
  client.connectionTimeout = const Duration(seconds: 10);

  try {
    print("⏳ [1/4] Apertura connessione HTTP...");
    final request = await client.getUrl(Uri.parse("$baseUrl$ssePath"));

    // Configurazione Header "robusti"
    print("📤 [2/4] Invio Header...");
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.headers.set(
      'X-Requested-With',
      'XMLHttpRequest',
    ); // A volte bypassa filtri
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Dart Debugger)',
    );

    final response = await request.close();

    print("📥 [3/4] Risposta ricevuta!");
    print("   👉 Status Code: ${response.statusCode}");
    print("   👉 Content Type: ${response.headers.contentType}");

    // Log di tutti gli header ricevuti (utile per vedere se c'è un proxy di mezzo)
    print("\n--- Header del Server ---");
    response.headers.forEach((name, values) {
      print("   $name: ${values.join(', ')}");
    });
    print("-------------------------\n");

    if (response.statusCode != 200) {
      print("❌ ERRORE: Il server non ha accettato la connessione SSE.");
      if (response.statusCode == 405) {
        print(
          "💡 Suggerimento: Errore 405 (Method Not Allowed). AzuraCast SSE richiede GET. Verifica che non ci siano redirect forzati.",
        );
      }
      return;
    }

    print("📡 [4/4] Ascolto stream in corso... (Premi CTRL+C per fermare)");

    // Leggiamo lo stream riga per riga
    response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.trim().isEmpty) {
              print("⏱️  [Keep-alive] Ricevuta riga vuota");
            } else if (line.startsWith('data:')) {
              print("🎵 [Dati Ricevuti]: ${line.substring(5).trim()}");
              // Proviamo a fare il parse per vedere se il JSON è corretto
              try {
                final rawJson = line.substring(5).trim();
                if (rawJson != ":ok") {
                  json.decode(rawJson);
                  print("✅ JSON Valido!");
                }
              } catch (e) {
                print("⚠️ Errore Parsing JSON: $e");
              }
            } else {
              print("📩 [Messaggio]: $line");
            }
          },
          onError: (error) {
            print("\n❌ Errore durante lo streaming: $error");
          },
          onDone: () {
            print("\n🏁 Lo stream è stato chiuso dal server.");
          },
          cancelOnError: false,
        );
  } catch (e) {
    print("\n❌ ERRORE CRITICO DI CONNESSIONE:");
    if (e is SocketException) {
      print("   Host non raggiungibile o DNS errato: ${e.message}");
    } else if (e is HandshakeException) {
      print("   Errore SSL/Certificato: ${e.message}");
    } else {
      print("   $e");
    }
  }
}
