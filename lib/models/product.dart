// ============================================================================
// MODEL: Product
// ============================================================================
// Model produk utama — hasil mapping dari WooCommerce REST API (wc/v3/products).
//
// Isi/tanggung jawab utama:
//  - Field penting: id, name, slug, price/regular_price/sale_price, images, stock_status,
//  -   categories, tags, description, variations (kalau produk punya varian).
//  - Model paling sering dipakai di seluruh app (catalog, home, detail, cart, wishlist).
//  - Kalau WooCommerce menambah field baru yang perlu ditampilkan, mulai dari sini.
// ============================================================================

import 'product_video.dart';

class Product {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? shortDescription;
  final double price;
  final double? regularPrice;
  final double? salePrice;
  final bool onSale;
  final String imageUrl;
  final List<String> images;
  final String category;
  final List<String> categories;
  final List<int> categoryIds;
  final String? sku;
  final bool inStock;
  final int? stockQuantity;
  final bool manageStock;
  final String stockStatus;
  final double? weight;
  final Map<String, dynamic>? dimensions;
  final List<Map<String, dynamic>>? attributes;
  final double averageRating;
  final int ratingCount;
  final DateTime dateCreated;
  final DateTime dateModified;
  final int moq; // ✅ ADDED - Minimum Order Quantity, 0 = tidak ada MOQ
  final List<ProductVideo> videos; // ✅ ADDED - video galeri produk (WoodMart)

  Product({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.shortDescription,
    required this.price,
    this.regularPrice,
    this.salePrice,
    this.onSale = false,
    required this.imageUrl,
    this.images = const [],
    required this.category,
    this.categories = const [],
    this.categoryIds = const [],
    this.sku,
    this.inStock = true,
    this.stockQuantity,
    this.manageStock = false,
    this.stockStatus = 'instock',
    this.weight,
    this.dimensions,
    this.attributes,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    required this.dateCreated,
    required this.dateModified,
    this.moq = 0, // ✅ ADDED
    this.videos = const [], // ✅ ADDED
  });

