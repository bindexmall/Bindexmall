// ============================================================================
// MODEL: ProductVideo
// ============================================================================
// Metadata video produk (video upload sendiri / YouTube / Vimeo) untuk galeri produk.
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh widgets/product_gallery_video_player.dart.
//  - Lihat catatan riwayat bug di file tersebut soal video self-hosted yang butuh
//  -   header User-Agent/Referer agar tidak diblok hotlink protection.
// ============================================================================

import 'package:flutter/material.dart';

/// Represents one entry from WoodMart's native "Product gallery video"
/// (post meta key: woodmart_wc_video_gallery, exposed via REST as
/// `gallery_video`, keyed by an internal video id).
class ProductVideo {
  final String id;
  final String videoType; // 'youtube' | 'vimeo' | 'upload'
  final String? uploadVideoUrl;
  final String? youtubeUrl;
  final String? vimeoUrl;
  final bool autoplay;
  final String videoSize; // 'contain' | 'cover'
  final bool hideGalleryImg;
  final bool muted;

  const ProductVideo({
    required this.id,
    required this.videoType,
    this.uploadVideoUrl,
    this.youtubeUrl,
    this.vimeoUrl,
    this.autoplay = false,
    this.videoSize = 'contain',
    this.hideGalleryImg = false,
    this.muted = false,
  });

  factory ProductVideo.fromJson(String id, Map<String, dynamic> json) {
    return ProductVideo(
      id: id,
      videoType: (json['video_type'] ?? '').toString(),
      uploadVideoUrl: _emptyToNull(json['upload_video_url']),
      youtubeUrl: _emptyToNull(json['youtube_url']),
      vimeoUrl: _emptyToNull(json['vimeo_url']),
      autoplay: json['autoplay']?.toString() == '1',
      videoSize: (json['video_size'] ?? 'contain').toString(),
      hideGalleryImg: json['hide_gallery_img']?.toString() == '1',
      muted: (json['audio_status']?.toString() ?? 'unmute') == 'mute',
    );
  }

  static String? _emptyToNull(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  bool get isYoutube => videoType == 'youtube';
  bool get isVimeo => videoType == 'vimeo';
  bool get isSelfHosted => videoType == 'upload';

  /// The relevant source URL for whichever provider this video uses.
  String? get sourceUrl {
    if (isYoutube) return youtubeUrl;
    if (isVimeo) return vimeoUrl;
    return uploadVideoUrl;
  }

  bool get isValid => sourceUrl != null && sourceUrl!.isNotEmpty;

  String? get youtubeId {
    final url = youtubeUrl;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return uri.queryParameters['v'];
  }

  String? get vimeoId {
    final url = vimeoUrl;
    if (url == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(url);
    return match?.group(1);
  }

  /// Static preview image we can show before the player loads.
  /// Only YouTube has a free static-thumbnail endpoint; Vimeo/self-hosted
  /// fall back to the product's own image (passed in by the caller).
  String? get thumbnailUrl {
    final id = youtubeId;
    if (isYoutube && id != null) {
      return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    }
    return null;
  }

  BoxFit get boxFit => videoSize == 'cover' ? BoxFit.cover : BoxFit.contain;

  Map<String, dynamic> toJson() => {
        'video_type': videoType,
        'upload_video_url': uploadVideoUrl ?? '',
        'youtube_url': youtubeUrl ?? '',
        'vimeo_url': vimeoUrl ?? '',
        'autoplay': autoplay ? '1' : '0',
        'video_size': videoSize,
        'hide_gallery_img': hideGalleryImg ? '1' : '0',
        'audio_status': muted ? 'mute' : 'unmute',
      };
}
