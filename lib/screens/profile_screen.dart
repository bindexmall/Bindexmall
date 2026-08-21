// ============================================================================
// SCREEN: ProfileScreen
// ============================================================================
// Halaman akun user: ringkasan profil, menu ke alamat/pesanan/wishlist/pengaturan
// notifikasi/bahasa/tema, tombol logout.
// ============================================================================

import 'package:bindexmall/providers/language_provider.dart';
import 'package:bindexmall/providers/notification_provider.dart';
import 'package:bindexmall/providers/theme_provider.dart'; // ✅ TAMBAHKAN INI
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../services/woocommerce_service.dart';
import '../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _ordersCount = 0;
  bool _isLoadingOrders = true;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    setState(() {
      _currentLocale = Locale(languageCode);
    });
  }

  Future<void> _changeLanguage(String languageCode) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await languageProvider.changeLanguage(languageCode);
    
    setState(() {
      _currentLocale = Locale(languageCode);
    });
  }

  String _t(String key) {
    return AppLocalizations(_currentLocale).translate(key);
  }

  Future<void> _loadUserStats() async {
    setState(() {
      _isLoadingOrders = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.isAuthenticated && authProvider.userId != null) {
        final customerId = int.tryParse(authProvider.userId!);
        
        if (customerId != null) {
          final orders = await wooCommerceService.getCustomerOrders(
            customerId,
            perPage: 100,
          );
          
          _ordersCount = orders.length;
        }
      }

      setState(() {
        _isLoadingOrders = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingOrders = false;
        _ordersCount = 0;
      });
      
      debugPrint('Error loading user stats: $e');
    }
  }

  void _navigateToEditProfile(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      _showLoginRequiredDialog(context, _t('editProfile').toLowerCase());
      return;
    }
    
    Navigator.pushNamed(context, '/edit-profile');
  }

  void _navigateToOrders(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      _showLoginRequiredDialog(context, _t('myOrders').toLowerCase());
      return;
    }
    
    Navigator.pushNamed(context, '/orders');
  }

  void _showLoginRequiredDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 12),
            Text(_t('loginRequired')),
          ],
        ),
        content: Text(
          '${_currentLocale.languageCode == 'en' ? 'You must login first to' : 'Anda harus login terlebih dahulu untuk'} $feature.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/signin');
            },
            child: Text(_t('login')),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _t('selectLanguage'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildLanguageOption(
              context,
              _t('english'),
              'en',
              '🇺🇸',
            ),
            _buildLanguageOption(
              context,
              _t('indonesian'),
              'id',
              '🇮🇩',
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String label,
    String code,
    String flag,
  ) {
    final isSelected = _currentLocale.languageCode == code;
    
    return ListTile(
      leading: Text(
        flag,
        style: const TextStyle(fontSize: 28),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () async {
        await _changeLanguage(code);
        Navigator.pop(context);
        
        // Show snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                code == 'en'
                    ? _t('languageChangedToEnglish')
                    : _t('languageChangedToIndonesian'),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.grey[900] 
          : Colors.grey[50], // ✅ SUPPORT DARK MODE
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (!authProvider.isAuthenticated) {
            return _buildGuestView(context);
          }
          return RefreshIndicator(
            onRefresh: _loadUserStats,
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(context),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildProfileCard(context),
                      const SizedBox(height: 20),
                      _buildMenuSection(context),
                      const SizedBox(height: 16),
                      _buildSettingsSection(context),
                      const SizedBox(height: 20),
                      _buildLogoutButton(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
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
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('guestUser'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentLocale.languageCode == 'en'
                          ? 'Please login to access all features'
                          : 'Silakan login untuk mengakses semua fitur',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Login Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, // ✅ SUPPORT DARK MODE
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _currentLocale.languageCode == 'en'
                            ? 'Login to Continue'
                            : 'Login untuk Melanjutkan',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentLocale.languageCode == 'en'
                            ? 'Access your profile, orders, and exclusive features'
                            : 'Akses profil, pesanan, dan fitur eksklusif Anda',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/signin');
                          },
                          icon: const Icon(Icons.login),
                          label: Text(
                            _currentLocale.languageCode == 'en'
                                ? 'Login Now'
                                : 'Login Sekarang',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text(
                          _currentLocale.languageCode == 'en'
                              ? 'Don\'t have an account? Register'
                              : 'Belum punya akun? Daftar',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Guest Features
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, // ✅ SUPPORT DARK MODE
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.favorite_outline,
                        title: _t('myWishlist'),
                        onTap: () {
                          Navigator.pushNamed(context, '/wishlist');
                        },
                      ),
                      _buildDividerLine(),
                      // ✅ TAMBAHKAN DARK MODE TOGGLE DI GUEST VIEW
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, child) {
                          return _buildMenuItem(
                            context,
                            icon: themeProvider.isDarkMode 
                                ? Icons.dark_mode 
                                : Icons.light_mode,
                            title: _currentLocale.languageCode == 'en'
                                ? 'Dark Mode'
                                : 'Mode Gelap',
                            subtitle: themeProvider.isDarkMode
                                ? (_currentLocale.languageCode == 'en' ? 'Enabled' : 'Aktif')
                                : (_currentLocale.languageCode == 'en' ? 'Disabled' : 'Nonaktif'),
                            trailing: Switch.adaptive(
                              value: themeProvider.isDarkMode,
                              onChanged: (value) async {
                                await themeProvider.toggleTheme();
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? (_currentLocale.languageCode == 'en'
                                                ? 'Dark mode enabled'
                                                : 'Mode gelap diaktifkan')
                                            : (_currentLocale.languageCode == 'en'
                                                ? 'Light mode enabled'
                                                : 'Mode terang diaktifkan'),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                      _buildDividerLine(),
                      _buildMenuItem(
                        context,
                        icon: Icons.language,
                        title: _t('language'),
                        subtitle: _currentLocale.languageCode == 'en' ? _t('english') : _t('indonesian'),
                        onTap: () => _showLanguageSelector(context),
                      ),
                      _buildDividerLine(),
                      _buildMenuItem(
                        context,
                        icon: Icons.help_outline,
                        title: _t('helpAndSupport'),
                        onTap: () {
                          Navigator.pushNamed(context, '/help-support');
                        },
                      ),
                      _buildDividerLine(),
                      _buildMenuItem(
                        context,
                        icon: Icons.info_outline,
                        title: _t('about'),
                        onTap: () {
                          Navigator.pushNamed(context, '/about');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
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
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return Column(
                      children: [
                        Text(
                          auth.userName ?? _t('guestUser'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          auth.userEmail ?? 'guest@example.com',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅ SUPPORT DARK MODE
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            _isLoadingOrders ? '...' : '$_ordersCount',
            _t('orders'),
            Icons.shopping_bag_outlined,
            onTap: () => _navigateToOrders(context),
          ),
          Container(
            height: 50,
            width: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]
                : Colors.grey[200], // ✅ SUPPORT DARK MODE
          ),
          Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              return _buildStatItem(
                context,
                '${productProvider.wishlist.length}',
                _t('wishlist'),
                Icons.favorite_outline,
                onTap: () {
                  Navigator.pushNamed(context, '/wishlist');
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600], // ✅ SUPPORT DARK MODE
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅ SUPPORT DARK MODE
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: _t('editProfile'),
            onTap: () => _navigateToEditProfile(context),
          ),
          _buildDividerLine(),
          _buildMenuItem(
            context,
            icon: Icons.receipt_long_outlined,
            title: _t('myOrders'),
            onTap: () => _navigateToOrders(context),
          ),
          _buildDividerLine(),
          _buildMenuItem(
            context,
            icon: Icons.favorite_outline,
            title: _t('myWishlist'),
            onTap: () {
              Navigator.pushNamed(context, '/wishlist');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅ SUPPORT DARK MODE
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          return Column(
            children: [
              // Main Notification Toggle
              _buildMenuItem(
                context,
                icon: Icons.notifications_outlined,
                title: _t('notifications'),
                trailing: Switch.adaptive(
                  value: notificationProvider.notificationsEnabled,
                  onChanged: (value) async {
                    await notificationProvider.toggleNotifications(value);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value 
                              ? _t('notificationSettingsComingSoon')
                              : (_currentLocale.languageCode == 'en' 
                                  ? 'Notifications disabled' 
                                  : 'Notifikasi dinonaktifkan'),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
              
              // Show sub-options only if notifications are enabled
              if (notificationProvider.notificationsEnabled) ...[
                _buildDividerLine(),
                Padding(
                  padding: const EdgeInsets.only(left: 72),
                  child: _buildMenuItem(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: _currentLocale.languageCode == 'en' 
                        ? 'Order Updates' 
                        : 'Update Pesanan',
                    subtitle: _currentLocale.languageCode == 'en'
                        ? 'Get notified when order status changes'
                        : 'Dapatkan notifikasi saat status pesanan berubah',
                    trailing: Switch.adaptive(
                      value: notificationProvider.orderStatusEnabled,
                      onChanged: (value) async {
                        await notificationProvider.toggleOrderStatus(value);
                      },
                    ),
                  ),
                ),
                _buildDividerLine(),
                Padding(
                  padding: const EdgeInsets.only(left: 72),
                  child: _buildMenuItem(
                    context,
                    icon: Icons.mail_outline,
                    title: _currentLocale.languageCode == 'en'
                        ? 'Newsletter & Promotions'
                        : 'Newsletter & Promosi',
                    subtitle: _currentLocale.languageCode == 'en'
                        ? 'Get deals, offers, and news'
                        : 'Dapatkan penawaran dan berita',
                    trailing: Switch.adaptive(
                      value: notificationProvider.newsletterEnabled,
                      onChanged: (value) async {
                        await notificationProvider.toggleNewsletter(value);
                      },
                    ),
                  ),
                ),
              ],
              
              _buildDividerLine(),
              
              // ✅ TAMBAHKAN DARK MODE TOGGLE DI SINI (UNTUK LOGGED IN USER)
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return _buildMenuItem(
                    context,
                    icon: themeProvider.isDarkMode 
                        ? Icons.dark_mode 
                        : Icons.light_mode,
                    title: _currentLocale.languageCode == 'en'
                        ? 'Dark Mode'
                        : 'Mode Gelap',
                    subtitle: themeProvider.isDarkMode
                        ? (_currentLocale.languageCode == 'en' ? 'Enabled' : 'Aktif')
                        : (_currentLocale.languageCode == 'en' ? 'Disabled' : 'Nonaktif'),
                    trailing: Switch.adaptive(
                      value: themeProvider.isDarkMode,
                      onChanged: (value) async {
                        await themeProvider.toggleTheme();
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? (_currentLocale.languageCode == 'en'
                                        ? 'Dark mode enabled'
                                        : 'Mode gelap diaktifkan')
                                    : (_currentLocale.languageCode == 'en'
                                        ? 'Light mode enabled'
                                        : 'Mode terang diaktifkan'),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
              
              _buildDividerLine(),
              _buildMenuItem(
                context,
                icon: Icons.language,
                title: _t('language'),
                subtitle: _currentLocale.languageCode == 'en' ? _t('english') : _t('indonesian'),
                onTap: () => _showLanguageSelector(context),
              ),
              _buildDividerLine(),
              _buildMenuItem(
                context,
                icon: Icons.help_outline,
                title: _t('helpAndSupport'),
                onTap: () {
                  Navigator.pushNamed(context, '/help-support');
                },
              ),
              _buildDividerLine(),
              _buildMenuItem(
                context,
                icon: Icons.info_outline,
                title: _t('about'),
                onTap: () {
                  Navigator.pushNamed(context, '/about');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600], // ✅ SUPPORT DARK MODE
                fontSize: 13,
              ),
            )
          : null,
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[600]
                : Colors.grey[400], // ✅ SUPPORT DARK MODE
            size: 20,
          ),
    );
  }

  Widget _buildDividerLine() {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[200], // ✅ SUPPORT DARK MODE
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _showLogoutDialog(context);
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: Text(
          _t('logout'),
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.red.shade400, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('logout')),
        content: Text(_t('logoutConfirmation')),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/intro',
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(_t('logout')),
          ),
        ],
      ),
    );
  }
}