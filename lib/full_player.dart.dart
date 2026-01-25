import 'package:flutter/material.dart';
import 'radio_service.dart'; // Importante per i dati

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final radioService = RadioService();

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      // Ascoltiamo i Metadati anche qui
      child: ValueListenableBuilder<RadioMetadata>(
        valueListenable: radioService.metadataNotifier,
        builder: (context, metadata, _) {
          return Column(
            children: [
              // Maniglia
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Chiudi
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // 1. IMMAGINE GRANDE RESPONSIVE
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: DecorationImage(
                          image: metadata.artUrl.isNotEmpty
                              ? NetworkImage(metadata.artUrl)
                              : const NetworkImage(
                                  'https://via.placeholder.com/600',
                                ), // Fallback
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. INFO BRANO
              Column(
                children: [
                  Text(
                    metadata.title,
                    textAlign: TextAlign.center,
                    // Aggiungi questi due parametri per sicurezza:
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis, // Mette "..." se è troppo lungo
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metadata.artist,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.white60),
                  ),
                ],
              ),

              const Spacer(),

              // 3. CONTROLLI PLAY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 28),
                    onPressed: () {},
                  ),

                  // Bottone Play Centrale
                  Container(
                    height: 70,
                    width: 70,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: radioService.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return IconButton(
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 45,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            if (isPlaying)
                              radioService.pause();
                            else
                              radioService.play();
                          },
                        );
                      },
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble,
                      size: 30,
                      color: Colors.green,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
