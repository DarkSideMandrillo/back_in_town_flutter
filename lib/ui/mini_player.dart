import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/radio_service.dart';
import '../services/whatsapp_service.dart';
import '../models/radio_metadata.dart';
import '../widgets/scrolling_text.dart';
import 'full_player_screen.dart';

/*
 * widget 'persistent bottom bar'.
 * deve essere leggero. mostra info essenziali e controlli rapidi.
 * funge da trigger per aprire il player a schermo intero.
 */

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final radioService = RadioService();

    return GestureDetector(
      // tap sulla barra apre il player full screen
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
            // --- sezione info (sx) ---
            Expanded(
              child: ValueListenableBuilder<RadioMetadata>(
                valueListenable: radioService.metadataNotifier,
                builder: (context, metadata, _) {
                  return Row(
                    children: [
                      // artwork
                      Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: metadata.artUrl.isNotEmpty
                              ? Image.network(
                                  metadata.artUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.music_note,
                                    color: Colors.white24,
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note,
                                  color: Colors.white24,
                                ),
                        ),
                      ),
                      // testi
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 25,
                              child: ScrollingText(
                                text: metadata.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              metadata.artist,
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

            // --- sezione controlli (dx) ---
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // whatsapp
                IconButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Color(0xFF25D366),
                    size: 32,
                  ),
                  onPressed: () => WhatsAppService.openWhatsApp(context),
                ),
                const SizedBox(width: 8),

                // play/pause con spinner loading
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
                          onPressed: () => isPlaying
                              ? radioService.pause()
                              : radioService.play(),
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
