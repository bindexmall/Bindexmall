// ============================================================================
// SCREEN: WishlistScreen
// ============================================================================
// Daftar produk favorit/wishlist user, via ProductProvider (state wishlist digabung
//
// Catatan:
//  - ke ProductProvider, bukan provider terpisah — lihat providers/product_provider.dart).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/product_card.dart';
import '../l10n/app_localizations.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('myWishlist', locale)),
            actions: [
              Consumer<ProductProvider>(
                builder: (context, productProvider, child) {
                  if (productProvider.wishlist.isEmpty) return const SizedBox();

                  return TextButton(
                    onPressed: () {
                      _showClearDialog(context, productProvider, locale);
                    },
                    child: Text(_t('clearAll', locale)),
                  );
                },
              ),
            ],
          ),
          body: Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              final wishlist = productProvider.wishlist;

              if (wishlist.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        locale.languageCode == 'en'
                            ? 'Your wishlist is empty'
                            : 'Wishlist Anda kosong',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locale.languageCode == 'en'
                            ? 'Add products you love to your wishlist'
                            : 'Tambahkan produk favorit Anda ke wishlist',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/categories');
                        },
                        icon: const Icon(Icons.shopping_bag),
                        label: Text(_t('startShopping', locale)),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: wishlist.length,
                itemBuilder: (context, index) {
                  return ProductCard(
                    product: wishlist[index],
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/product-detail',
                        arguments: wishlist[index],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showClearDialog(
    BuildContext context,
    ProductProvider productProvider,
    Locale locale,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          locale.languageCode == 'en'
              ? 'Clear Wishlist'
              : 'Kosongkan Wishlist'
        ),
        content: Text(
          locale.languageCode == 'en'
              ? 'Are you sure you want to remove all items from your wishlist?'
              : 'Apakah Anda yakin ingin menghapus semua item dari wishlist?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel', locale)),
          ),
          FilledButton(
            onPressed: () {
              productProvider.clearWishlist();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    locale.languageCode == 'en'
                        ? 'Wishlist cleared'
                        : 'Wishlist dikosongkan'
                  ),
                ),
              );
            },
            child: Text(
              locale.languageCode == 'en' ? 'Clear' : 'Kosongkan'
            ),
          ),
        ],
      ),
    );
  }
}