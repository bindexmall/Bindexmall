// ============================================================================
// SERVICE: RajaOngkirService / Province / City / District / Subdistrict / ShippingRate
// ============================================================================
// Integrasi kalkulasi ongkos kirim via RajaOngkir (Komerce API): wilayah berjenjang
// (provinsi/kota/kecamatan/kelurahan) dan kalkulasi tarif pengiriman antar kurir.
//
// Isi/tanggung jawab utama:
//  - apiKey sekarang diambil dari config/secrets.dart (di-gitignore). Risiko key ini
//    bocor lebih rendah dibanding Midtrans/WooCommerce (paling banter kuota dipakai
//    orang lain), tapi tetap lebih baik ga nangkring polos di source code.
//  - _cache di dalam service ini nyimpen hasil request per sesi app (hilang saat app ditutup)
//  -   — clearCache() dipanggil manual kalau perlu paksa refresh.
//  - Dipakai oleh ShippingProvider — alur pemilihan wilayah harus berjenjang sesuai urutan
//  -   method (province -> city -> district -> subdistrict) karena masing-masing butuh ID induk.
// ============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/secrets.dart';

class RajaOngkirService {
  // ✅ CORRECT BASE URL
  static const String baseUrl = 'https://rajaongkir.komerce.id/api/v1';
  static const String apiKey = Secrets.rajaOngkirApiKey;
  
  late final Dio _dio;
  
  // Cache for API responses
  final Map<String, dynamic> _cache = {};

  RajaOngkirService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Key': apiKey, // ✅ Header name is 'Key', not 'x-api-key'
        'Content-Type': 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('🚀 RajaOngkir: $obj'),
      ));
    }
  }

  // ==================== GET PROVINCES ====================
  Future<List<Province>> getProvinces() async {
    const cacheKey = 'provinces';
    
    if (_cache.containsKey(cacheKey)) {
      debugPrint('📋 Using cached provinces');
      return _cache[cacheKey] as List<Province>;
    }
    
    try {
      debugPrint('🔄 Fetching provinces...');
      debugPrint('🔗 URL: $baseUrl/destination/province');
      
      final response = await _dio.get('/destination/province');
      
      debugPrint('📡 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data['data'] != null) {
          final provinces = (data['data'] as List)
              .map((e) => Province.fromJson(e))
              .toList();
          
          _cache[cacheKey] = provinces;
          debugPrint('✅ Loaded ${provinces.length} provinces');
          
          return provinces;
        }
      }
      
      throw Exception('Failed to load provinces: ${response.statusCode}');
      
    } catch (e) {
      debugPrint('❌ Error loading provinces: $e');
      rethrow;
    }
  }

  // ==================== GET CITIES BY PROVINCE ID ====================
  Future<List<City>> getCitiesByProvinceId(int provinceId) async {
    final cacheKey = 'cities_$provinceId';
    
    if (_cache.containsKey(cacheKey)) {
      debugPrint('📋 Using cached cities for province $provinceId');
      return _cache[cacheKey] as List<City>;
    }
    
    try {
      debugPrint('🔄 Fetching cities for province ID: $provinceId');
      
      final response = await _dio.get('/destination/city/$provinceId');
      
      debugPrint('📡 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data['data'] != null) {
          final cities = (data['data'] as List)
              .map((e) => City.fromJson(e))
              .toList();
          
          _cache[cacheKey] = cities;
          debugPrint('✅ Loaded ${cities.length} cities');
          
          return cities;
        }
      }
      
      throw Exception('Failed to load cities: ${response.statusCode}');
      
    } catch (e) {
      debugPrint('❌ Error loading cities: $e');
      rethrow;
    }
  }

  // ==================== GET DISTRICTS BY CITY ID ====================
  Future<List<District>> getDistrictsByCityId(int cityId) async {
    final cacheKey = 'districts_$cityId';
    
    if (_cache.containsKey(cacheKey)) {
      debugPrint('📋 Using cached districts for city $cityId');
      return _cache[cacheKey] as List<District>;
    }
    
    try {
      debugPrint('🔄 Fetching districts for city ID: $cityId');
      
      final response = await _dio.get('/destination/district/$cityId');
      
      debugPrint('📡 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data['data'] != null) {
          final districts = (data['data'] as List)
              .map((e) => District.fromJson(e))
              .toList();
          
          _cache[cacheKey] = districts;
          debugPrint('✅ Loaded ${districts.length} districts');
          
          return districts;
        }
      }
      
      throw Exception('Failed to load districts: ${response.statusCode}');
      
    } catch (e) {
      debugPrint('❌ Error loading districts: $e');
      rethrow;
    }
  }

  // ==================== GET SUBDISTRICTS BY DISTRICT ID ====================
  Future<List<Subdistrict>> getSubdistrictsByDistrictId(int districtId) async {
    final cacheKey = 'subdistricts_$districtId';
    
    if (_cache.containsKey(cacheKey)) {
      debugPrint('📋 Using cached subdistricts for district $districtId');
      return _cache[cacheKey] as List<Subdistrict>;
    }
    
    try {
      debugPrint('🔄 Fetching subdistricts for district ID: $districtId');
      
      final response = await _dio.get('/destination/sub-district/$districtId');
      
      debugPrint('📡 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data['data'] != null) {
          final subdistricts = (data['data'] as List)
              .map((e) => Subdistrict.fromJson(e))
              .toList();
          
          _cache[cacheKey] = subdistricts;
          debugPrint('✅ Loaded ${subdistricts.length} subdistricts');
          
          return subdistricts;
        }
      }
      
      throw Exception('Failed to load subdistricts: ${response.statusCode}');
      
    } catch (e) {
      debugPrint('❌ Error loading subdistricts: $e');
      rethrow;
    }
  }

  // ==================== CALCULATE SHIPPING COST ====================
  Future<List<ShippingRate>> calculateShipping({
    required int originDistrictId,
    required int destinationDistrictId,
    required int weight,
    List<String> couriers = const ['jne', 'pos', 'tiki', 'jnt', 'sicepat'],
  }) async {
    try {
      debugPrint('💰 Calculating shipping cost...');
      debugPrint('   Origin District ID: $originDistrictId');
      debugPrint('   Destination District ID: $destinationDistrictId');
      debugPrint('   Weight: $weight grams');
      debugPrint('   Couriers: ${couriers.join(":")}');
      
      if (weight < 1) {
        throw Exception('Berat minimal 1 gram');
      }
      
      // ✅ CORRECT ENDPOINT & FORMAT
      final response = await _dio.post(
        '/calculate/district/domestic-cost',
        data: {
          'origin': originDistrictId.toString(),
          'destination': destinationDistrictId.toString(),
          'weight': weight.toString(),
          'courier': couriers.join(':'), // Format: jne:pos:tiki
          'price': 'lowest', // Optional: lowest, highest
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      
      debugPrint('📡 Calculate Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data['data'] != null) {
          final rates = <ShippingRate>[];
          final results = data['data'] as List;
          
          if (results.isEmpty) {
            throw Exception('Tidak ada opsi pengiriman tersedia');
          }
          
          for (var item in results) {
            rates.add(ShippingRate.fromJson(item));
          }
          
          rates.sort((a, b) => a.cost.compareTo(b.cost));
          
          debugPrint('✅ Found ${rates.length} shipping options');
          for (var i = 0; i < rates.length && i < 5; i++) {
            debugPrint('   ${i + 1}. ${rates[i].displayName}: ${rates[i].displayPrice}');
          }
          
          return rates;
        }
      }
      
      throw Exception('Failed to calculate shipping: ${response.statusCode}');
      
    } catch (e) {
      debugPrint('❌ Error calculating shipping: $e');
      rethrow;
    }
  }

  // ==================== UTILITY ====================
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️ Cache cleared');
  }
  
  Future<bool> testConnection() async {
    try {
      debugPrint('🧪 Testing RajaOngkir API...');
      debugPrint('🔗 Base URL: $baseUrl');
      debugPrint('🔑 API Key: ${apiKey.substring(0, 10)}...');
      
      await getProvinces();
      debugPrint('✅ API Connection OK');
      return true;
    } catch (e) {
      debugPrint('❌ API Connection Failed: $e');
      return false;
    }
  }
}

