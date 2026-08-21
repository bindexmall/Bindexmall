// ============================================================================
// MODEL: PromoBanner
// ============================================================================
// Data banner promo yang tampil di carousel home screen.
//
// Isi/tanggung jawab utama:
//  - Diambil dari endpoint custom: /wp-json/bindexmall/v1/promo-banners
//  -   (lihat repositories/promo_banner_repository.dart).
// ============================================================================

// lib/models/promo_banner.dart
class PromoBanner {
  final int id;
  final String title;
  final String imageUrl;
  final String linkType; // none, product, category, url, webview
  final String? linkValue;

  PromoBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkType,
    this.linkValue,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    try {
      return PromoBanner(
        id: _parseId(json['id']),
        title: json['title']?.toString() ?? '',
        imageUrl: json['image_url']?.toString() ?? json['image']?.toString() ?? '',
        linkType: json['link_type']?.toString() ?? 'none',
        linkValue: json['link_value']?.toString(),
      );
    } catch (e) {
      rethrow;
    }
  }

  static int _parseId(dynamic id) {
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'link_type': linkType,
      'link_value': linkValue,
    };
  }

  // Helper untuk validasi
  bool get isValid => id > 0 && imageUrl.isNotEmpty;
  bool get hasLink => linkType != 'none' && linkValue != null && linkValue!.isNotEmpty;

  @override
  String toString() {
    return 'PromoBanner(id: $id, title: $title, linkType: $linkType)';
  }
}