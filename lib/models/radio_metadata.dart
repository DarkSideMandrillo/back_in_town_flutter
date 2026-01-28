/*
 * dto puro. definisce la struttura della canzone (titolo, artista, cover).
 * zero logica, solo dati.
 * serve a evitare di passare stringhe sciolte e null sparsi per la ui.
 */
class RadioMetadata {
  final String title;
  final String artist;
  final String artUrl;

  RadioMetadata({
    required this.title,
    required this.artist,
    required this.artUrl,
  });

  // factory per creare oggetto vuoto/default.
  // evita null check sparsi ovunque nella ui.
  factory RadioMetadata.empty() {
    return RadioMetadata(
      title: "Back In Town",
      artist: "Radio Fossano",
      artUrl: "",
    );
  }
}
