// ============================================================================
// WIDGET: NewArrivalsSection
// ============================================================================
// Section 'Produk Terbaru' di HomeScreen — list horizontal ProductCard dari
// ProductRepository.fetchLatestProducts().
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/language_provider.dart';
import '../../repositories/product_repository.dart';
import '../../l10n/app_localizations.dart';

class NewArrivalsSection extends StatefulWidget {
  const NewArrivalsSection({super.key});

  @override
  State<NewArrivalsSection> createState() => _NewArrivalsSectionState();
}

class _NewArrivalsSectionState extends State<NewArrivalsSection> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  static final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await productRepository.fetchLatestProducts();
      if (mounted) {
        setState(() {
          _products = products.take(10).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _t(String key, Locale locale) =>
      AppLocalizations(locale).translate(key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        final locale = langProvider.currentLocale;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _t('newArrivals', locale),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _t('new', locale),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _t('justLanded', locale),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/catalog',
                      arguments: {
                        'category': 'New Arrivals',
                        'categoryId': '',
                        'initialSort': 'date_desc',
                      },
                    ),
                    child: Row(
                      children: [
                        Text(
                          _t('seeAll', locale),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 240,
              child: _buildContent(locale),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(Locale locale) {
    if (_isLoading) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => _buildSkeleton(),
      );
    }

    if (_error != null || _products.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_t('retry', locale)),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) =>
          _buildCard(_products[index], locale),
    );
  }

  Widget _buildCard(Product product, Locale locale) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final isNew = DateTime.now().difference(product.dateCreated).inDays <= 14;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/product-detail',
        arguments: product,
      ),
      child: Container(
        width: 155,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              height: 130, color: Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(
                            height: 130,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 130,
                          color: Colors.grey[200],
                          child: const Icon(Icons.shopping_bag,
                              color: Colors.grey, size: 40),
                        ),
                ),
                if (isNew)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _t('new', locale),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (product.hasDiscount)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-${product.discountPercentage}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    if (product.hasDiscount)
                      Text(
                        _currencyFormatter.format(product.regularPrice),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _currencyFormatter.format(product.price),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (product.inStock)
                          GestureDetector(
                            onTap: () async {
                              await cartProvider.addProduct(product);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(_t('addedToCart', locale)),
                                    duration:
                                        const Duration(seconds: 1),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, color: Colors.grey[300]),
                const SizedBox(height: 6),
                Container(
                    height: 10, width: 80, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Container(
                    height: 14, width: 100, color: Colors.grey[300]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