// ==================== MODELS ====================

class Province {
  final int id;
  final String name;
  
  Province({
    required this.id,
    required this.name,
  });
  
  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: json['id'] as int,
      name: json['name'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  
  @override
  String toString() => name;
}

class City {
  final int id;
  final String name;
  final String zipCode;
  
  City({
    required this.id,
    required this.name,
    required this.zipCode,
  });
  
  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as int,
      name: json['name'] ?? '',
      zipCode: json['zip_code'] ?? '0',
    );
  }
  
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'zip_code': zipCode};
  
  @override
  String toString() => name;
}

class District {
  final int id;
  final String name;
  final String zipCode;
  
  District({
    required this.id,
    required this.name,
    required this.zipCode,
  });
  
  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] as int,
      name: json['name'] ?? '',
      zipCode: json['zip_code'] ?? '0',
    );
  }
  
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'zip_code': zipCode};
  
  @override
  String toString() => name;
}

class Subdistrict {
  final int id;
  final String name;
  final String zipCode;
  
  Subdistrict({
    required this.id,
    required this.name,
    required this.zipCode,
  });
  
  factory Subdistrict.fromJson(Map<String, dynamic> json) {
    return Subdistrict(
      id: json['id'] as int,
      name: json['name'] ?? '',
      zipCode: json['zip_code'] ?? '0',
    );
  }
  
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'zip_code': zipCode};
  
  String get fullLabel => '$name ($zipCode)';
  
  @override
  String toString() => name;
}

class ShippingRate {
  final String name;
  final String code;
  final String service;
  final String description;
  final int cost;
  final String etd;
  
  ShippingRate({
    required this.name,
    required this.code,
    required this.service,
    required this.description,
    required this.cost,
    required this.etd,
  });
  
  factory ShippingRate.fromJson(Map<String, dynamic> json) {
    return ShippingRate(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      service: json['service'] ?? '',
      description: json['description'] ?? '',
      cost: json['cost'] is int ? json['cost'] : int.parse(json['cost'].toString()),
      etd: json['etd'] ?? '',
    );
  }
  
  String get displayName => '$name - $service';
  
  String get displayPrice {
    final formatted = cost.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }
  
  String get displayDuration {
    if (etd.isEmpty) return 'Estimasi tidak tersedia';
    if (etd.toLowerCase().contains('day')) return etd;
    return '$etd hari';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'service': service,
      'description': description,
      'cost': cost,
      'etd': etd,
    };
  }
  
  @override
  String toString() => 'ShippingRate($displayName: $displayPrice, ETD: $etd)';
}

final rajaOngkirService = RajaOngkirService();