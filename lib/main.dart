import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'radio_service.dart'; // Importa il servizio

void main() {
  // 1. Assicuriamo che il motore di Flutter sia pronto
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Avviamo la connessione SSE e Audio in BACKGROUND.
  // Ho tolto 'await': così l'app si apre ISTANTANEAMENTE senza aspettare la rete.
  RadioService().init();

  runApp(const RadioApp());
}

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BackInTown Radio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.amber, // Colore giallo del tuo logo
        // Aggiungi questo per supportare il Material 3 moderno se vuoi
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
