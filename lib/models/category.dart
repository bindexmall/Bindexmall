// ============================================================================
// MODEL: Category
// ============================================================================
// Kategori produk WooCommerce (id, nama, slug, parent, jumlah produk, gambar).
//
// Isi/tanggung jawab utama:
//  - Diambil dari WooCommerce REST API lewat CategoryRepository.
// ============================================================================

class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String imageUrl;
  final int? parent;
  final int count;
  final String? display;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.imageUrl,
    this.parent,
    this.count = 0,
    this.display,
  });

  // Factory constructor from WooCommerce API
  factory Category.fromWooCommerce(Map<String, dynamic> json) {
    // Extract image
    String imageUrl = '';
    if (json['image'] != null && json['image']['src'] != null) {
      imageUrl = json['image']['src'] as String;
    }

    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Category',
      slug: json['slug'] ?? '',
      description: json['description']?.toString(),
      imageUrl: imageUrl,
      parent: json['parent'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
      display: json['display'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'image_url': imageUrl,
      'parent': parent,
      'count': count,
      'display': display,
    };
  }

  // From JSON (for local storage)
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'] ?? '',
      parent: json['parent'],
      count: json['count'] ?? 0,
      display: json['display'],
    );
  }

  // Copy with method
  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? imageUrl,
    int? parent,
    int? count,
    String? display,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      parent: parent ?? this.parent,
      count: count ?? this.count,
      display: display ?? this.display,
    );
  }

  // Check if this is a top-level category
  bool get isTopLevel => parent == null || parent == 0;

  // Check if category has products
  bool get hasProducts => count > 0;
}
