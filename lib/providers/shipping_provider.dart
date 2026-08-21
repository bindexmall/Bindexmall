// ============================================================================
// PROVIDER: ShippingProvider (ChangeNotifier)
// ============================================================================
// State alur pemilihan wilayah pengiriman berjenjang (Provinsi > Kota > Kecamatan >
// Kelurahan) dan kalkulasi ongkir, via RajaOngkirService (Komerce API).
//
// Isi/tanggung jawab utama:
//  - Alur: selectProvince -> loadCities -> selectCity -> loadDistricts -> ... -> calculateShipping.
//  - validateForCheckout()/getValidationError() dipakai checkout_screen.dart sebelum bayar.
//  - clearCache() membersihkan cache request RajaOngkirService (lihat services/rajaongkir_service.dart).
// ============================================================================

import 'package:flutter/foundation.dart';
import '../services/rajaongkir_service.dart';

class ShippingProvider extends ChangeNotifier {
  // Selected items
  Province? _selectedProvince;
  City? _selectedCity;
  District? _selectedDistrict;
  Subdistrict? _selectedSubdistrict;

  // Lists
  List<Province> _provinces = [];
  List<City> _cities = [];
  List<District> _districts = [];
  List<Subdistrict> _subdistricts = [];
  List<ShippingRate> _shippingRates = [];
  
  ShippingRate? _selectedShipping;

  // Loading states
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingSubdistricts = false;
  bool _isCalculatingShipping = false;

  // Origin district ID (warehouse/store location)
  int originDistrictId = 0;

  // Getters
  Province? get selectedProvince => _selectedProvince;
  City? get selectedCity => _selectedCity;
  District? get selectedDistrict => _selectedDistrict;
  Subdistrict? get selectedSubdistrict => _selectedSubdistrict;

  List<Province> get provinces => _provinces;
  List<City> get cities => _cities;
  List<District> get districts => _districts;
  List<Subdistrict> get subdistricts => _subdistricts;
  List<ShippingRate> get shippingRates => _shippingRates;
  
  ShippingRate? get selectedShipping => _selectedShipping;

  bool get isLoadingProvinces => _isLoadingProvinces;
  bool get isLoadingCities => _isLoadingCities;
  bool get isLoadingDistricts => _isLoadingDistricts;
  bool get isLoadingSubdistricts => _isLoadingSubdistricts;
  bool get isCalculatingShipping => _isCalculatingShipping;

  bool get hasSelectedLocation => _selectedSubdistrict != null;
  bool get hasShippingRates => _shippingRates.isNotEmpty;
  bool get isReady => hasSelectedLocation && !isCalculatingShipping;

  // ==================== LOAD PROVINCES ====================
  Future<void> loadProvinces() async {
    if (_isLoadingProvinces) return;

    _isLoadingProvinces = true;
    notifyListeners();

    try {
      _provinces = await rajaOngkirService.getProvinces();
      debugPrint('✅ Provider: Loaded ${_provinces.length} provinces');
    } catch (e) {
      debugPrint('❌ Provider: Error loading provinces - $e');
      rethrow;
    } finally {
      _isLoadingProvinces = false;
      notifyListeners();
    }
  }

  // ==================== LOAD CITIES ====================
  Future<void> loadCities(int provinceId) async {
    if (_isLoadingCities) return;

    _isLoadingCities = true;
    _cities = [];
    _districts = [];
    _subdistricts = [];
    _selectedCity = null;
    _selectedDistrict = null;
    _selectedSubdistrict = null;
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();

    try {
      _cities = await rajaOngkirService.getCitiesByProvinceId(provinceId);
      debugPrint('✅ Provider: Loaded ${_cities.length} cities');
    } catch (e) {
      debugPrint('❌ Provider: Error loading cities - $e');
      rethrow;
    } finally {
      _isLoadingCities = false;
      notifyListeners();
    }
  }

  // ==================== LOAD DISTRICTS ====================
  Future<void> loadDistricts(int cityId) async {
    if (_isLoadingDistricts) return;

    _isLoadingDistricts = true;
    _districts = [];
    _subdistricts = [];
    _selectedDistrict = null;
    _selectedSubdistrict = null;
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();

    try {
      _districts = await rajaOngkirService.getDistrictsByCityId(cityId);
      debugPrint('✅ Provider: Loaded ${_districts.length} districts');
    } catch (e) {
      debugPrint('❌ Provider: Error loading districts - $e');
      rethrow;
    } finally {
      _isLoadingDistricts = false;
      notifyListeners();
    }
  }

  // ==================== LOAD SUBDISTRICTS ====================
  Future<void> loadSubdistricts(int districtId) async {
    if (_isLoadingSubdistricts) return;

    _isLoadingSubdistricts = true;
    _subdistricts = [];
    _selectedSubdistrict = null;
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();

    try {
      _subdistricts = await rajaOngkirService.getSubdistrictsByDistrictId(districtId);
      debugPrint('✅ Provider: Loaded ${_subdistricts.length} subdistricts');
    } catch (e) {
      debugPrint('❌ Provider: Error loading subdistricts - $e');
      rethrow;
    } finally {
      _isLoadingSubdistricts = false;
      notifyListeners();
    }
  }

  // ==================== SELECTION METHODS ====================

