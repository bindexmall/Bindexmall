// ============================================================================
// SCREEN: AboutScreen
// ============================================================================
// Halaman 'Tentang Kami' — info perusahaan, alamat toko, kontak, kebijakan, dsb (statis).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    if (mounted) {
      setState(() {
        _currentLocale = Locale(languageCode);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload language preference when dependencies change
    _loadLanguagePreference();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(_currentLocale);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.translate('about'))),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // App Logo & Info Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/ic_launcher.png',
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.shopping_bag,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.translate('version'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.translate('yourTrustedShoppingDestination'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('aboutUs'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.translate('aboutUsDescription'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      l10n,
                      icon: Icons.verified_user,
                      title: l10n.translate('originalProduct'),
                      description: l10n.translate('originalProductDesc'),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      l10n,
                      icon: Icons.local_shipping,
                      title: l10n.translate('fastDelivery'),
                      description: l10n.translate('fastDeliveryDesc'),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      l10n,
                      icon: Icons.payment,
                      title: l10n.translate('securePaymentTitle'),
                      description: l10n.translate('securePaymentDesc'),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      l10n,
                      icon: Icons.support_agent,
                      title: l10n.translate('customerService247'),
                      description: l10n.translate('customerService247Desc'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('followUs'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSocialButton(
                          icon: Icons.facebook,
                          color: const Color(0xFF1877F2),
                          label: l10n.translate('facebook'),
                          onTap: () => _launchURL('https://facebook.com/bindexmall'),
                        ),
                        _buildSocialButton(
                          icon: Icons.camera_alt,
                          color: const Color(0xFFE4405F),
                          label: l10n.translate('instagram'),
                          onTap: () => _launchURL('https://instagram.com/bindexmall'),
                        ),
                        _buildSocialButton(
                          icon: Icons.play_circle_outline,
                          color: const Color(0xFFFF0000),
                          label: l10n.translate('youtube'),
                          onTap: () => _launchURL('https://youtube.com/@bindexmall'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Legal Links
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildLegalItem(
                      l10n,
                      icon: Icons.description_outlined,
                      title: l10n.translate('termsConditions'),
                      onTap: () => _launchURL('https://bindexmall.com/terms'),
                    ),
                    _buildDivider(),
                    _buildLegalItem(
                      l10n,
                      icon: Icons.privacy_tip_outlined,
                      title: l10n.translate('privacyPolicy'),
                      onTap: () => _launchURL('https://bindexmall.com/privacy'),
                    ),
                    _buildDivider(),
                    _buildLegalItem(
                      l10n,
                      icon: Icons.gavel_outlined,
                      title: l10n.translate('returnPolicy'),
                      onTap: () => _launchURL('https://bindexmall.com/returns'),
                    ),
                    _buildDivider(),
                    _buildLegalItem(
                      l10n,
                      icon: Icons.security_outlined,
                      title: l10n.translate('securityPrivacy'),
                      onTap: () => _launchURL('https://bindexmall.com/security'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // App Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(l10n, l10n.translate('applicationVersion'), '1.0.3'),
                    const SizedBox(height: 12),
                    _buildInfoRow(l10n, l10n.translate('releaseDate'), 'October 2025'),
                    const SizedBox(height: 12),
                    _buildInfoRow(l10n, l10n.translate('platform'), 'Android & iOS'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Copyright
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.translate('madeWithLoveInIndonesia'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[600]
                      : Colors.grey[500], // ✅ UBAH
                  fontSize: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.blue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegalItem(
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]
            : Colors.grey[700], // ✅ UBAH
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[600]
            : Colors.grey[400], // ✅ UBAH
      ),
    );
  }
  
  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[200], // ✅ UBAH
    );
  }
  
  Widget _buildInfoRow(AppLocalizations l10n, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[400]
                : Colors.grey[600], // ✅ UBAH
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }
}