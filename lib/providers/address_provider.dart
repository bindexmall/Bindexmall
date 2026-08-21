// ============================================================================
// PROVIDER: AddressProvider (ChangeNotifier)
// ============================================================================
// State management untuk daftar alamat user (CRUD alamat, tandai alamat utama).
// Alamat disimpan lokal per-user via SharedPreferences (bukan API WooCommerce).
//
// Isi/tanggung jawab utama:
//  - initialize(userId) — panggil saat login/logout untuk load alamat user yang tepat.
//  - addAddress/updateAddress/deleteAddress/setDefaultAddress — semua auto-save & notifyListeners.
//  - Didaftarkan di main.dart dengan ChangeNotifierProxyProvider mengikuti AuthProvider.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/address.dart';
import '../services/woocommerce_service.dart';

class AddressProvider extends ChangeNotifier {
  List<Address> _addresses = [];
  bool _isLoading = false;
  String? _currentUserId;

  List<Address> get addresses => _addresses;
  bool get isLoading => _isLoading;
  
  Address? get defaultAddress {
    try {
      return _addresses.firstWhere((addr) => addr.isDefault);
    } catch (e) {
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  // Initialize with user ID
  Future<void> initialize(String? userId) async {
    _currentUserId = userId;
    if (userId != null) {
      await loadAddresses();
    } else {
      _addresses = [];
      notifyListeners();
    }
  }

  // Load addresses from WooCommerce customer meta_data
  Future<void> loadAddresses() async {
    if (_currentUserId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final customerId = int.tryParse(_currentUserId!);
      if (customerId != null) {
        final customer = await wooCommerceService.getCustomer(customerId);
        
        final metaData = customer['meta_data'] as List?;
        if (metaData != null) {
          final addressesMeta = metaData.firstWhere(
            (meta) => meta['key'] == 'addresses',
            orElse: () => null,
          );
          
          if (addressesMeta != null && addressesMeta['value'] != null) {
            final addressesJson = addressesMeta['value'];
            List<dynamic> decoded;
            
            if (addressesJson is String) {
              decoded = json.decode(addressesJson);
            } else {
              decoded = addressesJson as List;
            }
            
            _addresses = decoded.map((item) => Address.fromJson(item)).toList();
          } else {
            // No saved addresses
            _addresses = [];
            
            // Create from billing if exists
            final billing = customer['billing'];
            if (billing != null && 
                billing['address_1'] != null && 
                billing['address_1'].toString().isNotEmpty) {
              _addresses.add(Address(
                id: 'billing_${DateTime.now().millisecondsSinceEpoch}',
                firstName: billing['first_name'] ?? '',
                lastName: billing['last_name'] ?? '',
                company: billing['company'] ?? '',
                phone: billing['phone'] ?? '',
                email: billing['email'] ?? '',
                country: billing['country'] ?? 'Indonesia',
                address: billing['address_1'] ?? '',
                apartment: billing['address_2'] ?? '',
                isDefault: true,
                // ✅ TIDAK ADA provinceId, cityId, districtId lagi!
                // User harus update address untuk pilih lokasi RajaOngkir
              ));
            }
          }
        }
      }
      
      if (_addresses.isEmpty) {
        await _loadFromLocal();
      }
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      await _loadFromLocal();
    }

    _isLoading = false;
    notifyListeners();
  }
  
  // Load addresses from SharedPreferences (fallback)
  Future<void> _loadFromLocal() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'addresses_$_currentUserId';
      final addressesJson = prefs.getString(key);

      if (addressesJson != null) {
        final List<dynamic> decoded = json.decode(addressesJson);
        _addresses = decoded.map((item) => Address.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading addresses from local: $e');
    }
  }

  // Save addresses to WooCommerce customer meta_data
  Future<void> _saveAddresses() async {
    if (_currentUserId == null) return;

    try {
      final customerId = int.tryParse(_currentUserId!);
      if (customerId != null) {
        final addressesJson = json.encode(
          _addresses.map((addr) => addr.toJson()).toList(),
        );
        
        final updateData = <String, dynamic>{
          'meta_data': [
            {
              'key': 'addresses',
              'value': addressesJson,
            }
          ],
        };
        
        // Update billing/shipping with default address
        final defaultAddr = defaultAddress;
        if (defaultAddr != null) {
          updateData['billing'] = {
            'first_name': defaultAddr.firstName,
            'last_name': defaultAddr.lastName,
            'company': defaultAddr.company,
            'address_1': defaultAddr.address,
            'address_2': defaultAddr.apartment,
            'city': defaultAddr.cityName ?? '', // ✅ FIXED
            'state': defaultAddr.provinceName ?? '', // ✅ FIXED
            'postcode': defaultAddr.zipCode ?? '', // ✅ FIXED
            'country': defaultAddr.country,
            'email': defaultAddr.email,
            'phone': defaultAddr.phone,
          };
          
          updateData['shipping'] = {
            'first_name': defaultAddr.firstName,
            'last_name': defaultAddr.lastName,
            'company': defaultAddr.company,
            'address_1': defaultAddr.address,
            'address_2': defaultAddr.apartment,
            'city': defaultAddr.cityName ?? '', // ✅ FIXED
            'state': defaultAddr.provinceName ?? '', // ✅ FIXED
            'postcode': defaultAddr.zipCode ?? '', // ✅ FIXED
            'country': defaultAddr.country,
          };
        }
        
        await wooCommerceService.updateCustomer(customerId, updateData);
        debugPrint('✅ Addresses saved to WooCommerce');
      }
      
      await _saveToLocal();
    } catch (e) {
      debugPrint('Error saving addresses: $e');
      await _saveToLocal();
      rethrow;
    }
  }
  
  // Save addresses to SharedPreferences (backup)
  Future<void> _saveToLocal() async {
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'addresses_$_currentUserId';
      final addressesJson = json.encode(
        _addresses.map((addr) => addr.toJson()).toList(),
      );
      await prefs.setString(key, addressesJson);
    } catch (e) {
      debugPrint('Error saving addresses to local: $e');
    }
  }

  // Add new address
  Future<void> addAddress(Address address) async {
    // If this is the first address or marked as default, make it default
    if (_addresses.isEmpty || address.isDefault) {
      // Remove default from other addresses
      _addresses = _addresses.map((addr) => addr.copyWith(isDefault: false)).toList();
    }

    _addresses.add(address);
    await _saveAddresses();
    notifyListeners();
  }

  // Update address
  Future<void> updateAddress(String addressId, Address updatedAddress) async {
    final index = _addresses.indexWhere((addr) => addr.id == addressId);
    if (index != -1) {
      // If marked as default, remove default from others
      if (updatedAddress.isDefault) {
        _addresses = _addresses.map((addr) => addr.copyWith(isDefault: false)).toList();
      }

      _addresses[index] = updatedAddress;
      await _saveAddresses();
      notifyListeners();
    }
  }

  // Delete address
  Future<void> deleteAddress(String addressId) async {
    final index = _addresses.indexWhere((addr) => addr.id == addressId);
    if (index != -1) {
      final wasDefault = _addresses[index].isDefault;
      _addresses.removeAt(index);

      // If deleted address was default, make first address default
      if (wasDefault && _addresses.isNotEmpty) {
        _addresses[0] = _addresses[0].copyWith(isDefault: true);
      }

      await _saveAddresses();
      notifyListeners();
    }
  }

  // Set default address
  Future<void> setDefaultAddress(String addressId) async {
    _addresses = _addresses.map((addr) {
      return addr.copyWith(isDefault: addr.id == addressId);
    }).toList();

    await _saveAddresses();
    notifyListeners();
  }

  // Get address by ID
  Address? getAddressById(String addressId) {
    try {
      return _addresses.firstWhere((addr) => addr.id == addressId);
    } catch (e) {
      return null;
    }
  }
  
  // Refresh addresses from server
  Future<void> refreshAddresses() async {
    await loadAddresses();
  }
}