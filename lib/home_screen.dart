import 'package:back_in_town_flutter/mini_player.dart.dart';
import 'package:flutter/foundation.dart'; // Serve per kDebugMode
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import necessario per le funzioni specifiche Android
import 'package:webview_flutter_android/webview_flutter_android.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WebViewController _webController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // 1. Creiamo i parametri di inizializzazione specifici per la piattaforma
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    // 2. Creiamo il controller con i parametri
    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      // --- FIX ORB ERROR: Impostiamo un User Agent standard da mobile ---
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Inietta il CSS/JS per nascondere il player del sito se necessario
            controller.runJavaScript('''
              var element = document.querySelector('.custom-radio-player');
              if (element) { element.style.display = 'none'; }
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              "Errore WebView: ${error.description}, Code: ${error.errorCode}",
            );
          },
        ),
      )
      ..loadRequest(Uri.parse('https://test.backintown.it/'));

    // 3. Configurazioni specifiche per Android (Debug e Media)
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;

      // Abilita il debug della WebView se siamo in modalità debug (utile per ispezionare da Chrome su PC)
      if (kDebugMode) {
        AndroidWebViewController.enableDebugging(true);
      }

      // Permette la riproduzione media senza gesture (opzionale, ma aiuta con l'audio)
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _webController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _webController),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    ),
                ],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
