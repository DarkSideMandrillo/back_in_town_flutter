import 'package:back_in_town_flutter/full_player.dart.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Importa le icone
import 'radio_service.dart';
import 'whatsapp_service.dart'; // Importa il servizio WhatsApp

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        ),
        child: Row(
          children: [
            // 1. INFO CANZONE E IMMAGINE
            Expanded(
              child: ValueListenableBuilder<RadioMetadata>(
                valueListenable: radioService.metadataNotifier,
                builder: (context, metadata, _) {
                  return Row(
                    children: [
                      // Immagine Album
                      Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: metadata.artUrl.isNotEmpty
                              ? Image.network(
                                  metadata.artUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.music_note,
                                      color: Colors.white24,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.music_note,
                                  color: Colors.white24,
                                ),
                        ),
                      ),

                      // Testi
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 25,
                              child: AutoScrollingText(
                                text: metadata.title.isNotEmpty
                                    ? metadata.title
                                    : "Back In Town",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              metadata.artist.isNotEmpty
                                  ? metadata.artist
                                  : "Radio Fossano",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 2. PULSANTI (WhatsApp + Play/Pause)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- BOTTONE WHATSAPP ---
                IconButton(
                  // Icona ufficiale WhatsApp
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Color(0xFF25D366), // Verde ufficiale WhatsApp
                    size: 32,
                  ),
                  onPressed: () {
                    WhatsAppService.openWhatsApp(context);
                  },
                ),

                const SizedBox(width: 8), // Spazio tra i bottoni
                // Bottone Play/Pause
                ValueListenableBuilder<bool>(
                  valueListenable: radioService.isLoadingNotifier,
                  builder: (context, isLoading, _) {
                    if (isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.amber,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    return ValueListenableBuilder<bool>(
                      valueListenable: radioService.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return IconButton(
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 40,
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
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget Scroll (invariato)
class AutoScrollingText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const AutoScrollingText({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: text, style: style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        if (textPainter.width > constraints.maxWidth) {
          return Marquee(
            text: text,
            style: style,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            blankSpace: 30.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 3),
            startPadding: 0.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.linear,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          );
        } else {
          return Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
      },
    );
  }
}
