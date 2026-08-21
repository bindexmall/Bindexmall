// ============================================================================
// SCREEN: LiveStreamScreen
// ============================================================================
// UI untuk menonton live streaming/live shopping (memakai LiveSettingsProvider).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class LiveStreamScreen extends StatefulWidget {
  final String liveType;
  final String embedUrl;

  const LiveStreamScreen({
    super.key,
    required this.liveType,
    required this.embedUrl,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    if (widget.liveType == 'tiktok') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInExternalApp();
      });
    } else {
      _initializeWebView();
    }
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  String _getEnhancedYouTubeUrl(String url) {
    String videoId = '';
    
    if (url.contains('/embed/')) {
      videoId = url.split('/embed/')[1].split('?')[0];
    } else if (url.contains('watch?v=')) {
      videoId = url.split('watch?v=')[1].split('&')[0];
    } else if (url.contains('youtu.be/')) {
      videoId = url.split('youtu.be/')[1].split('?')[0];
    }
    
    if (videoId.isEmpty) {
      return url;
    }
    
    final enhancedUrl = 'https://www.youtube.com/embed/$videoId'
        '?autoplay=1'
        '&controls=1'
        '&modestbranding=1'
        '&rel=0'
        '&playsinline=1'
        '&enablejsapi=1'
        '&origin=https://bindexmall.com';
    
    return enhancedUrl;
  }

  void _initializeWebView() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    
    final enhancedUrl = _getEnhancedYouTubeUrl(widget.embedUrl);
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            String userMessage = error.description;
            
            if (error.description.contains('153') || 
                error.description.contains('configuration error')) {
              userMessage = locale.languageCode == 'en'
                  ? 'YouTube video configuration error.\n\n'
                      'Possible reasons:\n'
                      '• Video is private or restricted\n'
                      '• Live stream hasn\'t started yet\n'
                      '• Embedding is disabled for this video\n'
                      '• Invalid video ID\n\n'
                      'Please check the video settings in YouTube Studio.'
                  : 'Kesalahan konfigurasi video YouTube.\n\n'
                      'Kemungkinan penyebab:\n'
                      '• Video bersifat privat atau dibatasi\n'
                      '• Live stream belum dimulai\n'
                      '• Embedding dinonaktifkan untuk video ini\n'
                      '• ID video tidak valid\n\n'
                      'Silakan periksa pengaturan video di YouTube Studio.';
            }
            
            setState(() {
              _isLoading = false;
              _errorMessage = userMessage;
            });
          },
        ),
      )
      ..loadRequest(
        Uri.parse(enhancedUrl),
        headers: {
          'Referer': 'https://bindexmall.com',
        },
      );
  }

  Future<void> _openInExternalApp() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    
    String appUrl = widget.embedUrl;
    
    if (widget.liveType == 'youtube') {
      if (appUrl.contains('/embed/')) {
        final videoId = appUrl.split('/embed/')[1].split('?')[0];
        appUrl = 'https://www.youtube.com/watch?v=$videoId';
      }
    }
    
    final Uri url = Uri.parse(appUrl);
    
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched && widget.liveType == 'tiktok' && mounted) {
        Navigator.pop(context);
      }
      
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale.languageCode == 'en'
                  ? 'Cannot open ${_getAppName()} app'
                  : 'Tidak dapat membuka aplikasi ${_getAppName()}'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale.languageCode == 'en'
                  ? 'Error: ${e.toString()}'
                  : 'Kesalahan: ${e.toString()}'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getAppName() {
    return widget.liveType == 'tiktok' ? 'TikTok' : 'YouTube';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        if (widget.liveType == 'tiktok') {
          return _buildTikTokPreviewScreen(locale);
        }
        
        return _buildYouTubeWebViewScreen(locale);
      },
    );
  }

  Widget _buildTikTokPreviewScreen(Locale locale) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00F2EA),
              const Color(0xFFFF0050),
              const Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.music_note,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'TikTok Live',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('openingLiveStream', locale),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _openInExternalApp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFFF0050),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.music_note, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  _t('watchOnTikTok', locale),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubeWebViewScreen(Locale locale) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _t('youtubeLive', locale),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _initializeWebView,
            tooltip: _t('refresh', locale),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: _openInExternalApp,
            tooltip: _t('openInYouTube', locale),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage == null)
            WebViewWidget(controller: _webViewController),

          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('cannotLoadVideo', locale),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _initializeWebView,
                      icon: const Icon(Icons.refresh),
                      label: Text(_t('tryAgain', locale)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _openInExternalApp,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(_t('openInYouTubeApp', locale)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading && _errorMessage == null)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('loadingYouTubeLive', locale),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}