  Future<void> selectProvince(Province province) async {
    if (_selectedProvince == province) return;

    _selectedProvince = province;
    _selectedCity = null;
    _selectedDistrict = null;
    _selectedSubdistrict = null;
    _cities = [];
    _districts = [];
    _subdistricts = [];
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();

    await loadCities(province.id);
  }

  Future<void> selectCity(City city) async {
    if (_selectedCity == city) return;

    _selectedCity = city;
    _selectedDistrict = null;
    _selectedSubdistrict = null;
    _districts = [];
    _subdistricts = [];
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();

    await loadDistricts(city.id);
  }

  Future<void> selectDistrict(District district) async {
    if (_selectedDistrict == district) return;

    _selectedDistrict = district;
    _selectedSubdistrict = null;
    _subdistricts = [];
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();

    await loadSubdistricts(district.id);
  }

  void selectSubdistrict(Subdistrict subdistrict) {
    _selectedSubdistrict = subdistrict;
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();
    debugPrint('✅ Provider: Selected subdistrict: ${subdistrict.name}');
  }

  // ==================== CALCULATE SHIPPING ====================

  Future<void> calculateShipping({
    required int weight,
    List<String> couriers = const ['jne', 'pos', 'tiki', 'jnt', 'sicepat'],
  }) async {
    if (_selectedDistrict == null) {
      throw Exception('Pilih kecamatan tujuan terlebih dahulu');
    }

    if (originDistrictId == 0) {
      throw Exception('Origin district ID belum diset. Hubungi admin.');
    }

    if (_isCalculatingShipping) return;

    _isCalculatingShipping = true;
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();

    try {
      debugPrint('📦 Provider: Calculating shipping...');
      debugPrint('   Origin District ID: $originDistrictId');
      debugPrint('   Destination District ID: ${_selectedDistrict!.id}');
      debugPrint('   Weight: $weight grams');

      _shippingRates = await rajaOngkirService.calculateShipping(
        originDistrictId: originDistrictId,
        destinationDistrictId: _selectedDistrict!.id,
        weight: weight,
        couriers: couriers,
      );

      debugPrint('✅ Provider: Found ${_shippingRates.length} shipping options');
    } catch (e) {
      debugPrint('❌ Provider: Error calculating shipping - $e');
      rethrow;
    } finally {
      _isCalculatingShipping = false;
      notifyListeners();
    }
  }

  void selectShippingOption(ShippingRate rate) {
    _selectedShipping = rate;
    notifyListeners();
    debugPrint('✅ Provider: Selected ${rate.displayName}');
  }

  // ==================== RESET METHODS ====================

  void clearSelection() {
    _selectedProvince = null;
    _selectedCity = null;
    _selectedDistrict = null;
    _selectedSubdistrict = null;
    _cities = [];
    _districts = [];
    _subdistricts = [];
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();
    debugPrint('🗑️ Provider: All selections cleared');
  }

  void resetShippingOptions() {
    _shippingRates = [];
    _selectedShipping = null;
    notifyListeners();
    debugPrint('🗑️ Provider: Shipping options reset');
  }

  // ==================== UTILITY ====================

  String getFullAddress() {
    if (_selectedSubdistrict == null) return '';
    
    final parts = <String>[];
    
    if (_selectedSubdistrict != null) parts.add(_selectedSubdistrict!.name);
    if (_selectedDistrict != null) parts.add(_selectedDistrict!.name);
    if (_selectedCity != null) parts.add(_selectedCity!.name);
    if (_selectedProvince != null) parts.add(_selectedProvince!.name);
    
    return parts.join(', ');
  }

  String getShippingCostSummary() {
    if (_selectedShipping == null) return 'Belum dipilih';
    return '${_selectedShipping!.displayPrice} - ${_selectedShipping!.displayDuration}';
  }

  ShippingRate? getCheapestRate() {
    if (_shippingRates.isEmpty) return null;
    return _shippingRates.reduce((a, b) => a.cost < b.cost ? a : b);
  }

  bool validateForCheckout() {
    if (_selectedSubdistrict == null) {
      debugPrint('⚠️ Validation failed: Subdistrict not selected');
      return false;
    }

    if (_selectedShipping == null) {
      debugPrint('⚠️ Validation failed: Shipping not selected');
      return false;
    }

    return true;
  }

  String? getValidationError() {
    if (_selectedSubdistrict == null) {
      return 'Pilih lokasi pengiriman hingga kelurahan terlebih dahulu';
    }
    if (_selectedShipping == null) {
      return 'Pilih metode pengiriman terlebih dahulu';
    }
    return null;
  }

  void clearCache() {
    rajaOngkirService.clearCache();
    debugPrint('🗑️ Provider: Service cache cleared');
  }

  Map<String, dynamic> getStateSummary() {
    return {
      'province': _selectedProvince?.name ?? 'Not selected',
      'city': _selectedCity?.name ?? 'Not selected',
      'district': _selectedDistrict?.name ?? 'Not selected',
      'subdistrict': _selectedSubdistrict?.name ?? 'Not selected',
      'shipping': _selectedShipping?.displayName ?? 'Not selected',
      'shippingCost': _selectedShipping?.displayPrice ?? 'N/A',
      'hasLocation': hasSelectedLocation,
      'hasShipping': hasShippingRates,
      'isReady': isReady,
    };
  }

  @override
  void dispose() {
    clearSelection();
    super.dispose();
  }
}