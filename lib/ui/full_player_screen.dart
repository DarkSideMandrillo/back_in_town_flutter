import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/radio_service.dart';
import '../services/whatsapp_service.dart';
import '../models/radio_metadata.dart';
import '../widgets/scrolling_text.dart';

/*
 * vista modale 'now playing'.
 * focus totale su artwork e leggibilità.
 * simula il comportamento standard dei player ios/android (swipe down per chiudere).
 */

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final radioService = RadioService();

    return Container(
      // copre 95% altezza, simula foglio modale ios
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      child: Column(
        children: [
          // maniglia drag & drop (visiva)
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // tasto chiudi
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

          const Spacer(),

          // --- artwork & meta ---
          ValueListenableBuilder<RadioMetadata>(
            valueListenable: radioService.metadataNotifier,
            builder: (context, metadata, _) {
              return Column(
                children: [
                  // copertina grande
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
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[900],
                                child: const Icon(
                                  Icons.music_note,
                                  size: 80,
                                  color: Colors.white24,
                                ),
                              ),
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

                  // titolo
                  SizedBox(
                    height: 35,
                    child: ScrollingText(
                      text: metadata.title,
                      centerIfStationary:
                          true, // qui vogliamo centrare se il testo è corto
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // artista
                  Text(
                    metadata.artist,
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

          // --- controlli principali ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // whatsapp big
              IconButton(
                iconSize: 40,
                icon: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                ),
                onPressed: () => WhatsAppService.openWhatsApp(context),
              ),

              const SizedBox(width: 40),

              // play big con sfondo bianco
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white,
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
                            color: Colors.black,
                          ),
                          onPressed: () => isPlaying
                              ? radioService.pause()
                              : radioService.play(),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(width: 40),
              // placeholder per simmetria, se serve in futuro
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
