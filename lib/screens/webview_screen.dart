import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'webview_screen.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  final String url = 'https://www.appsheet.com/start/e95d2220-9727-4cac-b4c6-1fa0c4cd116c';
  final String viewID = 'appsheet-web-view';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      try {
        ui.platformViewRegistry.registerViewFactory(
          viewID,
          (int viewId) => html.IFrameElement()
            ..src = url
            ..style.border = 'none'
            ..style.height = '100%'
            ..style.width = '100%'
            ..style.overflow = 'hidden'
            ..allowFullscreen = true,
        );
      } catch (e) {
        print('View factory already registered: $e');
      }
    } else {
      controller = WebViewController()
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = true;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              print('WebView error: ${error.description}');
            },
          ),
        )
        ..enableZoom(true)
        ..loadRequest(
          Uri.parse(url),
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          }
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Stack(
        children: [
          if (kIsWeb)
            SizedBox.expand(
              child: HtmlElementView(
                viewType: viewID,
              ),
            )
          else
            WebViewWidget(controller: controller),
          if (isLoading && !kIsWeb)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}