// ============================================================================
// PROVIDER: AuthProvider (ChangeNotifier)
// ============================================================================
// Pusat state autentikasi user: login, register, logout, simpan token JWT,
// auto-login saat app dibuka (baca token tersimpan), lupa password.
//
// Isi/tanggung jawab utama:
//  - Menggunakan JWTAuthService (custom WP JWT endpoint) untuk login/register/reset password.
//  - Token & data user disimpan di SharedPreferences agar sesi bertahan antar-buka-app.
//  - initialize() dipanggil sekali di main.dart saat provider dibuat (auto check token).
//  - Provider lain (Cart, Product, Address) mendengarkan userId dari sini via
//  -   ChangeNotifierProxyProvider agar cart/wishlist/alamat ikut ganti saat login/logout.
//  - Juga memicu OrderTrackingService.startTracking/stopTracking mengikuti status login.
// ============================================================================

import 'package:bindexmall/services/order_tracking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/jwt_auth_service.dart';
import '../services/woocommerce_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  /// Callback untuk notify perubahan user ID ke cart & wishlist providers
  void Function(String?)? onUserIdChanged;

  /// Initialize - check if user already logged in
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔐 Initializing AuthProvider...');
      
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('jwt_token');
      final savedUserId = prefs.getString('user_id');
      final savedUserEmail = prefs.getString('user_email');
      final savedUserName = prefs.getString('user_name');
      
      if (savedToken != null) {
        debugPrint('🔑 Found saved token, validating...');
        
        // Validate saved token
        try {
          final result = await jwtAuthService.validateToken(savedToken);
          
          if (result['code'] == 'jwt_auth_valid_token') {
            debugPrint('✅ Token is valid!');
            
            _token = savedToken;
            _userEmail = result['data']['user_email'] ?? savedUserEmail;
            _userName = result['data']['user_display_name'] ?? savedUserName;
            _isAuthenticated = true;
            
            // ✅ USE SAVED USER ID OR LOAD FROM WOOCOMMERCE
            if (savedUserId != null && savedUserId.isNotEmpty) {
              _userId = savedUserId;
              debugPrint('📋 Using saved user ID: $_userId');
            } else {
              // Get customer ID from WooCommerce
              await _loadCustomerData(_userEmail!);
            }
            
            // Notify user ID changed for cart and wishlist sync
            _notifyUserIdChanged();
            
            // START ORDER TRACKING
            if (_userId != null) {
              orderTrackingService.startTracking(_userId);
              debugPrint('📦 Order tracking started for user: $_userId');
            }
            
            debugPrint('✅ User authenticated: $_userEmail (ID: $_userId)');
          } else {
            debugPrint('❌ Token validation failed');
            await _clearAuth();
          }
        } catch (e) {
          debugPrint('❌ Token validation error: $e');
          await _clearAuth();
        }
      } else {
        debugPrint('ℹ️ No saved token found');
      }
    } catch (e) {
      debugPrint('❌ Auth initialization error: $e');
      await _clearAuth();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔐 Attempting login for: $email');
      
      // 1. Login via JWT
      final result = await jwtAuthService.login(email, password);
      
      _token = result['token'];
      _userEmail = result['user_email'];
      _userName = result['user_display_name'];
      _isAuthenticated = true;

      debugPrint('✅ JWT login successful');

      // 2. Get customer data from WooCommerce
      await _loadCustomerData(email);

      // 3. Save authentication data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('user_email', _userEmail!);
      await prefs.setString('user_name', _userName ?? '');
      if (_userId != null) {
        await prefs.setString('user_id', _userId!);
      }

      debugPrint('💾 Authentication data saved');

      // 4. Notify user ID changed for cart and wishlist sync
      _notifyUserIdChanged();
      
      // 5. START ORDER TRACKING
      if (_userId != null) {
        orderTrackingService.startTracking(_userId);
        debugPrint('📦 Order tracking started');
      }

      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ Sign in completed successfully');
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign up dengan auto-fallback
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📝 Attempting registration for: $email');
      
      // Coba Method 1: Custom endpoint (preferred)
      try {
        debugPrint('Trying custom registration endpoint...');
        final result = await jwtAuthService.register(
          name: name,
          email: email,
          password: password,
          phone: phone,
        );

        if (result['success'] == true) {
          if (result['token'] != null) {
            _token = result['token'];
            _userEmail = result['email'];
            _userName = result['name'];
            _userId = result['user_id'].toString();
            _isAuthenticated = true;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('jwt_token', _token!);
            await prefs.setString('user_email', _userEmail!);
            await prefs.setString('user_name', _userName!);
            await prefs.setString('user_id', _userId!);

            _notifyUserIdChanged();

            debugPrint('✅ Registration successful with auto-login');
            _isLoading = false;
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        debugPrint('❌ Custom endpoint failed: $e');
      }

      debugPrint('Trying WooCommerce registration...');
      
      final existingCustomers = await wooCommerceService.getCustomerByEmail(email);
      if (existingCustomers.isNotEmpty) {
        throw Exception('Email sudah terdaftar');
      }

      final nameParts = name.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      String username = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      username = '${username}_${DateTime.now().millisecondsSinceEpoch % 100000}';

      final customerData = {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'billing': {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'phone': phone ?? '',
        }
      };

      debugPrint('Creating WooCommerce customer...');
      final newCustomer = await wooCommerceService.createCustomer(customerData);

      _userId = newCustomer['id'].toString();
      _userName = name;
      _userEmail = email;
      _isAuthenticated = true;

      debugPrint('✅ Customer created with ID: $_userId');
      
      _isLoading = false;
      notifyListeners();

      // Info untuk user
      throw Exception(
        'Akun berhasil dibuat!\n\n'
        'PENTING: Anda perlu mengatur password.\n'
        'Silakan:\n'
        '1. Buka https://bindexmall.com\n'
        '2. Klik "Lupa Password"\n'
        '3. Masukkan email: $email\n'
        '4. Set password baru\n\n'
        'Setelah itu, Anda bisa login di aplikasi.'
      );

    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      
      String errorMessage = 'Gagal membuat akun';
      
      if (e.response?.data != null) {
        debugPrint('Error response: ${e.response?.data}');
        final data = e.response!.data;
        
        if (data is Map) {
          if (data['message'] != null) {
            errorMessage = data['message'].toString();
          } else if (data['code'] == 'registration-error-email-exists') {
            errorMessage = 'Email sudah terdaftar';
          } else if (data['code'] == 'rest_invalid_param') {
            errorMessage = 'Email tidak valid';
          }
        }
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadCustomerData(String email) async {
    try {
      debugPrint('🔍 Loading customer data for: $email');
      final customers = await wooCommerceService.getCustomerByEmail(email);
      
      if (customers.isNotEmpty) {
        final customer = customers.first;
        _userId = customer['id'].toString();
        
        final fullName = '${customer['first_name']} ${customer['last_name']}'.trim();
        if (fullName.isNotEmpty) {
          _userName = fullName;
        }
        
        debugPrint('✅ Customer found - ID: $_userId, Name: $_userName');
      } else {
        debugPrint('⚠️ Customer not found in WooCommerce');
      }
    } catch (e) {
      debugPrint('❌ Error loading customer data: $e');
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔓 Signing out user: $_userEmail');
      
      await _clearAuth();
      
      _notifyUserIdChanged();
      
      orderTrackingService.stopTracking();
      
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ Sign out completed');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    
    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _isAuthenticated = false;
    
    debugPrint('🗑️ Authentication data cleared');
  }

  void _notifyUserIdChanged() {
    if (onUserIdChanged != null) {
      onUserIdChanged!(_userId);
    }
  }

  Future<void> logout() => signOut();

  Future<void> updateProfile({
    String? name,
    String? email,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    _isLoading = true;
    notifyListeners();

    try {
      final updateData = <String, dynamic>{};
      
      if (name != null) {
        final nameParts = name.split(' ');
        updateData['first_name'] = nameParts.first;
        updateData['last_name'] = nameParts.length > 1 
            ? nameParts.sublist(1).join(' ') 
            : '';
      }
      
      if (email != null) {
        updateData['email'] = email;
      }

      await wooCommerceService.updateCustomer(
        int.parse(_userId!),
        updateData,
      );

      if (name != null) _userName = name;
      if (email != null) _userEmail = email;
      
      final prefs = await SharedPreferences.getInstance();
      if (name != null) await prefs.setString('user_name', name);
      if (email != null) await prefs.setString('user_email', email);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCustomerData() async {
    if (_userId == null) return null;
    
    try {
      return await wooCommerceService.getCustomer(int.parse(_userId!));
    } catch (e) {
      debugPrint('Error getting customer data: $e');
      return null;
    }
  }
}