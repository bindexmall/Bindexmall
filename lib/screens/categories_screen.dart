// ============================================================================
// SCREEN: CategoriesScreen
// ============================================================================
// Daftar semua kategori produk (grid/list) — tap kategori masuk ke CatalogScreen ter-filter.
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../providers/cart_provider.dart';
import '../repositories/category_repository.dart';
import '../l10n/app_localizations.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  List<Category> _categories = [];
  List<int> _extends = [];
  bool _isLoading = true;
  String? _error;
  Locale _currentLocale = const Locale('en');

  final rnd = Random();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _loadCategory();
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCategory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await categoryRepository.fetchCategories();
      final extents = List<int>.generate(
        categories.length,
        (index) => rnd.nextInt(3) + 2,
      );

      setState(() {
        _categories = categories;
        _extends = extents;
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(_currentLocale);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // ✅ TAMBAHKAN
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ TAMBAHKAN
      appBar: AppBar(
        title: Text(l10n.translate('categories')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87, // ✅ TAMBAHKAN
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
                icon: Badge(
                  isLabelVisible: cartProvider.isNotEmpty,
                  label: Text('${cartProvider.totalQuantity}'),
                  child: Icon(
                    Icons.shopping_cart,
                    color: isDarkMode ? Colors.white : Colors.black87, // ✅ UBAH
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.favorite_border,
              color: isDarkMode ? Colors.white : Colors.black87, // ✅ UBAH
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/wishlist');
            },
          ),
          PopupMenuButton(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode ? Colors.white : Colors.black87, // ✅ UBAH
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(l10n.translate('profile')),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(l10n.translate('settings')),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'settings') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.translate('settingsComingSoon')),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('errorLoadingCategories'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600], // ✅ UBAH
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCategory,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.translate('retry')),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]
                  : Colors.grey[400], // ✅ UBAH
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('noCategoriesAvailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n),
          Expanded(
            child: _buildCategoriesGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('shopByCategory'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('findWhatYouNeed'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600], // ✅ UBAH
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return FadeTransition(
      opacity: _animationController,
      child: MasonryGridView.count(
        padding: const EdgeInsets.only(
          left: 8.0,
          right: 8.0,
          bottom: 16.0,
        ),
        crossAxisCount: 3,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final height = _extends[index] * 100;
          final category = _categories[index];
          
          return _buildCategoryCard(category, height.toDouble());
        },
      ),
    );
  }

  Widget _buildCategoryCard(Category category, double height) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // ✅ TAMBAHKAN
    
    return Hero(
      tag: category.id,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/catalog',
              arguments: {
                'category': category.name,
                'categoryId': category.id,
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1), // ✅ UBAH
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Category Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    category.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[300], // ✅ UBAH
                        child: Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: isDarkMode ? Colors.grey[600] : Colors.grey[500], // ✅ UBAH
                        ),
                      );
                    },
                  ),
                ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(isDarkMode ? 0.8 : 0.7), // ✅ UBAH - lebih gelap di dark mode
                      ],
                    ),
                  ),
                ),
                // Category Name
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}