// ============================================================================
// SCREEN: IntroScreen + IntroPage
// ============================================================================
// Onboarding/carousel perkenalan app untuk user baru (biasanya muncul sebelum sign in).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _checkAuthStatus();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    setState(() {
      _currentLocale = Locale(languageCode);
    });
  }

  String _t(String key) {
    return AppLocalizations(_currentLocale).translate(key);
  }

  List<IntroPage> _getPages() {
    return [
      IntroPage(
        title: _t('welcomeToBindexmall'),
        description: _t('discoverAmazingProducts'),
        image: Icons.shopping_bag,
        color: Colors.blue,
        imageUrl: null,
      ),
      IntroPage(
        title: _t('easyShopping'),
        description: _t('browseThousandsOfProducts'),
        image: Icons.smartphone,
        color: Colors.green,
        imageUrl: null,
      ),
      IntroPage(
        title: _t('securePayment'),
        description: _t('shopWithConfidence'),
        image: Icons.security,
        color: Colors.orange,
        imageUrl: null,
      ),
    ];
  }

  void _checkAuthStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();

      if (authProvider.isAuthenticated) {
        debugPrint('✅ User already logged in, redirecting to main...');
        Navigator.pushReplacementNamed(context, '/main');
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/signin');
                },
                child: Text(_t('skip')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(pages[index], index);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, '/signin');
                    }
                  },
                  child: Text(
                    _currentPage < pages.length - 1
                        ? _t('next')
                        : _t('getStarted'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(IntroPage page, int index) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon / Image
          page.imageUrl != null && page.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: page.imageUrl!,
                  width: 150,
                  height: 150,
                  placeholder: (context, url) => Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    page.image,
                    size: 150,
                    color: page.color,
                  ),
                  fit: BoxFit.contain,
                )
              : Icon(
                  page.image,
                  size: 150,
                  color: page.color,
                ),
          // const SizedBox(height: 10),
          if (index == 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Welcome to ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),

                Image.asset(
                  'assets/images/ic_launcher.png',
                  width: 120,
                  fit: BoxFit.contain,
                ),

                // RichText(
                //   text: TextSpan(
                //     children: [
                //       TextSpan(
                //         text: 'binde',
                //         style: TextStyle(
                //           fontSize: 24,
                //           fontWeight: FontWeight.bold,
                //           color: Colors.blue[800],
                //         ),
                //       ),
                //       TextSpan(
                //         text: 'X',
                //         style: TextStyle(
                //           fontSize: 24,
                //           fontWeight: FontWeight.bold,
                //           color: Colors.orange[700],
                //         ),
                //       ),
                //       TextSpan(
                //         text: 'mall',
                //         style: TextStyle(
                //           fontSize: 20,
                //           fontWeight: FontWeight.bold,
                //           color: Colors.orange[700],
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ] else ...[
            Text(
              page.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class IntroPage {
  final String title;
  final String description;
  final IconData image;
  final Color color;
  final String? imageUrl;

  IntroPage({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
    this.imageUrl,
  });
}
