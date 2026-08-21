// ============================================================================
// SCREEN: LiveChatScreen
// ============================================================================
// UI chat dengan chatbot internal (ChatbotService) — bukan Tawk.to. Cek konteksnya
//
// Catatan:
//  - dulu (tombol mana yang membuka screen ini) sebelum menyamakan dengan live_stream_screen.dart.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen>
    with TickerProviderStateMixin {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _isConnected = false;
  
  late AnimationController _shimmerController;
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeWebView();
  }

  void _initializeAnimations() {
    // Shimmer animation for loading
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    

    // Dot animation for loading indicator
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  void _initializeWebView() {
    final authProvider = context.read<AuthProvider>();
    
    const propertyId = '68f6ebe4559a7e194c802005';
    const widgetId = '1j828iu09';
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              if (progress == 100) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _isConnected = true;
                    });
                  }
                });
              }
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            if (authProvider.isAuthenticated) {
              await _setTawkUserInfo(authProvider);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _isConnected = false;
              });
            }
          },
        ),
      );

    final tawkUrl = 'https://tawk.to/chat/$propertyId/$widgetId';
    _webViewController.loadRequest(Uri.parse(tawkUrl));
  }

  Future<void> _setTawkUserInfo(AuthProvider authProvider) async {
    final userName = authProvider.userName ?? 'Guest';
    final userEmail = authProvider.userEmail ?? '';
    
    try {
      await _webViewController.runJavaScript('''
        (function() {
          if (typeof Tawk_API !== 'undefined') {
            Tawk_API.setAttributes({
              'name': '$userName',
              'email': '$userEmail',
              'userId': '${authProvider.userId ?? ''}'
            });
          }
        })();
      ''');
    } catch (e) {
      debugPrint('Error setting Tawk user info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildNativeAppBar(locale),
          body: Stack(
            children: [
              // Native-looking background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey[50]!,
                      Colors.white,
                    ],
                  ),
                ),
              ),

              // WebView dengan rounded corners
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: WebViewWidget(controller: _webViewController),
                  ),
                ),
              ),
              
              // Native loading overlay
              if (_isLoading) _buildNativeLoadingOverlay(),
              
              // Connection status bar
              _buildConnectionStatusBar(locale),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildNativeAppBar(Locale locale) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              if (_isConnected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('customerSupport', locale),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _isConnected ? _t('online', locale) : _t('connecting', locale),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isConnected ? Colors.green : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black87),
          onPressed: () => _webViewController.reload(),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onPressed: () => _showNativeOptions(context, locale),
        ),
      ],
    );
  }

  Widget _buildNativeLoadingOverlay() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );
  }

  Widget _buildConnectionStatusBar(Locale locale) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: _isConnected && !_isLoading ? -50 : 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: _isConnected ? Colors.green : Colors.orange,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isConnected ? Icons.check_circle : Icons.sync,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _isConnected ? _t('connected', locale) : _t('reconnecting', locale),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNativeOptions(BuildContext context, Locale locale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              _buildOptionTile(
                locale: locale,
                icon: Icons.refresh,
                title: _t('reloadChat', locale),
                subtitle: _t('refreshTheConversation', locale),
                onTap: () {
                  Navigator.pop(context);
                  _webViewController.reload();
                },
              ),
              
              _buildOptionTile(
                locale: locale,
                icon: Icons.cleaning_services_outlined,
                title: _t('clearCache', locale),
                subtitle: locale.languageCode == 'en' ? 'Reset chat data' : 'Reset data obrolan',
                onTap: () async {
                  Navigator.pop(context);
                  await _webViewController.clearCache();
                  await _webViewController.clearLocalStorage();
                  _webViewController.reload();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 12),
                            Text(_t('cacheClearedSuccessfully', locale)),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
              ),
              
              _buildOptionTile(
                locale: locale,
                icon: Icons.info_outline,
                title: _t('about', locale),
                subtitle: _t('chatInformation', locale),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog(locale);
                },
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required Locale locale,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showAboutDialog(Locale locale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(_t('liveChat', locale)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Powered by Tawk.to',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              locale.languageCode == 'en' 
                ? 'Real-time messaging' 
                : 'Pesan real-time',
            ),
            _buildFeatureItem(
              locale.languageCode == 'en' 
                ? '24/7 support availability' 
                : 'Dukungan 24/7',
            ),
            _buildFeatureItem(
              locale.languageCode == 'en' 
                ? 'Chat history saved' 
                : 'Riwayat chat tersimpan',
            ),
            _buildFeatureItem(
              locale.languageCode == 'en' 
                ? 'File sharing support' 
                : 'Dukungan berbagi file',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('gotIt', locale)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}