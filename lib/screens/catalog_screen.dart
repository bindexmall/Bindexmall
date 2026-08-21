// ============================================================================
// SCREEN: CatalogScreen
// ============================================================================
// Halaman katalog/daftar produk lengkap dengan search, filter kategori/harga, sorting,
// menggunakan ProductProvider.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../repositories/category_repository.dart';
import '../widgets/product_card.dart';
import '../l10n/app_localizations.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.category,
    required this.categoryId,
    this.tag,
    this.initialSort,
  });

  final String category;
  final String categoryId;
  /// WooCommerce tag slug, e.g. 'best-seller'
  final String? tag;
  /// Initial sort key: 'date_desc', 'price_asc', 'price_desc', 'name'
  final String? initialSort;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;
  Locale _currentLocale = const Locale('en');
  
  // Untuk subcategories
  List<Category> _subCategories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubCategories();
      final provider = context.read<ProductProvider>();
      // Apply initial sort if provided
      if (widget.initialSort != null) {
        provider.sortProducts(widget.initialSort!);
      }
      // Load products with tag or categoryId
      if (widget.tag != null && widget.tag!.isNotEmpty) {
        provider.loadProductsByTag(widget.tag!);
      } else {
        provider.loadProducts(widget.categoryId);
      }
    });
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

  Future<void> _loadSubCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final subCategories = await categoryRepository.fetchSubcategories(widget.categoryId);
      setState(() {
        _subCategories = subCategories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      print('Error loading subcategories: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(_currentLocale);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
                icon: Badge(
                  isLabelVisible: cartProvider.isNotEmpty,
                  label: Text('${cartProvider.totalQuantity}'),
                  child: const Icon(Icons.shopping_cart),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(l10n),
          // Tampilkan subcategories jika ada
          if (_subCategories.isNotEmpty) _buildSubCategoriesSection(),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (productProvider.error != null) {
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
                          l10n.translate('errorLoadingProducts'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          productProvider.error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (widget.tag != null && widget.tag!.isNotEmpty) {
                              productProvider.loadProductsByTag(widget.tag!);
                            } else {
                              productProvider.loadProducts(widget.categoryId);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.translate('retry')),
                        ),
                      ],
                    ),
                  );
                }

                final products = productProvider.products;

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.translate('noProductsFound'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (productProvider.searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              productProvider.searchProducts('');
                            },
                            child: Text(l10n.translate('clearSearch')),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _loadSubCategories(),
                      if (widget.tag != null && widget.tag!.isNotEmpty)
                        productProvider.loadProductsByTag(widget.tag!)
                      else
                        productProvider.loadProducts(widget.categoryId),
                    ]);
                  },
                  child: _isGridView
                      ? _buildGridView(products)
                      : _buildListView(products),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCategoriesSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: _isLoadingCategories
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _subCategories.length,
                    itemBuilder: (context, index) {
                      final subCategory = _subCategories[index];
                      return _buildSubCategoryCard(subCategory);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey[200]!,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCategoryCard(Category category) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CatalogScreen(
                category: category.name,
                categoryId: category.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                category.imageUrl.isNotEmpty
                    ? Image.network(
                        category.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder();
                        },
                      )
                    : _buildPlaceholder(),
                // Overlay gradient untuk memberikan depth
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.category_rounded,
          size: 36,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.translate('searchProducts'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<ProductProvider>().searchProducts('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        onChanged: (value) {
          context.read<ProductProvider>().searchProducts(value);
        },
      ),
    );
  }

  Widget _buildGridView(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(
          product: products[index],
          onTap: () {
            Navigator.pushNamed(
              context,
              '/product-detail',
              arguments: products[index],
            );
          },
        );
      },
    );
  }

  Widget _buildListView(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(
          product: products[index],
          isListView: true,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/product-detail',
              arguments: products[index],
            );
          },
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    final l10n = AppLocalizations(_currentLocale);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.6,
                  minChildSize: 0.4,
                  maxChildSize: 0.9,
                  expand: false,
                  builder: (context, scrollController) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.translate('filterAndSort'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              TextButton(
                                onPressed: () {
                                  productProvider.clearFilters();
                                  Navigator.pop(context);
                                },
                                child: Text(l10n.translate('clearAll')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              children: [
                                _buildSortSection(productProvider, l10n),
                                const Divider(height: 32),
                                _buildPriceRangeSection(productProvider, setModalState, l10n),
                              ],
                            ),
                          ),
                          SafeArea(
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(l10n.translate('applyFilters')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSortSection(ProductProvider productProvider, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('sortBy'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _buildSortOption(l10n.translate('name'), 'name', productProvider),
        _buildSortOption(l10n.translate('priceLowToHigh'), 'price_asc', productProvider),
        _buildSortOption(l10n.translate('priceHighToLow'), 'price_desc', productProvider),
      ],
    );
  }

  Widget _buildSortOption(
    String label,
    String value,
    ProductProvider productProvider,
  ) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: productProvider.sortBy,
      onChanged: (newValue) {
        if (newValue != null) {
          productProvider.sortProducts(newValue);
        }
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPriceRangeSection(
    ProductProvider productProvider, 
    StateSetter setModalState,
    AppLocalizations l10n,
  ) {
    double minPrice = productProvider.minPrice ?? 0;
    double maxPrice = productProvider.maxPrice ?? 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('priceRange'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('\$${minPrice.toStringAsFixed(0)}'),
            const Spacer(),
            Text('\$${maxPrice.toStringAsFixed(0)}'),
          ],
        ),
        RangeSlider(
          values: RangeValues(minPrice, maxPrice),
          min: 0,
          max: 500,
          divisions: 50,
          labels: RangeLabels(
            '\$${minPrice.toStringAsFixed(0)}',
            '\$${maxPrice.toStringAsFixed(0)}',
          ),
          onChanged: (RangeValues values) {
            setModalState(() {
              productProvider.setPriceRange(values.start, values.end);
            });
          },
        ),
      ],
    );
  }
}