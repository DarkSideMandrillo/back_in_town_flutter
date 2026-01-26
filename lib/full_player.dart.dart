import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Per icona WhatsApp
import 'radio_service.dart';
import 'whatsapp_service.dart'; // Per la logica WhatsApp

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final radioService = RadioService();

    return Container(
      // Occupa il 95% dell'altezza dello schermo
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFF181818), // Sfondo scuro
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      child: Column(
        children: [
          // -----------------------------------------------------
          // 1. MANIGLIA E TASTO CHIUDI
          // -----------------------------------------------------
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 35,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          const Spacer(), // Spinge il contenuto al centro
          // -----------------------------------------------------
          // 2. COPERTINA ALBUM (GRANDE) E DATI
          // -----------------------------------------------------
          ValueListenableBuilder<RadioMetadata>(
            valueListenable: radioService.metadataNotifier,
            builder: (context, metadata, _) {
              return Column(
                children: [
                  // COPERTINA
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: metadata.artUrl.isNotEmpty
                          ? Image.network(
                              metadata.artUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[900],
                                  child: const Icon(
                                    Icons.music_note,
                                    size: 80,
                                    color: Colors.white24,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[900],
                              child: const Icon(
                                Icons.music_note,
                                size: 80,
                                color: Colors.white24,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // TITOLO (Scorrevoli)
                  SizedBox(
                    height: 35,
                    child: AutoScrollingTextFull(
                      text: metadata.title.isNotEmpty
                          ? metadata.title
                          : "Back In Town",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ARTISTA
                  Text(
                    metadata.artist.isNotEmpty
                        ? metadata.artist
                        : "Radio Fossano",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),

          const Spacer(),

          // -----------------------------------------------------
          // 3. CONTROLLI (WhatsApp e Play/Pause)
          // -----------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BOTTONE WHATSAPP
              IconButton(
                iconSize: 40,
                icon: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                ),
                onPressed: () {
                  WhatsAppService.openWhatsApp(context);
                },
              ),

              const SizedBox(width: 40),

              // BOTTONE PLAY/PAUSE (Con Loading)
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white, // Cerchio bianco
                  shape: BoxShape.circle,
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: radioService.isLoadingNotifier,
                  builder: (context, isLoading, _) {
                    if (isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 3,
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
                            size: 50,
                            color: Colors.black, // Icona nera su cerchio bianco
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
              ),

              const SizedBox(width: 40),

              // (Opzionale: Un terzo bottone fantasma per bilanciare il layout se serve,
              // altrimenti puoi lasciarlo vuoto o mettere un pulsante share)
              const SizedBox(width: 40),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- HELPER PER SCROLL (Versione centrata per il Full Player) ---
class AutoScrollingTextFull extends StatelessWidget {
  final String text;
  final TextStyle style;

  const AutoScrollingTextFull({
    super.key,
    required this.text,
    required this.style,
  });

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
            blankSpace: 50.0,
            velocity: 30.0,
            pauseAfterRound: const Duration(seconds: 3),
            startPadding: 0.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.linear,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          );
        } else {
          // Nel Full Player preferiamo il titolo CENTRATO se non scorre
          return Center(
            child: Text(
              text,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }
      },
    );
  }
}
