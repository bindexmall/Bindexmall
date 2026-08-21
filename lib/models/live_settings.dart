// ============================================================================
// MODEL: LiveSettings
// ============================================================================
// Konfigurasi fitur live streaming/live shopping (mis. status on/off, URL stream).
//
// Isi/tanggung jawab utama:
//  - Diambil dari endpoint custom WordPress: /wp-json/bindexmall/v1/live-settings
//  -   (lihat services/live_settings_service.dart).
// ============================================================================

class LiveSettings {
  final bool isLive;
  final String liveType;
  final String tiktokUrl;
  final String youtubeUrl;
  final bool showButton;

  LiveSettings({
    required this.isLive,
    required this.liveType,
    required this.tiktokUrl,
    required this.youtubeUrl,
    required this.showButton,
  });

  factory LiveSettings.fromJson(Map<String, dynamic> json) {
    return LiveSettings(
      isLive: json['is_live'] ?? false,
      liveType: json['live_type'] ?? 'tiktok',
      tiktokUrl: json['tiktok_url'] ?? '',
      youtubeUrl: json['youtube_url'] ?? '',
      showButton: json['show_button'] ?? true,
    );
  }
}