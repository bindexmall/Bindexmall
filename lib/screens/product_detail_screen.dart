// ============================================================================
// SCREEN: ProductDetailScreen + CurrencyFormatter (lokal)
// ============================================================================
// Halaman detail produk: galeri gambar/video (ProductGalleryVideoPlayer), deskripsi,
// varian produk, section review (ProductReviewSection), tombol add-to-cart/wishlist,
// share (ShareService), tracking analytics (AnalyticsService.logViewItem).
//
// Catatan:
//  - CurrencyFormatter di file ini adalah salinan LOKAL — ada juga utils/currency_formatter.dart.
//  -   Cek dua-duanya sebelum ubah format harga supaya tetap konsisten.
//  - File ini salah satu yang paling sering disentuh (lihat riwayat: fitur variasi produk,
//  -   bug video galeri) — baca dulu keseluruhan sebelum refactor besar.
// ============================================================================

import 'package:bindexmall/widgets/share_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../models/product_video.dart'; // ✅ ADDED
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/language_provider.dart';
import '../providers/review_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/product_review_section.dart';
import '../widgets/product_gallery_video_player.dart'; // ✅ ADDED

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(double amount) {
    return _formatter.format(amount);
  }

  static String formatInt(int amount) {
    return _formatter.format(amount);
  }

  static String formatWithoutSymbol(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    return formatter.format(amount).trim();
  }

  static double parse(String rupiahString) {
    final cleanString = rupiahString
        .replaceAll('Rp', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleanString) ?? 0.0;
  }

  static String formatCustom(double amount, {String symbol = 'Rp '}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: symbol,
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late int _quantity; // ✅ CHANGED - was final, now mutable + MOQ-aware
  int _currentImageIndex = 0;
  bool _isAddingToCart = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // ✅ ADDED - qty awal langsung ikut MOQ produk, bukan selalu 1
    _quantity = widget.product.effectiveMinQty;
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ✅ ADDED - naik/turun qty tapi gak boleh di bawah MOQ
  void _incrementQuantity() {
    setState(() => _quantity++);
  }

  void _decrementQuantity() {
    final minQty = widget.product.effectiveMinQty;
    if (_quantity > minQty) {
      setState(() => _quantity--);
    }
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  // ✅ ADDED - thumbnail kecil buat item video di strip bawah galeri
  Widget _buildVideoThumbnail(ProductVideo video, bool isDarkMode) {
    final thumb = video.thumbnailUrl ?? widget.product.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb != null && thumb.toString().isNotEmpty)
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
            ),
          )
        else
          Container(color: isDarkMode ? Colors.grey[850] : Colors.grey[200]),
        Container(color: Colors.black26),
        const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
        ),
      ],
    );
  }

  void _onImageGalleryTap(int index) {
    setState(() {
      _currentImageIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        final productProvider = context.watch<ProductProvider>();
        final isWishlisted = productProvider.isInWishlist(widget.product.id);
        final isDarkMode = Theme.of(context).brightness == Brightness.dark; // ✅ TAMBAHKAN

        return Scaffold(
          backgroundColor: isDarkMode 
              ? Theme.of(context).scaffoldBackgroundColor 
              : const Color(0xFFE7DED7), // ✅ UBAH
          appBar: AppBar(
            backgroundColor: isDarkMode 
                ? Theme.of(context).appBarTheme.backgroundColor 
                : const Color(0xFFE7DED7), // ✅ UBAH
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios,
                color: isDarkMode ? Colors.white : Colors.black, // ✅ UBAH
              ),
            ),
            actions: [
              ShareButton(product: widget.product),
              IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
                icon: Icon(
                  Icons.shopping_bag_outlined,
                  color: isDarkMode ? Colors.white : Colors.black, // ✅ UBAH
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // ✅ MAIN PRODUCT IMAGE WITH CACHED NETWORK IMAGE
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                padding: const EdgeInsets.only(bottom: 30),
                width: double.infinity,
                color: isDarkMode 
                    ? Colors.grey[900] 
                    : const Color(0xFFE7DED7), // ✅ TAMBAHKAN
                child: (widget.product.images.isNotEmpty || widget.product.hasVideo)
                    ? PageView.builder(
                        controller: _pageController,
                        // ✅ UBAH - video di depan (slide pertama), gambar nyusul
                        itemCount: widget.product.images.length +
                            widget.product.videos.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          // ✅ UBAH - video duluan (index 0..videos.length-1)
                          if (index < widget.product.videos.length) {
                            final video = widget.product.videos[index];
                            return ProductGalleryVideoPlayer(
                              video: video,
                              fallbackThumbnailUrl: widget.product.imageUrl,
                              isDarkMode: isDarkMode,
                            );
                          }
                          final imageIndex = index - widget.product.videos.length;
                          return CachedNetworkImage(
                            imageUrl: widget.product.images[imageIndex],
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(
                              color: isDarkMode ? Colors.grey[850] : Colors.grey[200], // ✅ UBAH
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 100,
                                color: isDarkMode ? Colors.grey[700] : Colors.grey, // ✅ UBAH
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 100,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey, // ✅ UBAH
                        ),
                      ),
              ),

              // Draggable Bottom Sheet Content
              DraggableScrollableSheet(
                initialChildSize: 0.55,
                minChildSize: 0.45,
                maxChildSize: 0.95,
                controller: _sheetController,
                builder: (BuildContext context, ScrollController scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor, // ✅ UBAH
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag Handle
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 16),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[700] : Colors.grey[300], // ✅ UBAH
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category
                                Text(
                                  widget.product.category.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey, // ✅ UBAH
                                  ),
                                ),

                                // Product Name and Price
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.product.name,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).textTheme.bodyLarge?.color, // ✅ TAMBAHKAN
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (widget.product.hasDiscount &&
                                            widget.product.regularPrice != null) ...[
                                          Row(
                                            children: [
                                              Text(
                                                CurrencyFormatter.format(
                                                    widget.product.regularPrice!),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDarkMode ? Colors.grey[500] : Colors.grey, // ✅ UBAH
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '-${widget.product.discountPercentage}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          CurrencyFormatter.format(widget.product.price),
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).textTheme.bodyLarge?.color, // ✅ TAMBAHKAN
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 15),

                                // Stock Badge
                                _buildStockBadge(locale),

                                const SizedBox(height: 15),

                                // Rating
                                if (widget.product.ratingCount > 0)
                                  Row(
                                    children: [
                                      ...List.generate(5, (index) {
                                        if (index < widget.product.averageRating.floor()) {
                                          return const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 18,
                                          );
                                        } else if (index < widget.product.averageRating) {
                                          return const Icon(
                                            Icons.star_half,
                                            color: Colors.amber,
                                            size: 18,
                                          );
                                        } else {
                                          return Icon(
                                            Icons.star_border,
                                            color: isDarkMode ? Colors.grey[600] : Colors.grey, // ✅ UBAH
                                            size: 18,
                                          );
                                        }
                                      }),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${widget.product.averageRating.toStringAsFixed(1)} (${widget.product.ratingCount} ${locale.languageCode == 'en' ? 'reviews' : 'ulasan'})',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey, // ✅ UBAH
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 20),

                                // ✅ IMAGE + VIDEO GALLERY THUMBNAILS
                                if (widget.product.images.length +
                                        widget.product.videos.length >
                                    1)
                                  SizedBox(
                                    height: 80,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: widget.product.images.length +
                                          widget.product.videos.length, // ✅ UBAH
                                      itemBuilder: (context, index) {
                                        final isSelected = index == _currentImageIndex;
                                        final isVideo = index <
                                            widget.product.videos.length; // ✅ UBAH - video di depan
                                        return GestureDetector(
                                          onTap: () => _onImageGalleryTap(index),
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            margin: const EdgeInsets.only(right: 10),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isSelected
                                                    ? Theme.of(context).colorScheme.primary
                                                    : (isDarkMode ? Colors.grey[700]! : Colors.grey.shade300), // ✅ UBAH
                                                width: isSelected ? 2 : 1,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(7),
                                              child: isVideo // ✅ UBAH - thumbnail video di depan
                                                  ? _buildVideoThumbnail(
                                                      widget.product.videos[index],
                                                      isDarkMode,
                                                    )
                                                  : CachedNetworkImage(
                                                      imageUrl: widget.product.images[
                                                          index - widget.product.videos.length],
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Container(
                                                        color: isDarkMode ? Colors.grey[850] : Colors.grey[200], // ✅ UBAH
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          ),
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) => Icon(
                                                        Icons.broken_image,
                                                        color: isDarkMode ? Colors.grey[700] : Colors.grey, // ✅ UBAH
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                const SizedBox(height: 20),

                                // ✅ ADDED - Quantity Selector + MOQ Notice
                                if (widget.product.hasMoq)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3CD),
                                      border: Border.all(
                                          color: const Color(0xFFFFC107)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('📦', style: TextStyle(fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            locale.languageCode == 'en'
                                                ? 'Minimum order: ${widget.product.moq} items'
                                                : 'Minimum Pembelian: ${widget.product.moq} item',
                                            style: const TextStyle(
                                              color: Color(0xFF856404),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Text(
                                      locale.languageCode == 'en' ? 'Quantity' : 'Jumlah',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: isDarkMode
                                                ? Colors.grey[700]!
                                                : const Color(0xFFDCDDE2)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 18),
                                            onPressed: _decrementQuantity,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                                minWidth: 32, minHeight: 32),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              '$_quantity',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 18),
                                            onPressed: _incrementQuantity,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                                minWidth: 32, minHeight: 32),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Description Title
                                Text(
                                  _t('description', locale),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge?.color, // ✅ TAMBAHKAN
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Description Content
                                Text(
                                  widget.product.description ??
                                      widget.product.shortDescription ??
                                      (locale.languageCode == 'en'
                                          ? 'No description available'
                                          : 'Tidak ada deskripsi tersedia'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey, // ✅ UBAH
                                    height: 1.5,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Specifications
                                if (widget.product.weight != null ||
                                    widget.product.dimensions != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('specifications', locale),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).textTheme.bodyLarge?.color, // ✅ TAMBAHKAN
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (widget.product.weight != null)
                                        _buildSpecRow(
                                          _t('weight', locale),
                                          '${widget.product.weight} g',
                                        ),
                                    ],
                                  ),

                                // Review Section
                                if (widget.product.ratingCount > 0)
                                  ChangeNotifierProvider(
                                    create: (_) => ReviewProvider(),
                                    child: ProductReviewSection(
                                      productId: int.parse(widget.product.id),
                                      productName: widget.product.name,
                                      averageRating: widget.product.averageRating,
                                      ratingCount: widget.product.ratingCount,
                                    ),
                                  ),

                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: Container(
            height: 70,
            color: Theme.of(context).cardColor, // ✅ UBAH
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Wishlist Button
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode 
                          ? Colors.grey[700]! 
                          : const Color(0xFFDCDDE2), // ✅ UBAH
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      productProvider.toggleWishlist(widget.product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isWishlisted
                                ? _t('removedFromWishlist', locale)
                                : _t('addedToWishlist', locale),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: Icon(
                      isWishlisted ? Icons.favorite : Icons.favorite_border,
                      size: 30,
                      color: isWishlisted ? Colors.red : (isDarkMode ? Colors.grey[400] : Colors.grey), // ✅ UBAH
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Add to Cart Button
                Expanded(
                  child: InkWell(
                    onTap: _isAddingToCart || !widget.product.isAvailable
                        ? null
                        : () async {
                            setState(() {
                              _isAddingToCart = true;
                            });

                            try {
                              final cartProvider = context.read<CartProvider>();
                              await cartProvider.addProduct(
                                widget.product,
                                quantity: _quantity,
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      locale.languageCode == 'en'
                                          ? 'Added ${widget.product.name} to cart'
                                          : '${widget.product.name} ditambahkan ke keranjang',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: locale.languageCode == 'en' ? 'VIEW CART' : 'LIHAT KERANJANG',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/cart');
                                      },
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${locale.languageCode == 'en' ? 'Error' : 'Kesalahan'}: ${e.toString()}'
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isAddingToCart = false;
                                });
                              }
                            }
                          },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.product.isAvailable 
                            ? Theme.of(context).colorScheme.primary 
                            : (isDarkMode ? Colors.grey[800] : Colors.grey), // ✅ UBAH
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: _isAddingToCart
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              widget.product.isAvailable
                                  ? _t('addToCart', locale)
                                  : _t('outOfStock', locale),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockBadge(Locale locale) {
    final isAvailable = widget.product.isAvailable;
    final stockText = locale.languageCode == 'en'
        ? widget.product.stockDisplayText
        : (isAvailable ? 'Tersedia' : 'Stok Habis');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAvailable
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isAvailable ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            stockText,
            style: TextStyle(
              color: isAvailable ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey, // ✅ UBAH
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyLarge?.color, // ✅ TAMBAHKAN
            ),
          ),
        ],
      ),
    );
  }
}