import 'package:flutter/material.dart';
import 'package:back_in_town_flutter/mini_player.dart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea impedisce che l'app finisca sotto la 'tacca' o la barra di stato
      body: SafeArea(
        child: Column(
          children: [
            // --- PARTE SUPERIORE: SITO WEB / IMMAGINE ---
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.grey[900],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.web_asset, size: 60, color: Colors.white24),
                      SizedBox(height: 10),
                      Text(
                        "Area Sito Web",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- PARTE INFERIORE: MINI PLAYER ---
            // È separato in un altro file per pulizia
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