  factory Product.fromWooCommerce(Map<String, dynamic> json) {
    final List<dynamic> imagesList = json['images'] ?? [];
    final List<String> images = imagesList
        .map((img) => img['src'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();

    final List<dynamic> categoriesList = json['categories'] ?? [];
    final List<String> categories = categoriesList
        .map((cat) => cat['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    final List<int> categoryIds = categoriesList
        .map((cat) => cat['id'] as int? ?? 0)
        .where((id) => id > 0)
        .toList();

    final double price = _parsePrice(json['price']) ?? 0.0;
    final double? regularPrice = _parsePrice(json['regular_price']);
    final double? salePrice = _parsePrice(json['sale_price']);

    final String stockStatus = json['stock_status']?.toString() ?? 'instock';
    final bool manageStock = json['manage_stock'] as bool? ?? false;
    final int? stockQuantity = json['stock_quantity'] as int?;

    bool inStock;
    if (manageStock) {
      inStock = (stockQuantity ?? 0) > 0;
    } else {
      inStock = stockStatus == 'instock';
    }

    // ✅ ADDED

    Map<String, dynamic>? dimensions;
    if (json['dimensions'] != null) {
      dimensions = {
        'length': json['dimensions']['length'] ?? '',
        'width': json['dimensions']['width'] ?? '',
        'height': json['dimensions']['height'] ?? '',
      };
    }

    List<Map<String, dynamic>>? attributes;
    if (json['attributes'] != null && json['attributes'] is List) {
      attributes = (json['attributes'] as List)
          .map((attr) => {
                'name': attr['name'] ?? '',
                'options': attr['options'] ?? [],
              })
          .toList();
    }

    DateTime dateCreated;
    try {
      dateCreated = DateTime.parse(
          json['date_created'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      dateCreated = DateTime.now();
    }

    DateTime dateModified;
    try {
      dateModified = DateTime.parse(
          json['date_modified'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      dateModified = DateTime.now();
    }

    // ✅ ADDED - parse field custom 'gallery_video' (di-expose lewat
    // register_rest_field dari meta woodmart_wc_video_gallery)
    List<ProductVideo> videos = [];
    final rawGalleryVideo = json['gallery_video'];
    if (rawGalleryVideo is Map) {
      videos = rawGalleryVideo.entries
          .map((entry) => ProductVideo.fromJson(
                entry.key.toString(),
                Map<String, dynamic>.from(entry.value as Map),
              ))
          .where((v) => v.isValid)
          .toList();
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Product',
      slug: json['slug'] as String?, // ✅ ADDED - Map slug from WooCommerce
      description: _stripHtmlTags(json['description'] ?? ''),
      shortDescription: _stripHtmlTags(json['short_description'] ?? ''),
      price: price,
      regularPrice: regularPrice,
      salePrice: salePrice,
      onSale: json['on_sale'] as bool? ?? false,
      imageUrl: images.isNotEmpty ? images.first : '',
      images: images,
      category: categories.isNotEmpty ? categories.first : 'Uncategorized',
      categories: categories,
      categoryIds: categoryIds,
      sku: json['sku'] as String?,
      inStock: inStock,
      stockQuantity: stockQuantity,
      manageStock: manageStock,
      stockStatus: stockStatus,
      weight: json['weight'] != null
          ? double.tryParse(json['weight'].toString())
          : null,
      dimensions: dimensions,
      attributes: attributes,
      averageRating:
          double.tryParse(json['average_rating']?.toString() ?? '0') ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      dateCreated: dateCreated,
      dateModified: dateModified,
      // ✅ ADDED - field custom dari plugin wc-moq-per-product (register_rest_field)
      moq: (json['moq'] as num?)?.toInt() ?? 0,
      videos: videos, // ✅ ADDED
    );
  }

  /// Safely parse a price string from WooCommerce.
  /// Handles formats: "460800", "460.800", "460,800", "460800.00"
  static double? _parsePrice(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    // Remove currency symbols / spaces
    var clean = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (clean.isEmpty) return null;

    // Detect format: if last separator is ',' and it has 3 digits after → thousand sep
    // e.g. "460.800" or "460,800" → 460800
    // e.g. "460.80"  or "460,80"  → 460.80 (decimal)
    final dotIdx = clean.lastIndexOf('.');
    final commaIdx = clean.lastIndexOf(',');

    if (dotIdx > commaIdx) {
      // dot is decimal separator → remove commas (thousand sep)
      clean = clean.replaceAll(',', '');
      // if dot has exactly 3 trailing digits it's likely thousand sep
      if (dotIdx != -1 &&
          clean.length - dotIdx - 1 == 3 &&
          !clean.contains('.', dotIdx + 1)) {
        // ambiguous: WooCommerce always stores as plain number, treat dot as thousand sep
        clean = clean.replaceAll('.', '');
      }
    } else if (commaIdx > dotIdx) {
      // comma is decimal separator → remove dots (thousand sep), replace comma with dot
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // no separator or only one type — remove all dots/commas if purely numeric
      clean = clean.replaceAll(',', '').replaceAll('.', '');
    }

    return double.tryParse(clean);
  }

  static String _stripHtmlTags(String htmlString) {
    if (htmlString.isEmpty) return '';

    final RegExp exp =
        RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlString
        .replaceAll(exp, '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug, // ✅ ADDED
      'description': description,
      'short_description': shortDescription,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'on_sale': onSale,
      'image_url': imageUrl,
      'images': images,
      'category': category,
      'categories': categories,
      'category_ids': categoryIds,
      'sku': sku,
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'manage_stock': manageStock,
      'stock_status': stockStatus,
      'weight': weight,
      'dimensions': dimensions,
      'attributes': attributes,
      'average_rating': averageRating,
      'rating_count': ratingCount,
      'date_created': dateCreated.toIso8601String(),
      'date_modified': dateModified.toIso8601String(),
      'moq': moq, // ✅ ADDED
      'videos': videos.map((v) => {'id': v.id, ...v.toJson()}).toList(), // ✅ ADDED
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'], // ✅ ADDED
      description: json['description'],
      shortDescription: json['short_description'],
      price: json['price']?.toDouble() ?? 0.0,
      regularPrice: json['regular_price']?.toDouble(),
      salePrice: json['sale_price']?.toDouble(),
      onSale: json['on_sale'] ?? false,
      imageUrl: json['image_url'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      category: json['category'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      categoryIds: List<int>.from(json['category_ids'] ?? []),
      sku: json['sku'],
      inStock: json['in_stock'] ?? true,
      stockQuantity: json['stock_quantity'],
      manageStock: json['manage_stock'] ?? false,
      stockStatus: json['stock_status'] ?? 'instock',
      weight: json['weight']?.toDouble(),
      dimensions: json['dimensions'] != null
          ? Map<String, dynamic>.from(json['dimensions'])
          : null,
      attributes: json['attributes'] != null
          ? List<Map<String, dynamic>>.from(json['attributes'])
          : null,
      averageRating: json['average_rating']?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] ?? 0,
      dateCreated: DateTime.parse(
          json['date_created'] ?? DateTime.now().toIso8601String()),
      dateModified: DateTime.parse(
          json['date_modified'] ?? DateTime.now().toIso8601String()),
      moq: (json['moq'] as num?)?.toInt() ?? 0, // ✅ ADDED
      videos: json['videos'] != null // ✅ ADDED
          ? (json['videos'] as List)
              .map((v) => ProductVideo.fromJson(
                  v['id']?.toString() ?? '', Map<String, dynamic>.from(v)))
              .toList()
          : const [],
    );
  }

  // Copy with method
  Product copyWith({
    String? id,
    String? name,
    String? slug, // ✅ ADDED
    String? description,
    String? shortDescription,
    double? price,
    double? regularPrice,
    double? salePrice,
    bool? onSale,
    String? imageUrl,
    List<String>? images,
    String? category,
    List<String>? categories,
    List<int>? categoryIds,
    String? sku,
    bool? inStock,
    int? stockQuantity,
    bool? manageStock,
    String? stockStatus,
    double? weight,
    Map<String, dynamic>? dimensions,
    List<Map<String, dynamic>>? attributes,
    double? averageRating,
    int? ratingCount,
    DateTime? dateCreated,
    DateTime? dateModified,
    int? moq, // ✅ ADDED
    List<ProductVideo>? videos, // ✅ ADDED
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug, // ✅ ADDED
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      price: price ?? this.price,
      regularPrice: regularPrice ?? this.regularPrice,
      salePrice: salePrice ?? this.salePrice,
      onSale: onSale ?? this.onSale,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      categoryIds: categoryIds ?? this.categoryIds,
      sku: sku ?? this.sku,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      manageStock: manageStock ?? this.manageStock,
      stockStatus: stockStatus ?? this.stockStatus,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      attributes: attributes ?? this.attributes,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      moq: moq ?? this.moq, // ✅ ADDED
      videos: videos ?? this.videos, // ✅ ADDED
    );
  }

  // ✅ ADDED - ada video di galeri produk ini gak
  bool get hasVideo => videos.isNotEmpty;

  // ✅ ADDED - helper getter, MOQ efektif (minimal 1 walau moq belum diisi)
  int get effectiveMinQty => moq > 1 ? moq : 1;

  bool get hasMoq => moq > 1;

  String get displayPrice => 'Rp ${price.toStringAsFixed(0)}';
  String get displayRegularPrice =>
      regularPrice != null ? 'Rp ${regularPrice!.toStringAsFixed(0)}' : '';
  bool get hasDiscount =>
      onSale &&
      salePrice != null &&
      regularPrice != null &&
      salePrice! < regularPrice!;
  int get discountPercentage {
    if (!hasDiscount || regularPrice == null || salePrice == null) return 0;
    return (((regularPrice! - salePrice!) / regularPrice!) * 100).round();
  }

  bool get isAvailable {
    if (manageStock) {
      return (stockQuantity ?? 0) > 0;
    } else {
      return stockStatus == 'instock';
    }
  }

  String get stockDisplayText {
    if (manageStock && stockQuantity != null) {
      return stockQuantity! > 0 ? 'In Stock ($stockQuantity)' : 'Out of Stock';
    } else {
      return stockStatus == 'instock' ? 'In Stock' : 'Out of Stock';
    }
  }
}