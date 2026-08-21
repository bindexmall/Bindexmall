// ============================================================================
// SCREEN: MainScreen
// ============================================================================
// Container navigasi utama (bottom navigation bar) yang menampung Home/Catalog/
//
// Catatan:
//  - Cart/Wishlist/Profile (atau kombinasi serupa) sebagai tab. Ini root screen setelah login.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ShopScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
  ];

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: _t('home', locale),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  activeIcon: const Icon(Icons.shopping_bag),
                  label: _t('shop', locale),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: _t('orders', locale),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: _t('profile', locale),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}