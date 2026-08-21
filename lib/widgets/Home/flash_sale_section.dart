// ============================================================================
// WIDGET: FlashSaleSection + _CountdownChip
// ============================================================================
// Section 'Flash Sale' di HomeScreen dengan countdown timer (_CountdownChip)
// sampai promo berakhir.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/language_provider.dart';
import '../../repositories/product_repository.dart';
import '../../l10n/app_localizations.dart';

class FlashSaleSection extends StatefulWidget {
  /// End time for the flash sale countdown.
  /// Defaults to end-of-day if not provided.
  final DateTime? saleEndTime;

  const FlashSaleSection({super.key, this.saleEndTime});

  @override
  State<FlashSaleSection> createState() => _FlashSaleSectionState();
}

class _FlashSaleSectionState extends State<FlashSaleSection> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  static final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _load();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    final now = DateTime.now();
    final endTime = widget.saleEndTime ??
        DateTime(now.year, now.month, now.day, 23, 59, 59);
    _remaining = endTime.difference(now);
    if (_remaining.isNegative) _remaining = Duration.zero;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 1) {
          _remaining = _remaining - const Duration(seconds: 1);
        } else if (_remaining.inSeconds == 1) {
          _remaining = Duration.zero;
          // Countdown habis → refresh produk & mulai countdown hari berikutnya
          _onCountdownFinished();
        }
      });
    });
  }

  /// Dipanggil saat countdown mencapai 0:
  /// refresh produk flash sale & mulai countdown untuk hari berikutnya
  Future<void> _onCountdownFinished() async {
    _countdownTimer?.cancel();

    // Reload produk flash sale terbaru
    await _load();

    // Reset countdown ke akhir hari berikutnya
    if (mounted) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final nextEnd =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59);
      setState(() {
        _remaining = nextEnd.difference(DateTime.now());
      });
      _startCountdown();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await productRepository.fetchProductsByTag('flash-sale');
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

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        final locale = langProvider.currentLocale;

        // Hide section if no sale products
        if (!_isLoading && (_error != null || _products.isEmpty)) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade700,
                Colors.red.shade500,
                Colors.orange.shade500,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.yellow, size: 26),
                        const SizedBox(width: 6),
                        Text(
                          _t('flashSale', locale),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _t('endsIn', locale),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CountdownChip(label: _pad(_remaining.inHours)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3),
                          child: Text(':',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        _CountdownChip(
                            label: _pad(_remaining.inMinutes.remainder(60))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3),
                          child: Text(':',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        _CountdownChip(
                            label: _pad(_remaining.inSeconds.remainder(60))),
                      ],
                    ),
                  ],
                ),
              ),
              // Products list
              SizedBox(
                height: 230,
                child: _isLoading
                    ? _buildSkeletonList()
                    : _buildProductList(locale),
              ),
              // See all button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  // child: OutlinedButton(
                  //   onPressed: () => Navigator.pushNamed(
                  //     context,
                  //     '/deals',
                  //   ),
                  //   style: OutlinedButton.styleFrom(
                  //     foregroundColor: Colors.white,
                  //     side: const BorderSide(color: Colors.white60),
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     padding: const EdgeInsets.symmetric(vertical: 12),
                  //   ),
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.center,
                  //     children: [
                  //       Text(
                  //         _t('seeAllDeals', locale),
                  //         style: const TextStyle(
                  //             fontWeight: FontWeight.w700, fontSize: 14),
                  //       ),
                  //       const SizedBox(width: 4),
                  //       const Icon(Icons.arrow_forward, size: 16),
                  //     ],
                  //   ),
                  // ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductList(Locale locale) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) =>
          _buildFlashCard(_products[index], locale),
    );
  }

  Widget _buildFlashCard(Product product, Locale locale) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/product-detail',
        arguments: product,
      ),
      child: Container(
        width: 145,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + discount badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          height: 118,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(height: 118, color: Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(
                            height: 118,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 118,
                          color: Colors.grey[200],
                          child: const Icon(Icons.shopping_bag,
                              color: Colors.grey, size: 40),
                        ),
                ),
                if (product.hasDiscount)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        '-${product.discountPercentage}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
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
                                    content: Text(_t('addedToCart', locale)),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                size: 13,
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

  Widget _buildSkeletonList() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Container(
        width: 145,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              height: 118,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, color: Colors.white.withOpacity(0.4)),
                  const SizedBox(height: 6),
                  Container(
                      height: 10,
                      width: 60,
                      color: Colors.white.withOpacity(0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Countdown chip widget ────────────────────────────────────────────────────

class _CountdownChip extends StatelessWidget {
  final String label;
  const _CountdownChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
