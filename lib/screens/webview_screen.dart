// ============================================================================
// SCREEN: WebViewScreen
// ============================================================================
// WebView generik yang dipakai ulang untuk berbagai kebutuhan (Tawk.to chat,
// halaman kebijakan/T&C dari web, dll) — terima parameter URL/judul.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            final languageProvider = Provider.of<LanguageProvider>(
              context,
              listen: false,
            );
            final locale = languageProvider.currentLocale;
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    locale.languageCode == 'en'
                        ? 'Error loading page: ${error.description}'
                        : 'Kesalahan memuat halaman: ${error.description}'
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.title,
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: _t('refresh', locale),
                onPressed: () {
                  _controller.reload();
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              WebViewWidget(controller: _controller),
              
              if (_isLoading)
                LinearProgressIndicator(
                  value: _loadingProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}