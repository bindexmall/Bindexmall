// ============================================================================
// WIDGET: ProductCard
// ============================================================================
// Kartu produk (gambar, nama, harga, badge diskon, tombol wishlist/add-to-cart)
// yang dipakai berulang di HomeScreen, CatalogScreen, DealsScreen, dsb.
//
// Catatan:
//  - Widget paling sering dipakai ulang di seluruh app — kalau tampilan kartu produk
//  -   perlu diubah secara global, cukup edit di sini.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../utils/currency_formatter.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isListView;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.isListView = false,
  });

  @override
  Widget build(BuildContext context) {
    return isListView ? _buildListCard(context) : _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final isWishlisted = productProvider.isInWishlist(product.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 13,
              child: Stack(
                children: [
                  Hero(
                    tag: 'product_${product.id}',
                    child: SizedBox.expand(
                      child: product.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported),
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                    ),
                  ),
                  // Wishlist button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          productProvider.toggleWishlist(product);
                        },
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            isWishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: isWishlisted ? Colors.red : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Discount badge
                  if (product.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '-${product.discountPercentage}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Stock badge
                  if (!product.inStock)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Info
            Expanded(
              flex: 18,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name - Fixed height
                    SizedBox(
                      height: 37, // Space for 2 lines of text
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Price section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Regular price (crossed out) if discount
                              if (product.hasDiscount &&
                                  product.regularPrice != null)
                                Text(
                                  CurrencyFormatter.format(product.regularPrice!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    decoration: TextDecoration.lineThrough,
                                    height: 1.2,
                                  ),
                                ),
                              // Current price
                              Text(
                                CurrencyFormatter.format(product.price),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                          // Add to cart button - always visible at bottom
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildAddToCartButton(context),
                          ),
                        ],
                      ),
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

  Widget _buildListCard(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final isWishlisted = productProvider.isInWishlist(product.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Hero(
                tag: 'product_${product.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          ),
                        )
                      : Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isWishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isWishlisted ? Colors.red : null,
                          ),
                          onPressed: () {
                            productProvider.toggleWishlist(product);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (product.shortDescription != null &&
                        product.shortDescription!.isNotEmpty)
                      Text(
                        product.shortDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.hasDiscount &&
                                  product.regularPrice != null)
                                Text(
                                  CurrencyFormatter.format(product.regularPrice!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                CurrencyFormatter.format(product.price),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildAddToCartButton(context),
                      ],
                    ),
                    if (!product.inStock)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Colors.red[900],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddToCartButton(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    return Material(
      color: product.inStock
          ? Theme.of(context).colorScheme.primary
          : Colors.grey[300],
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: product.inStock
            ? () async {
                try {
                  await cartProvider.addProduct(product, quantity: 1);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to cart'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.add_shopping_cart,
            size: 20,
            color: product.inStock ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}