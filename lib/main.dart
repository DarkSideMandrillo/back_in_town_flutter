import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'ui/home_screen.dart';

/*
 * entry point. bootstrap dell'applicazione.
 * inizializza i binding critici e il servizio audio background (obbligatorio per android).
 * se questo fallisce, l'app parte ma l'audio background sarà instabile.
 */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // init servizio audio background.
    // critico: serve per la notifica android e controlli lockscreen.
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    // se fallisce init audio, logghiamo forte ma proviamo a partire lo stesso.
    print("⚠️ critical audio error: $e");
  }

  runApp(const MyApp());
}

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
