import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart'; // <--- IMPORTANTE
import 'home_screen.dart';

// Future<void> main() async {
//   // Assicura che i collegamenti nativi siano pronti
//   WidgetsFlutterBinding.ensureInitialized();

//   // --- INIZIALIZZA IL SERVIZIO DI BACKGROUND ---
//   await JustAudioBackground.init(
//     androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
//     androidNotificationChannelName: 'Audio playback',
//     androidNotificationOngoing: true,
//   );
// --------------------------------------------

//   runApp(const MyApp());
// }

// ---------------------- FIX
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Proviamo a inizializzare l'audio
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    // Se fallisce, stampiamo l'errore ma NON blocchiamo l'app
    print("⚠️ ERRORE CRITICO AUDIO: $e");
  }

  runApp(const MyApp());
}
// ---------------------- FINE FIX

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Back In Town',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
