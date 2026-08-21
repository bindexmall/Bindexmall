// ============================================================================
// SCREEN: CheckoutScreen + SelectLocationScreen (lokal) + MidtransPaymentScreen
// ============================================================================
// SCREEN PALING KOMPLEKS di app ini (~2500+ baris). Alur lengkap checkout:
// pilih/isi alamat pengiriman, pilih kurir & layanan (ShippingProvider/RajaOngkir),
// terapkan kupon, ringkasan biaya (subtotal + ongkir - diskon), buat order ke
// WooCommerce (OrderRepository), lalu bayar via Midtrans Snap (MidtransPaymentScreen
// = WebView yang load buildSnapUrl() dari MidtransService).
//
// Catatan:
//  - SelectLocationScreen di file ini KHUSUS untuk alur checkout — beda dari
//  -   SelectLocationScreen di add_address_screen.dart maupun select_shipping_screen.dart.
//  -   Ketiganya class dengan nama sama tapi implementasi terpisah — HATI-HATI saat edit,
//  -   pastikan mengedit file yang benar sesuai konteks (checkout vs tambah alamat vs shipping).
//  - PPN 11%: JANGAN tambahkan kalkulasi pajak baru di sini — harga produk WooCommerce
//  -   SUDAH termasuk PPN. Riwayat bug 'PPN dihitung dobel' sudah pernah diperbaiki di
//  -   cart.dart, cart_screen.dart, dan file ini — lihat komentar terkait di sekitar
//  -   perhitungan total sebelum ubah logic harga.
//  - MidtransPaymentScreen adalah WebView yang menangkap redirect/callback status
//  -   pembayaran dari Midtrans Snap.
// ============================================================================

import 'dart:io';

import 'package:bindexmall/services/cloudinary_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/rajaongkir_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/shipping_provider.dart';
import '../services/woocommerce_service.dart';
import '../services/midtrans_service.dart';

