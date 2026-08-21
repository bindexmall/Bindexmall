// ============================================================================
// SCREEN: ShopScreen
// ============================================================================
// Salah satu varian halaman belanja/katalog (cek routing di main.dart untuk tahu
//
// Catatan:
//  - kapan ShopScreen dipakai vs CatalogScreen — kemungkinan salah satunya adalah versi lama/duplikat.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/language_provider.dart';
import '../repositories/category_repository.dart';
import '../widgets/product_card.dart';
import '../l10n/app_localizations.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final CategoryRepository _categoryRepository = categoryRepository;

  bool _isGridView = true;
  bool _hasLoadedProducts = false;
  List<Category> _categories = [];
  bool _isLoadingCategories = false;
  String? _selectedCategoryId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedProducts) {
        _loadCategories();
        _loadAllProducts();
        _hasLoadedProducts = true;
      }
    });
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories =
          await _categoryRepository.fetchCategoriesWithProducts();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      if (mounted) {
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        final locale = languageProvider.currentLocale;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.languageCode == 'en'
                ? 'Failed to load categories: $e'
                : 'Gagal memuat kategori: $e'),
          ),
        );
      }
    }
  }

  Future<void> _loadAllProducts() async {
    final productProvider = context.read<ProductProvider>();
    await productProvider.loadProducts();
  }

  Future<void> _loadProductsByCategory(String? categoryId) async {
    final productProvider = context.read<ProductProvider>();
    setState(() {
      _selectedCategoryId = categoryId;
    });
    await productProvider.loadProducts(categoryId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              _t('shop', locale),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isGridView ? Icons.view_list : Icons.grid_view,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.filter_list,
                    color: Theme.of(context).iconTheme.color),
                onPressed: () => _showFilterBottomSheet(locale),
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
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildSearchBar(locale),
              _buildCategoryChips(locale),
              Expanded(
                child: Consumer<ProductProvider>(
                  builder: (context, productProvider, child) {
                    if (productProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (productProvider.error != null) {
                      return _buildErrorView(productProvider, locale);
                    }

                    final products = productProvider.products;

                    if (products.isEmpty) {
                      return _buildEmptyView(productProvider, locale);
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await _loadCategories();
                        if (_selectedCategoryId != null) {
                          await _loadProductsByCategory(_selectedCategoryId);
                        } else {
                          await _loadAllProducts();
                        }
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
      },
    );
  }

  Widget _buildSearchBar(Locale locale) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: _t('searchProducts', locale),
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
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) {
          context.read<ProductProvider>().searchProducts(value);
        },
      ),
    );
  }

  Widget _buildCategoryChips(Locale locale) {
    if (_isLoadingCategories) {
      return Container(
        color: Theme.of(context).cardColor,
        height: 60,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).cardColor,
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apps, size: 16),
                    const SizedBox(width: 4),
                    Text(_t('all', locale)),
                  ],
                ),
                selected: _selectedCategoryId == null,
                onSelected: (selected) {
                  _loadProductsByCategory(null);
                },
                selectedColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.6),
                checkmarkColor: const Color.fromARGB(255, 48, 48, 48),
              ),
            );
          }

          final category = _categories[index - 1];
          final isSelected = _selectedCategoryId == category.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              // ✅ GUNAKAN CACHED NETWORK IMAGE UNTUK CATEGORY AVATAR
              avatar: category.imageUrl.isNotEmpty
                  ? _buildCategoryAvatar(category.imageUrl)
                  : const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child:
                          Icon(Icons.category, size: 16, color: Colors.white),
                    ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 48, 48, 48),
                    ),
                  ),
                  if (category.count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${category.count})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color.fromARGB(255, 48, 48, 48),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                _loadProductsByCategory(category.id);
              },
              selectedColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.6),
              checkmarkColor: const Color.fromARGB(255, 48, 48, 48),
            ),
          );
        },
      ),
    );
  }

  // ✅ WIDGET UNTUK CATEGORY AVATAR DENGAN CACHED IMAGE
  Widget _buildCategoryAvatar(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        backgroundImage: imageProvider,
        backgroundColor: Colors.grey[200],
      ),
      placeholder: (context, url) => CircleAvatar(
        backgroundColor: Colors.grey[200],
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.category, size: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildErrorView(ProductProvider provider, Locale locale) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              _t('errorLoadingProducts', locale),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await _loadCategories();
                if (_selectedCategoryId != null) {
                  await _loadProductsByCategory(_selectedCategoryId);
                } else {
                  await _loadAllProducts();
                }
              },
              icon: const Icon(Icons.refresh),
              label: Text(_t('retry', locale)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ProductProvider provider, Locale locale) {
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
            _t('noProductsFound', locale),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (provider.searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                provider.searchProducts('');
              },
              child: Text(_t('clearSearch', locale)),
            )
          else if (_selectedCategoryId != null)
            TextButton(
              onPressed: () {
                _loadProductsByCategory(null);
              },
              child: Text(locale.languageCode == 'en'
                  ? 'Show all products'
                  : 'Tampilkan semua produk'),
            ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(12.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
      padding: const EdgeInsets.all(12.0),
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

  void _showFilterBottomSheet(Locale locale) {
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
                                color: const Color(0xFFE0E0E0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _t('filterAndSort', locale),
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
                                child: Text(_t('clearAll', locale)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              children: [
                                _buildSortSection(productProvider, locale),
                                const Divider(height: 32),
                                _buildPriceRangeSection(
                                    productProvider, setModalState, locale),
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
                                child: Text(_t('applyFilters', locale)),
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

  Widget _buildSortSection(ProductProvider productProvider, Locale locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('sortBy', locale),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _buildSortOption(_t('name', locale), 'name', productProvider),
        _buildSortOption(
            _t('priceLowToHigh', locale), 'price_asc', productProvider),
        _buildSortOption(
            _t('priceHighToLow', locale), 'price_desc', productProvider),
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

  Widget _buildPriceRangeSection(ProductProvider productProvider,
      StateSetter setModalState, Locale locale) {
    double minPrice = productProvider.minPrice ?? 0;
    double maxPrice = productProvider.maxPrice ?? 10000000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('priceRange', locale),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Rp ${minPrice.toStringAsFixed(0)}'),
            const Spacer(),
            Text('Rp ${maxPrice.toStringAsFixed(0)}'),
          ],
        ),
        RangeSlider(
          values: RangeValues(minPrice, maxPrice),
          min: 0,
          max: 10000000,
          divisions: 100,
          labels: RangeLabels(
            'Rp ${minPrice.toStringAsFixed(0)}',
            'Rp ${maxPrice.toStringAsFixed(0)}',
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
