// ============================================================================
// SERVICE: LiveSettingsService
// ============================================================================
// Fetch pengaturan live streaming dari endpoint custom WordPress:
// GET /wp-json/bindexmall/v1/live-settings
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh LiveSettingsProvider. baseUrl di-inject lewat constructor (lihat main.dart).
// ============================================================================

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/live_settings.dart';

class LiveSettingsService {
  final String baseUrl;

  LiveSettingsService({required this.baseUrl});

  Future<LiveSettings> fetchLiveSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wp-json/bindexmall/v1/live-settings'),
      );

      if (response.statusCode == 200) {
        return LiveSettings.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load live settings');
      }
    } catch (e) {
      throw Exception('Error fetching live settings: $e');
    }
  }
}