import '../utils/currency_formatter.dart';
import '../providers/coupon_provider.dart';
import '../widgets/applied_coupon_card.dart';
import '../l10n/app_localizations.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  bool loading = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _orderNotesController = TextEditingController();

  final _dropshipperNameController = TextEditingController();
  final _dropshipperPhoneController = TextEditingController();
  File? _paymentProof;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  bool _isDropshipper = false;

  String _selectedPaymentMethod = 'midtrans';

  ShippingRate? _selectedShipping;

  Province? _selectedProvince;
  City? _selectedCity;
  District? _selectedDistrict;
  Subdistrict? _selectedSubdistrict;

  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        _loadUserBillingInfo();
      } else {
        _emailController.clear();
      }

      final shippingProvider =
          Provider.of<ShippingProvider>(context, listen: false);
      if (shippingProvider.provinces.isEmpty) {
        shippingProvider.loadProvinces();
      }
    });
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    setState(() {
      _currentLocale = Locale(languageCode);
    });
  }

  String _t(String key) {
    return AppLocalizations(_currentLocale).translate(key);
  }

  Future<void> _loadUserBillingInfo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final customerId = int.tryParse(authProvider.userId ?? '');

      if (customerId != null) {
        final customer = await wooCommerceService.getCustomer(customerId);
        final billing = customer['billing'];

        if (billing != null) {
          setState(() {
            _firstNameController.text = billing['first_name'] ?? '';
            _lastNameController.text = billing['last_name'] ?? '';
            _companyController.text = billing['company'] ?? '';
            _phoneController.text = billing['phone'] ?? '';
            _emailController.text = billing['email'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading billing info: $e');
    }
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectLocationScreen(currentLocale: _currentLocale),
      ),
    );

    if (result != null && result['subdistrict'] is Subdistrict) {
      final shippingProvider = Provider.of<ShippingProvider>(
        context,
        listen: false,
      );

      setState(() {
        _selectedProvince = shippingProvider.selectedProvince;
        _selectedCity = shippingProvider.selectedCity;
        _selectedDistrict = shippingProvider.selectedDistrict;
        _selectedSubdistrict = result['subdistrict'] as Subdistrict;
        _selectedShipping = null;
      });

      await _calculateShipping();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_t('locationSelected')}: ${_selectedSubdistrict!.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _calculateShipping() async {
    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('selectDeliveryLocationFirst')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final shippingProvider =
        Provider.of<ShippingProvider>(context, listen: false);

    shippingProvider.originDistrictId = 1391;

    int totalWeight = cartProvider.items.fold(
      0,
      (sum, item) =>
          sum + ((item.product.weight ?? 500) * item.quantity).toInt(),
    );
    if (totalWeight < 100) totalWeight = 100;

    try {
      await shippingProvider.calculateShipping(weight: totalWeight);

      if (shippingProvider.shippingRates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('noShippingOptionsAvailable')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('errorCalculatingShipping')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectShipping() async {
    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('selectDeliveryLocationFirst')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final shippingProvider =
        Provider.of<ShippingProvider>(context, listen: false);

    if (shippingProvider.shippingRates.isEmpty &&
        !shippingProvider.isCalculatingShipping) {
      await _calculateShipping();
    }

    // ✅ CHANGED - dulu di-return + snackbar kalau shippingRates kosong (gak ada
    // kurir yang cover lokasi tsb). Sekarang tetap lanjut buka bottom sheet
    // tanpa snackbar, karena "Ambil di Tempat" tetap muncul sebagai opsi.
    if (!mounted) return;

    final selectedRate = await showModalBottomSheet<ShippingRate>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _t('selectShippingMethod'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<ShippingProvider>(
                  builder: (context, provider, child) {
                    if (provider.isCalculatingShipping) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(_t('calculatingShippingCosts')),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      // ✅ CHANGED - +1 slot buat opsi "Ambil di Tempat" di posisi paling atas
                      itemCount: provider.shippingRates.length + 1,
                      itemBuilder: (context, index) {
                        // ✅ ADDED - index 0 selalu "Ambil di Tempat" (pickup, no ongkir)
                        if (index == 0) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: Colors.green.withOpacity(0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.green.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.storefront,
                                    color: Colors.green),
                              ),
                              title: const Text(
                                'Ambil di Tempat',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                _currentLocale.languageCode == 'en'
                                    ? 'Pick up your order directly at our store'
                                    : 'Ambil pesanan langsung di toko kami',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Text(
                                'Rp 0',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                              onTap: () => Navigator.pop(
                                context,
                                ShippingRate(
                                  name: 'Ambil di Tempat',
                                  code: 'pickup',
                                  service: 'Store Pickup',
                                  description:
                                      'Ambil pesanan langsung di toko, tanpa ongkos kirim',
                                  cost: 0,
                                  etd: '',
                                ),
                              ),
                            ),
                          );
                        }

                        final rate = provider.shippingRates[index - 1];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.local_shipping,
                                  color: Colors.blue),
                            ),
                            title: Text(
                              rate.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rate.service),
                                const SizedBox(height: 4),
                                Text(
                                  rate.description,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_t('estimate')}: ${rate.displayDuration}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Text(
                              rate.displayPrice,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, rate),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );

    if (selectedRate != null) {
      setState(() {
        _selectedShipping = selectedRate;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _apartmentController.dispose();
    _orderNotesController.dispose();
    _dropshipperNameController.dispose();
    _dropshipperPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        title: Text(_t('checkout'), style: textTheme.headlineSmall),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(_t('orderSummary')),
                Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return _buildOrderSummary(cart);
                  },
                ),
                const SizedBox(height: 24.0),
                _buildDropshipperSection(),
                const SizedBox(height: 24.0),
                _buildSectionTitle(_t('recipientInformation')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: _t('firstNameRequired'),
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return _t('requiredField');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: _t('lastNameRequired'),
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return _t('requiredField');
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _companyController,
                  label: _t('companyOptional'),
                  icon: Icons.business,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: _t('telephoneNumber'),
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _t('requiredField');
                    }
                    if (value.trim().length < 10) {
                      return _t('telephoneTooShort');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return _buildTextField(
                      controller: _emailController,
                      label: '${_t('email')} *',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !authProvider.isAuthenticated,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return _t('requiredField');
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return _t('invalidEmail');
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(_t('deliveryLocation')),
                const SizedBox(height: 16),
                _buildLocationSection(),
                const SizedBox(height: 24.0),
                _buildSectionTitle(_t('completeAddress')),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: _t('streetAddressRequired'),
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  hintText: _t('streetAddressHint'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _t('requiredField');
                    }
                    if (value.trim().length < 10) {
                      return _t('addressTooShort');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _apartmentController,
                  label: _t('apartmentSuiteUnit'),
                  icon: Icons.apartment,
                  hintText: _t('apartmentHint'),
                ),
                const SizedBox(height: 24.0),
                _buildShippingSection(),
                const SizedBox(height: 24.0),
                _buildTextField(
                  controller: _orderNotesController,
                  label: _t('orderNotes'),
                  icon: Icons.note,
                  maxLines: 3,
                  hintText: _t('orderNotesHint'),
                ),
                const SizedBox(height: 24.0),
                _buildSectionTitle(_t('paymentMethod')),
                const SizedBox(height: 16.0),
                _buildPaymentMethodSelector(),
                const SizedBox(height: 24.0),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Consumer2<CartProvider, AuthProvider>(
        builder: (context, cartProvider, authProvider, child) {
          return _buildBottomBar(context, cartProvider, authProvider);
        },
      ),
    );
  }

  Widget _buildBankInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<File?> _pickImageSource(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _t('uploadPaymentProofTitle'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text(_t('chooseFromGallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: Text(_t('takePhoto')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return null;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('failedToPickImage')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return null;
  }

  Future<void> _uploadPaymentProofFromCheckout(
    String orderId,
    StateSetter setDialogState,
  ) async {
    if (_paymentProof == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${_t('mustBeLoggedInToUpload')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: _t('loginToUpload'),
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
      return;
    }

    setDialogState(() {
      _isUploading = true;
    });

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 Starting payment proof upload from checkout...');
      debugPrint('👤 User: ${authProvider.userName} (${authProvider.userId})');
      debugPrint('📧 Email: ${authProvider.userEmail}');
      debugPrint('💳 Order ID: $orderId');

      final customerName = authProvider.userName ?? 'Unknown';

      final orderData =
          await wooCommerceService.getOrderById(int.parse(orderId));
      final totalAmount = orderData['total']?.toString() ?? '0';

      debugPrint('👤 Customer: $customerName');
      debugPrint('💰 Amount: $totalAmount');

      final result = await cloudinaryUploadService.uploadPaymentProof(
        proofFile: _paymentProof!,
        orderId: orderId,
        customerName: customerName,
        customerEmail: authProvider.userEmail,
        transferAmount: totalAmount,
      );

      if (result == null) {
        throw Exception('Upload failed. Please try again.');
      }

      final imageUrl = result['url'];
      final mediaId = result['id'];

      debugPrint('✅ Image uploaded: $imageUrl');
      debugPrint('✅ Media ID: $mediaId');

      final updateSuccess = await wooCommerceService.updateOrderMetaData(
        orderId: int.parse(orderId),
        metaData: {
          '_payment_proof_url': imageUrl,
          '_payment_proof_media_id': mediaId.toString(),
          '_payment_proof_uploaded_at': DateTime.now().toIso8601String(),
          '_payment_proof_customer_name': customerName,
          '_payment_proof_customer_email': authProvider.userEmail ?? '',
          '_payment_proof_thumbnail': result['thumbnail'],
        },
      );

      if (!updateSuccess) {
        throw Exception('Failed to update order metadata');
      }

      debugPrint('✅ Order metadata updated');

      await wooCommerceService.addOrderNote(
        orderId: int.parse(orderId),
        note: '💳 Customer uploaded payment proof from checkout.\n'
            'Customer: $customerName\n'
            'Email: ${authProvider.userEmail}\n'
            'View: $imageUrl\n'
            'Uploaded: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        isCustomerNote: false,
      );

      debugPrint('✅ Order note added');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      setDialogState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_t('paymentProofUploadedSuccessfully')),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on SocketException {
      debugPrint('❌ No internet connection');
      setDialogState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${_t('noInternetConnection')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      setDialogState(() {
        _isUploading = false;
      });

      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        if (errorMessage.contains('Not authenticated')) {
          errorMessage = _t('sessionExpired');
        } else if (errorMessage.contains('Authentication failed')) {
          errorMessage = _t('authenticationFailed');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('failedToUpload')}: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: errorMessage.contains(_t('login').toLowerCase())
                ? SnackBarAction(
                    label: _t('login'),
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildDropshipperSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 77, 100, 255),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront,
                      color: Color.fromARGB(255, 255, 255, 255)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t('sendAsDropshipper'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: _isDropshipper,
                  onChanged: (value) {
                    setState(() {
                      _isDropshipper = value;
                      if (!value) {
                        _dropshipperNameController.clear();
                        _dropshipperPhoneController.clear();
                      }
                    });
                  },
                  activeThumbColor: const Color.fromARGB(255, 77, 100, 255),
                ),
              ],
            ),
            if (_isDropshipper) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 173, 182, 255),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color.fromARGB(255, 50, 64, 153)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Color.fromARGB(255, 46, 46, 46)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t('dropshipperInfo'),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color.fromARGB(255, 46, 46, 46)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _dropshipperNameController,
                      label: '${_t('senderName')} *',
                      icon: Icons.person_pin,
                      hintText: _t('senderNameHint'),
                      validator: _isDropshipper
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _t('requiredField');
                              }
                              return null;
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _dropshipperPhoneController,
                      label: '${_t('senderPhone')} *',
                      icon: Icons.phone_in_talk,
                      keyboardType: TextInputType.phone,
                      hintText: _t('senderPhoneHint'),
                      validator: _isDropshipper
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _t('requiredField');
                              }
                              if (value.trim().length < 10) {
                                return _t('telephoneTooShort');
                              }
                              return null;
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Text(
                  _t('selectDeliveryLocation'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedDistrict == null)
              OutlinedButton.icon(
                onPressed: _selectLocation,
                icon: const Icon(Icons.location_searching),
                label: Text(_t('selectDeliveryLocation')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedSubdistrict != null)
                                Text(
                                  _selectedSubdistrict!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              Text(
                                _selectedDistrict!.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                '${_selectedCity!.name}, ${_selectedProvince!.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (_selectedSubdistrict?.zipCode != null)
                                Text(
                                  '${_t('postalCode')}: ${_selectedSubdistrict!.zipCode}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _selectLocation,
                      icon: const Icon(Icons.edit_location, size: 18),
                      label: Text(_t('changeLocation')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        side: BorderSide(color: Colors.green.shade700),
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingSection() {
    return Card(
      margin: const EdgeInsets.all(0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Text(
                  _t('shippingMethod'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedShipping == null)
              OutlinedButton.icon(
                onPressed: _selectShipping,
                icon: const Icon(Icons.add),
                label: Text(_t('selectShippingMethod')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedShipping!.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedShipping!.displayPrice,
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_t('estimate')}: ${_selectedShipping!.displayDuration}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _selectShipping,
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: _t('changeLocation'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    return Consumer<CouponProvider>(
      builder: (context, couponProvider, child) {
        final subtotal = cart.total;
        final shippingCost = (_selectedShipping?.cost ?? 0).toDouble();
        final discount = couponProvider.calculateDiscount(subtotal);
        final subtotalAfterDiscount = subtotal - discount;
        final total = subtotalAfterDiscount + shippingCost;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...cart.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.product.name} x${item.quantity}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(
                                item.product.price * item.quantity),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                if (couponProvider.hasCoupon) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppliedCouponCard(
                      coupon: couponProvider.appliedCoupon!,
                      discount: discount,
                      onRemove: null,
                    ),
                  ),
                ],
                _buildSummaryRow(_t('subtotal'), subtotal),
                if (discount > 0)
                  _buildSummaryRow(
                    '${_t('discount')} (${couponProvider.appliedCoupon?.code})',
                    -discount,
                    valueColor: Colors.orange,
                  ),
                _buildSummaryRow(_t('shippingCost'), shippingCost),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('total'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      CurrencyFormatter.format(total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, double amount, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            CurrencyFormatter.format(amount.abs()),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[200],
      ),
      validator: validator,
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: RadioListTile<String>(
            title: Row(
              children: [
                const Icon(Icons.account_balance, size: 24, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('bankTransfer'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t('bankTransferAccount'),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 36),
              child: Text(
                _t('bankTransferNote'),
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
            value: 'bacs',
            groupValue: _selectedPaymentMethod,
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
            activeColor: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: RadioListTile<String>(
            title: Row(
              children: [
                Image.asset(
                  'assets/images/midtrans_logo.png',
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.payment,
                        size: 24, color: Colors.deepPurple);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('otherOnlinePayments'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t('viaMidtrans'),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 36),
              child: Text(
                _t('midtransPaymentMethods'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            value: 'midtrans',
            groupValue: _selectedPaymentMethod,
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
            activeColor: Colors.deepPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
      BuildContext context, CartProvider cart, AuthProvider auth) {
    return Consumer<CouponProvider>(
      builder: (context, couponProvider, child) {
        final subtotal = cart.total;
        final discount = couponProvider.calculateDiscount(subtotal);
        final subtotalAfterDiscount = subtotal - discount;
        final shippingCost = (_selectedShipping?.cost ?? 0).toDouble();
        final total = subtotalAfterDiscount + shippingCost;

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('totalPayment'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      if (discount > 0)
                        Text(
                          '${_t('youSave')} ${CurrencyFormatter.format(discount)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        loading ? null : () => _handleCheckout(cart, auth),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selectedPaymentMethod == 'bacs'
                                ? _t('placeOrder')
                                : _t('payNow'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCheckout(CartProvider cart, AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('pleaseCompleteAllData')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('pleaseSelectDeliveryLocation')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('yourCartIsEmptyMsg')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ ADDED - cek MOQ sebelum kirim order ke REST API.
    // Ini cuma buat UX (biar user tau lebih cepat tanpa nunggu round-trip
    // ke server); validasi final & wajib tetap di server lewat
    // validate_moq_rest_order() di plugin wc-moq-per-product.
    final moqViolations = cart.items
        .where(
            (item) => item.product.hasMoq && item.quantity < item.product.moq)
        .toList();

    if (moqViolations.isNotEmpty) {
      final firstViolation = moqViolations.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ${firstViolation.product.name}: minimum pembelian '
            '${firstViolation.product.moq} item (saat ini ${firstViolation.quantity}).',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_selectedShipping == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('pleaseChooseShippingMethod')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final wooOrder = await _createWooCommerceOrder(cart, auth);
      final orderId = wooOrder['id'].toString();

      if (!mounted) return;

      if (_selectedPaymentMethod == 'midtrans') {
        final snapToken = await _getMidtransSnapToken(orderId, cart);

        if (!mounted) return;

        await _openMidtransPayment(snapToken, orderId, cart);
      } else {
        final couponProvider =
            Provider.of<CouponProvider>(context, listen: false);
        couponProvider.removeCoupon();
        await cart.clearCart();
        _showBankTransferInstructions(orderId);
      }
    } catch (err) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('checkoutFailed')}: ${err.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _createWooCommerceOrder(
    CartProvider cart,
    AuthProvider auth,
  ) async {
    final couponProvider = Provider.of<CouponProvider>(context, listen: false);

    final subtotal = cart.total;
    final discount = couponProvider.calculateDiscount(subtotal);
    final subtotalAfterDiscount = subtotal - discount;

    final streetAddress = _apartmentController.text.isEmpty
        ? _addressController.text
        : '${_addressController.text}, ${_apartmentController.text}';

    final fullLocationDetail = [
      if (_selectedSubdistrict != null) _selectedSubdistrict!.name,
      if (_selectedDistrict != null) _selectedDistrict!.name,
    ].join(', ');

    final cityName = _selectedCity?.name ?? '';

    final orderData = {
      'payment_method': _selectedPaymentMethod,
      'payment_method_title': _selectedPaymentMethod == 'bacs'
          ? 'Transfer Bank'
          : 'Midtrans Payment Gateway',
      'set_paid': false,
      'billing': {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'company': _companyController.text.trim(),
        'address_1': streetAddress,
        'address_2': fullLocationDetail,
        'city': cityName,
        'state': _selectedProvince?.name ?? '',
        'postcode':
            _selectedSubdistrict?.zipCode ?? _selectedDistrict?.zipCode ?? '',
        'country': 'ID',
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
      },
      'shipping': {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'company': _companyController.text.trim(),
        'address_1': streetAddress,
        'address_2': fullLocationDetail,
        'city': cityName,
        'state': _selectedProvince?.name ?? '',
        'postcode':
            _selectedSubdistrict?.zipCode ?? _selectedDistrict?.zipCode ?? '',
        'country': 'ID',
      },
      'line_items': cart.items
          .map((item) => {
                'product_id': int.parse(item.product.id),
                'quantity': item.quantity,
              })
          .toList(),
      if (couponProvider.hasCoupon)
        'coupon_lines': [
          {'code': couponProvider.appliedCoupon!.code}
        ],
      'shipping_lines': [
        {
          'method_id': _selectedShipping!.code,
          'method_title': _selectedShipping!.displayName,
          'total': _selectedShipping!.cost.toString(),
          'meta_data': [
            {'key': 'courier_code', 'value': _selectedShipping!.code},
            {'key': 'courier_name', 'value': _selectedShipping!.name},
            {'key': 'service_code', 'value': _selectedShipping!.service},
            {'key': 'duration', 'value': _selectedShipping!.etd},
            {'key': 'description', 'value': _selectedShipping!.description},
          ],
        }
      ],
      'customer_note': _orderNotesController.text,
      'meta_data': [
        {
          'key': '_customer_user',
          'value': auth.userId ?? '0',
        },
        {
          'key': '_shipping_rajaongkir_data',
          'value': {
            'province_id': _selectedProvince?.id,
            'province_name': _selectedProvince?.name,
            'city_id': _selectedCity?.id,
            'city_name': _selectedCity?.name,
            'district_id': _selectedDistrict?.id,
            'district_name': _selectedDistrict?.name,
            'subdistrict_id': _selectedSubdistrict?.id,
            'subdistrict_name': _selectedSubdistrict?.name,
            'postal_code':
                _selectedSubdistrict?.zipCode ?? _selectedDistrict?.zipCode,
            'full_address':
                '$streetAddress, $fullLocationDetail, $cityName, ${_selectedProvince?.name ?? ''}',
            'courier_code': _selectedShipping!.code,
            'courier_name': _selectedShipping!.name,
            'service_code': _selectedShipping!.service,
            'price': _selectedShipping!.cost,
            'duration': _selectedShipping!.etd,
          },
        },
        {
          'key': '_shipping_district',
          'value': _selectedDistrict?.name ?? '',
        },
        {
          'key': '_shipping_district_id',
          'value': _selectedDistrict?.id.toString() ?? '',
        },
        {
          'key': '_shipping_subdistrict',
          'value': _selectedSubdistrict?.name ?? '',
        },
        {
          'key': '_shipping_subdistrict_id',
          'value': _selectedSubdistrict?.id.toString() ?? '',
        },
        if (_isDropshipper) ...[
          {
            'key': '_dropshipper_name',
            'value': _dropshipperNameController.text.trim(),
          },
          {
            'key': '_dropshipper_phone',
            'value': _dropshipperPhoneController.text.trim(),
          },
          {
            'key': '_is_dropshipper',
            'value': 'yes',
          },
        ],
      ],
    };

    final result = await wooCommerceService.createOrder(orderData);
    debugPrint('✅ WooCommerce Order Created: ${result['id']}');

    if (couponProvider.hasCoupon) {
      debugPrint('✅ Coupon applied: ${couponProvider.appliedCoupon!.code}');
      debugPrint('✅ Discount amount: ${CurrencyFormatter.format(discount)}');
    }

    if (_isDropshipper) {
      debugPrint('📦 Dropshipper: ${_dropshipperNameController.text.trim()}');
      debugPrint(
          '📞 Dropshipper Phone: ${_dropshipperPhoneController.text.trim()}');
    }

    debugPrint(
        '✅ Shipping: ${_selectedShipping!.displayName} - ${_selectedShipping!.displayPrice}');
    debugPrint(
        '📍 Full Address: $streetAddress, $fullLocationDetail, $cityName');

    return result;
  }

  Future<String> _getMidtransSnapToken(
      String orderId, CartProvider cart) async {
    final couponProvider = Provider.of<CouponProvider>(context, listen: false);

    final subtotal = cart.total;
    final shippingCost = (_selectedShipping!.cost).toDouble();
    final discount = couponProvider.calculateDiscount(subtotal);
    final subtotalAfterDiscount = subtotal - discount;
    final total = subtotalAfterDiscount + shippingCost;

    final customerDetails = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'billing_address': {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _selectedCity?.name ?? '',
        'postal_code':
            _selectedSubdistrict?.zipCode ?? _selectedDistrict?.zipCode ?? '',
        'country_code': 'IDN',
      },
      'shipping_address': {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _selectedCity?.name ?? '',
        'postal_code':
            _selectedSubdistrict?.zipCode ?? _selectedDistrict?.zipCode ?? '',
        'country_code': 'IDN',
      },
    };

    final itemDetails = <Map<String, dynamic>>[];

    for (var item in cart.items) {
      String itemName = item.product.name;
      if (itemName.length > 50) {
        itemName = '${itemName.substring(0, 47)}...';
      }

      itemDetails.add({
        'id': item.product.id,
        'price': item.product.price.toInt(),
        'quantity': item.quantity,
        'name': itemName,
      });
    }

    if (discount > 0) {
      itemDetails.add({
        'id': 'DISCOUNT',
        'price': -(discount.toInt()),
        'quantity': 1,
        'name': '${_t('discount')} (${couponProvider.appliedCoupon!.code})',
      });
    }

    itemDetails.add({
      'id': 'SHIPPING',
      'price': shippingCost.toInt(),
      'quantity': 1,
      'name': _selectedShipping!.displayName,
    });

    debugPrint('📊 Midtrans Total: ${total.toInt()}');
    if (discount > 0) {
      debugPrint('🎟️ Discount: ${discount.toInt()}');
    }

    try {
      final snapToken = await midtransService.getSnapToken(
        orderId: orderId,
        grossAmount: total.toDouble(),
        itemDetails: itemDetails,
        customerDetails: customerDetails,
      );

      return midtransService.buildSnapUrl(snapToken);
    } catch (e) {
      debugPrint('❌ Midtrans Error: $e');
      throw Exception('Gagal mendapatkan snap token Midtrans. '
          'Silakan cek konfigurasi server key atau gunakan sandbox mode.');
    }
  }

  Future<void> _openMidtransPayment(
    String snapToken,
    String orderId,
    CartProvider cart,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MidtransPaymentScreen(
          paymentUrl: snapToken,
          orderId: orderId,
          currentLocale: _currentLocale,
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'success' || result == 'pending') {
      final couponProvider =
          Provider.of<CouponProvider>(context, listen: false);
      couponProvider.removeCoupon();

      await cart.clearCart();

      setState(() {
        loading = false;
      });

      if (result == 'success') {
        _showSuccessDialog(orderId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('paymentPending')),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/orders', (route) => false);
      }
    } else if (result == 'failed') {
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('paymentFailed')),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _t('paymentSuccessful'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t('orderCreatedSuccessfully'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${_t('orderId')}: $orderId',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/main',
                (route) => false,
              );
            },
            child: Text(_t('backToHome')),
          ),
        ],
      ),
    );
  }

  void _showBankTransferInstructions(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                const Icon(
                  Icons.account_balance,
                  color: Colors.blue,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _t('orderSuccessfullyPlaced'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${_t('orderId')} #$orderId',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('pleaseTransferPaymentTo'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBankInfoRow(_t('bank'), 'BCA'),
                        const SizedBox(height: 8),
                        _buildBankInfoRow(_t('accountNo'), '5710900711'),
                        const SizedBox(height: 8),
                        _buildBankInfoRow(
                            _t('accountName'), 'PT. Bambi Mega Niaga'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _t('important'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_t('uploadProofBelow')}\n'
                          '${_t('includeOrderNumber')}\n'
                          '${_t('orderProcessedAfterConfirmation')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.green.shade300, width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.upload_file,
                                color: Colors.green.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _t('uploadPaymentProof'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_paymentProof != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _paymentProof!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!_isUploading)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final result =
                                        await _pickImageSource(context);
                                    if (result != null) {
                                      setDialogState(() {
                                        _paymentProof = result;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.photo_library),
                                  label: Text(_t('selectPhoto')),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade700,
                                    side: BorderSide(
                                        color: Colors.green.shade700),
                                  ),
                                ),
                              ),
                              if (_paymentProof != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      await _uploadPaymentProofFromCheckout(
                                        orderId,
                                        setDialogState,
                                      );
                                    },
                                    icon: const Icon(Icons.cloud_upload),
                                    label: Text(_t('upload')),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        else
                          Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(
                                _t('uploadingPaymentProof'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!_isUploading) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      _paymentProof = null;
                    });
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/main',
                      (route) => false,
                    );
                  },
                  child: Text(_t('close')),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _paymentProof = null;
                    });
                    Navigator.of(context).pop();
                    Navigator.pushNamed(
                      context,
                      '/order-detail',
                      arguments: int.parse(orderId),
                    );
                  },
                  child: Text(_t('viewOrder')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// SelectLocationScreen
class SelectLocationScreen extends StatefulWidget {
  final Locale currentLocale;

  const SelectLocationScreen({
    super.key,
    required this.currentLocale,
  });

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  String _t(String key) {
    return AppLocalizations(widget.currentLocale).translate(key);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ShippingProvider>(context, listen: false);
      if (provider.provinces.isEmpty) {
        provider.loadProvinces();
      }
    });
  }

  void _selectSubdistrict(Subdistrict subdistrict) {
    final provider = Provider.of<ShippingProvider>(context, listen: false);
    provider.selectSubdistrict(subdistrict);
    Navigator.pop(context, {'subdistrict': subdistrict});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('selectDeliveryLocation')),
        elevation: 0,
      ),
      body: Consumer<ShippingProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('province'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (provider.isLoadingProvinces)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<Province>(
                    initialValue: provider.selectedProvince,
                    decoration: InputDecoration(
                      hintText: _t('selectProvince'),
                      border: const OutlineInputBorder(),
                    ),
                    items: provider.provinces.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) provider.selectProvince(value);
                    },
                  ),
                const SizedBox(height: 16),
                if (provider.selectedProvince != null) ...[
                  Text(_t('cityRegency'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (provider.isLoadingCities)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<City>(
                      initialValue: provider.selectedCity,
                      decoration: InputDecoration(
                        hintText: _t('selectCity'),
                        border: const OutlineInputBorder(),
                      ),
                      items: provider.cities.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c.name));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) provider.selectCity(value);
                      },
                    ),
                  const SizedBox(height: 16),
                ],
                if (provider.selectedCity != null) ...[
                  Text(_t('district'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (provider.isLoadingDistricts)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<District>(
                      initialValue: provider.selectedDistrict,
                      decoration: InputDecoration(
                        hintText: _t('selectDistrict'),
                        border: const OutlineInputBorder(),
                      ),
                      items: provider.districts.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d.name));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) provider.selectDistrict(value);
                      },
                    ),
                  const SizedBox(height: 16),
                ],
                if (provider.selectedDistrict != null) ...[
                  Text(_t('subdistrict'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (provider.isLoadingSubdistricts)
                    const Center(child: CircularProgressIndicator())
                  else if (provider.subdistricts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(_t('noSubdistrictFound')),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.subdistricts.length,
                      itemBuilder: (context, index) {
                        final sub = provider.subdistricts[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_on,
                                color: Colors.blue),
                            title: Text(sub.name),
                            subtitle:
                                Text('${_t('postalCode')}: ${sub.zipCode}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectSubdistrict(sub),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Midtrans Payment WebView Screen
class MidtransPaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final Locale currentLocale;

  const MidtransPaymentScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    required this.currentLocale,
  });

  @override
  State<MidtransPaymentScreen> createState() => _MidtransPaymentScreenState();
}

class _MidtransPaymentScreenState extends State<MidtransPaymentScreen> {
  late final WebViewController _controller;
  bool isLoading = true;

  String _t(String key) {
    return AppLocalizations(widget.currentLocale).translate(key);
  }

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
            });
            _checkPaymentStatus(url);
          },
          onPageFinished: (url) {
            setState(() {
              isLoading = false;
            });
          },
          onNavigationRequest: (request) {
            _checkPaymentStatus(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentStatus(String url) {
    if (url.contains('status_code=200') ||
        url.contains('transaction_status=settlement') ||
        url.contains('transaction_status=capture')) {
      Navigator.pop(context, 'success');
    } else if (url.contains('transaction_status=pending')) {
      Navigator.pop(context, 'pending');
    } else if (url.contains('status_code=202') ||
        url.contains('transaction_status=deny') ||
        url.contains('transaction_status=cancel') ||
        url.contains('transaction_status=expire') ||
        url.contains('transaction_status=failure')) {
      Navigator.pop(context, 'failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('payment')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showCancelDialog();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('cancelPayment')),
        content: Text(_t('cancelPaymentConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('no')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, 'cancelled');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(_t('yesCancel')),
          ),
        ],
      ),
    );
  }
}
