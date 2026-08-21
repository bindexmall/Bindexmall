// ============================================================================
// SCREEN: DealsScreen
// ============================================================================
// Halaman produk diskon/flash sale (list produk dengan sale_price aktif).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../widgets/product_card.dart';
import '../l10n/app_localizations.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  List<Product> _saleProducts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _sortBy = 'discount_high';
  bool _isGridView = true;

  int _currentPage = 1;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadSaleProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreProducts();
      }
    }
  }

  Future<void> _loadSaleProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMorePages = true;
      _saleProducts.clear();
    });

    try {
      // Fetch first page only (fast!)
      final products = await productRepository.fetchProducts(
        page: 1,
        perPage: 20,
        onSale: true,
      );

      setState(() {
        _saleProducts = products;
        _applySorting();
        _isLoading = false;
        _hasMorePages = products.length >= 20;
        _currentPage = 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final products = await productRepository.fetchProducts(
        page: nextPage,
        perPage: 20,
        onSale: true,
      );

      setState(() {
        _saleProducts.addAll(products);
        _applySorting();
        _currentPage = nextPage;
        _hasMorePages = products.length >= 20;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('failedToLoadMore')}: $e')),
        );
      }
    }
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'discount_high':
        _saleProducts.sort(
            (a, b) => b.discountPercentage.compareTo(a.discountPercentage));
        break;
      case 'discount_low':
        _saleProducts.sort(
            (a, b) => a.discountPercentage.compareTo(b.discountPercentage));
        break;
      case 'price_low':
        _saleProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        _saleProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
    }
  }

  void _changeSortBy(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      _applySorting();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ UBAH
      appBar: AppBar(
        title: Text(
          _t('specialDeals'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor, // ✅ UBAH
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color, // ✅ UBAH
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? _t('listView') : _t('gridView'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: _t('sortBy'),
            onSelected: _changeSortBy,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'discount_high',
                child: Text(_t('highestDiscount')),
              ),
              PopupMenuItem(
                value: 'discount_low',
                child: Text(_t('lowestDiscount')),
              ),
              PopupMenuItem(
                value: 'price_low',
                child: Text(_t('priceLowToHigh')),
              ),
              PopupMenuItem(
                value: 'price_high',
                child: Text(_t('priceHighToLow')),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _t('failedToLoadDeals'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSaleProducts,
              icon: const Icon(Icons.refresh),
              label: Text(_t('retry')),
            ),
          ],
        ),
      );
    }

    if (_saleProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _t('noDealsAvailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _t('checkBackLaterForDeals'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSaleProducts,
      child: Column(
        children: [
          _buildHeaderBanner(),
          Expanded(
            child: _isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red[700]!,
            Colors.red[500]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('hotDeals'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_saleProducts.length}${_hasMorePages ? '+' : ''} ${_t('productsOnSale')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('upToOff'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_offer,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _saleProducts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _saleProducts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final product = _saleProducts[index];
        return ProductCard(
          product: product,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/product-detail',
              arguments: product,
            );
          },
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _saleProducts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _saleProducts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final product = _saleProducts[index];
        return ProductCard(
          product: product,
          isListView: true,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/product-detail',
              arguments: product,
            );
          },
        );
      },
    );
  }
}