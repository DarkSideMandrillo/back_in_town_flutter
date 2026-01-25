import 'package:back_in_town_flutter/full_player.dart.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'radio_service.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final radioService = RadioService();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const FullPlayerScreen(),
        );
      },
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: const Border(top: BorderSide(color: Colors.white12)),
        ),
        child: ValueListenableBuilder<RadioMetadata>(
          valueListenable: radioService.metadataNotifier,
          builder: (context, metadata, _) {
            // Definiamo lo stile del titolo una volta sola per coerenza
            const titleStyle = TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            );

            final titleText = metadata.title.isNotEmpty
                ? metadata.title
                : "Back In Town...";

            return Row(
              children: [
                // 1. IMMAGINE
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: metadata.artUrl.isNotEmpty
                        ? Image.network(metadata.artUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note),
                          ),
                  ),
                ),

                const SizedBox(width: 12),

                // 2. TESTI (Con logica intelligente per lo scroll)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- INIZIO LOGICA SCROLL INTELLIGENTE ---
                      SizedBox(
                        height: 25,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // 1. Misuriamo quanto sarebbe lungo il testo
                            final textSpan = TextSpan(
                              text: titleText,
                              style: titleStyle,
                            );
                            final textPainter = TextPainter(
                              text: textSpan,
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                            );
                            textPainter.layout();

                            // 2. Controlliamo se supera la larghezza disponibile
                            if (textPainter.width > constraints.maxWidth) {
                              // CASO A: Il testo è troppo lungo -> SCORRE
                              return Marquee(
                                text: titleText,
                                style: titleStyle,
                                scrollAxis: Axis.horizontal,
                                blankSpace: 30.0,
                                velocity: 30.0,
                                pauseAfterRound: const Duration(seconds: 2),
                                startPadding: 0.0,
                                accelerationDuration: const Duration(
                                  seconds: 1,
                                ),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(
                                  milliseconds: 500,
                                ),
                                decelerationCurve: Curves.easeOut,
                              );
                            } else {
                              // CASO B: Il testo ci sta -> FERMO
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  titleText,
                                  style: titleStyle,
                                  maxLines: 1,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      // --- FINE LOGICA SCROLL ---

                      // Artista
                      Text(
                        metadata.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. CONTROLLI
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.green,
                      ),
                      onPressed: () {},
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: radioService.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return IconButton(
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              radioService.pause();
                            } else {
                              radioService.play();
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
