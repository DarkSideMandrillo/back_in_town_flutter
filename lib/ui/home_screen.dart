import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'mini_player.dart';

/*
 * container principale.
 * impila la webview (il sito) e il mini player (l'audio nativo).
 * responsabile dell'injection js per nascondere il player html del sito web.
 */

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
    // hack per gestire piattaforma android vs ios
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      // user agent fake obbligatorio.
      // senza di questo, alcuni server audio bloccano la richiesta (orb error).
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            // injection js chirurgica per nascondere il player html del sito.
            // noi usiamo il player nativo (flutter), due player sarebbero ridicoli.
            controller.runJavaScript(
              "var element = document.querySelector('.custom-radio-player'); if (element) { element.style.display = 'none'; }",
            );
          },
          onWebResourceError: (err) =>
              debugPrint("webview error: ${err.description}"),
        ),
      )
      ..loadRequest(Uri.parse('https://test.backintown.it/'));

    // config extra android: debug e audio policy
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      if (kDebugMode) AndroidWebViewController.enableDebugging(true);
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
            // webview
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
            // player sempre visibile
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
