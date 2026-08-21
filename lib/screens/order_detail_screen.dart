// ============================================================================
// SCREEN: OrderDetailScreen
// ============================================================================
// Detail satu pesanan: item, alamat, status, riwayat status, tombol lihat bukti
// bayar / upload bukti bayar (CloudinaryUploadService), tracking pengiriman.
// ============================================================================

import 'package:bindexmall/services/cloudinary_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../utils/currency_formatter.dart';
import '../services/woocommerce_service.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  bool _isUploading = false;
  File? _paymentProof;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadOrderDetail();
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  Future<void> _loadOrderDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final order = await wooCommerceService.getOrderById(widget.orderId);
      setState(() {
        _orderData = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        final locale = languageProvider.currentLocale;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale.languageCode == 'en'
                  ? 'Failed to load order: $e'
                  : 'Gagal memuat pesanan: $e'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String get _paymentMethod => _orderData?['payment_method'] ?? '';
  String get _orderStatus => _orderData?['status'] ?? 'pending';
  bool get _isBankTransfer => _paymentMethod == 'bacs';
  bool get _needsPaymentProof => _isBankTransfer && 
      (_orderStatus == 'pending' || _orderStatus == 'on-hold');

  bool get _hasPaymentProof {
    final metaData = _orderData?['meta_data'] as List?;
    if (metaData != null) {
      return metaData.any((meta) => 
        meta['key'] == '_payment_proof_url' && 
        meta['value'] != null && 
        meta['value'].toString().isNotEmpty
      );
    }
    return false;
  }

  String _getUploadedProofDate(Locale locale) {
    final metaData = _orderData?['meta_data'] as List?;
    if (metaData != null) {
      try {
        final dateMeta = metaData.firstWhere(
          (meta) => meta['key'] == '_payment_proof_uploaded_at',
        );
        final date = DateTime.parse(dateMeta['value']);
        return DateFormat('dd MMM yyyy, HH:mm').format(date);
      } catch (e) {
        return locale.languageCode == 'en' ? 'Unknown date' : 'Tanggal tidak diketahui';
      }
    }
    return locale.languageCode == 'en' ? 'Unknown date' : 'Tanggal tidak diketahui';
  }

  Future<void> _pickImage() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _paymentProof = File(image.path);
        });
        _showUploadConfirmation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('failedToPickImage', locale)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _paymentProof = File(photo.path);
        });
        _showUploadConfirmation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale.languageCode == 'en'
                  ? 'Failed to take photo: $e'
                  : 'Gagal mengambil foto: $e'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUploadConfirmation() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(_t('uploadPaymentProofTitle', locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _paymentProof!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              locale.languageCode == 'en'
                  ? 'Make sure the transfer details are clearly visible'
                  : 'Pastikan detail transfer terlihat jelas',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _paymentProof = null;
              });
              Navigator.pop(context);
            },
            child: Text(_t('cancel', locale)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPaymentProof();
            },
            child: Text(_t('upload', locale)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPaymentProof() async {
    if (_paymentProof == null) return;

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('mustBeLoggedInToUpload', locale)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 Starting payment proof upload...');
      debugPrint('👤 User: ${authProvider.userName} (${authProvider.userId})');
      debugPrint('📧 Email: ${authProvider.userEmail}');
      
      final billing = _orderData?['billing'] as Map<String, dynamic>?;
      final customerName = billing != null 
          ? '${billing['first_name']} ${billing['last_name']}'.trim()
          : authProvider.userName ?? 'Unknown';
      final totalAmount = _orderData?['total']?.toString();
      
      debugPrint('💳 Order ID: ${widget.orderId}');
      debugPrint('👤 Customer: $customerName');
      debugPrint('💰 Amount: $totalAmount');
      
      // ✅ UPLOAD TO CLOUDINARY
      final result = await cloudinaryUploadService.uploadPaymentProof(
        proofFile: _paymentProof!,
        orderId: widget.orderId.toString(),
        customerName: customerName,
        customerEmail: authProvider.userEmail,
        transferAmount: totalAmount,
      );

      if (result == null) {
        throw Exception(
          locale.languageCode == 'en'
              ? 'Upload failed. Please try again.'
              : 'Upload gagal. Silakan coba lagi.'
        );
      }

      final imageUrl = result['url'];
      final mediaId = result['id'];
      
      debugPrint('✅ Image uploaded: $imageUrl');
      debugPrint('✅ Media ID: $mediaId');
      
      // Update WooCommerce order metadata
      final updateSuccess = await wooCommerceService.updateOrderMetaData(
        orderId: widget.orderId,
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
        throw Exception(
          locale.languageCode == 'en'
              ? 'Failed to update order metadata'
              : 'Gagal memperbarui metadata pesanan'
        );
      }

      debugPrint('✅ Order metadata updated');
      
      // Add order note
      await wooCommerceService.addOrderNote(
        orderId: widget.orderId,
        note: '💳 Customer uploaded payment proof.\n'
              'Customer: $customerName\n'
              'Email: ${authProvider.userEmail}\n'
              'View: $imageUrl\n'
              'Uploaded: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        isCustomerNote: false,
      );

      debugPrint('✅ Order note added');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      setState(() {
        _isUploading = false;
        _paymentProof = null;
      });

      await _loadOrderDetail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_t('paymentProofUploadedSuccessfully', locale)),
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
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('noInternetConnection', locale)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        if (errorMessage.contains('Not authenticated')) {
          errorMessage = _t('sessionExpired', locale);
        } else if (errorMessage.contains('Authentication failed')) {
          errorMessage = _t('authenticationFailed', locale);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('failedToUpload', locale)}: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: errorMessage.contains(_t('login', locale).toLowerCase())
                ? SnackBarAction(
                    label: _t('loginToUpload', locale),
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

  void _showUploadOptions() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('mustBeLoggedInToUpload', locale)),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: _t('loginToUpload', locale),
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
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
              _t('uploadPaymentProof', locale),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${locale.languageCode == 'en' ? 'Logged in as' : 'Login sebagai'}: ${authProvider.userName ?? authProvider.userEmail}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text(_t('chooseFromGallery', locale)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: Text(_t('takePhoto', locale)),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            title: Text(
              _isLoading 
                  ? _t('orderDetail', locale)
                  : '${_t('order', locale)} #${widget.orderId}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
              Consumer<AuthProvider>(
                builder: (context, auth, child) {
                  if (!auth.isAuthenticated) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.login, color: Colors.orange),
                        tooltip: locale.languageCode == 'en'
                            ? 'Login to upload proof'
                            : 'Login untuk upload bukti',
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orderData == null
                  ? _buildErrorState(locale)
                  : RefreshIndicator(
                      onRefresh: _loadOrderDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildStatusCard(locale),
                            const SizedBox(height: 12),
                            _buildPaymentInfoCard(locale),
                            if (_needsPaymentProof) ...[
                              const SizedBox(height: 12),
                              _buildUploadSection(locale),
                            ],
                            const SizedBox(height: 12),
                            _buildOrderSummaryCard(locale),
                            const SizedBox(height: 12),
                            _buildShippingAddressCard(locale),
                            const SizedBox(height: 12),
                            _buildItemsCard(locale),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildErrorState(Locale locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            locale.languageCode == 'en'
                ? 'Failed to load order details'
                : 'Gagal memuat detail pesanan'
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loadOrderDetail,
            child: Text(_t('retry', locale)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Locale locale) {
    final status = _orderData!['status'] ?? 'pending';
    final date = DateTime.parse(_orderData!['date_created']);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('orderStatus', locale),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(status, locale),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(date),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard(Locale locale) {
    final paymentMethod = _orderData!['payment_method_title'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('paymentMethod', locale),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isBankTransfer ? Icons.account_balance : Icons.payment,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    paymentMethod,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            if (_isBankTransfer) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.languageCode == 'en'
                          ? 'Bank Transfer Details'
                          : 'Detail Transfer Bank',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Bank: BCA', style: TextStyle(fontSize: 13)),
                    Text(
                      '${locale.languageCode == 'en' ? 'Account' : 'Rekening'}: 5710900711',
                      style: const TextStyle(fontSize: 13)
                    ),
                    Text(
                      '${locale.languageCode == 'en' ? 'Name' : 'Nama'}: PT. Bambi Mega Niaga',
                      style: const TextStyle(fontSize: 13)
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

  Widget _buildUploadSection(Locale locale) {
    if (_hasPaymentProof) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green[200]!, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      locale.languageCode == 'en'
                          ? 'Payment Proof Uploaded'
                          : 'Bukti Pembayaran Terupload',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${locale.languageCode == 'en' ? 'Uploaded on' : 'Diupload pada'} ${_getUploadedProofDate(locale)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locale.languageCode == 'en'
                            ? 'Your payment is being verified by our team'
                            : 'Pembayaran Anda sedang diverifikasi oleh tim kami',
                        style: const TextStyle(fontSize: 12),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t('uploadPaymentProof', locale),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Consumer<AuthProvider>(
              builder: (context, auth, child) {
                if (!auth.isAuthenticated) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t('mustBeLoggedInToUpload', locale),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.languageCode == 'en' ? '⚠️ Important:' : '⚠️ Penting:',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.languageCode == 'en'
                        ? '• Upload clear photo of transfer receipt\n'
                          '• Include order number in transfer notes\n'
                          '• Payment will be verified within 1x24 hours'
                        : '• Upload foto bukti transfer yang jelas\n'
                          '• Sertakan nomor pesanan di catatan transfer\n'
                          '• Pembayaran akan diverifikasi dalam 1x24 jam',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isUploading ? null : _showUploadOptions,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(
                  _isUploading 
                      ? _t('uploadingPaymentProof', locale)
                      : (locale.languageCode == 'en' ? 'Upload Now' : 'Upload Sekarang')
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(Locale locale) {
    final total = double.tryParse(_orderData!['total']?.toString() ?? '0') ?? 0.0;
    final subtotal = double.tryParse(_orderData!['subtotal']?.toString() ?? '0') ?? 0.0;
    final shippingTotal = double.tryParse(_orderData!['shipping_total']?.toString() ?? '0') ?? 0.0;
    final totalTax = double.tryParse(_orderData!['total_tax']?.toString() ?? '0') ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('orderSummary', locale),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(_t('subtotal', locale), subtotal),
            _buildSummaryRow(
              locale.languageCode == 'en' ? 'Shipping' : 'Pengiriman',
              shippingTotal
            ),
            if (totalTax > 0) _buildSummaryRow(
              locale.languageCode == 'en' ? 'Tax' : 'Pajak',
              totalTax
            ),
            const Divider(height: 24),
            _buildSummaryRow(_t('total', locale), total, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black : Colors.grey[600],
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Theme.of(context).colorScheme.primary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddressCard(Locale locale) {
    final shipping = _orderData!['shipping'] as Map<String, dynamic>?;
    if (shipping == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locale.languageCode == 'en' ? 'Shipping Address' : 'Alamat Pengiriman',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${shipping['first_name']} ${shipping['last_name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shipping['phone'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${shipping['address_1']}\n'
                        '${shipping['address_2'] ?? ''}\n'
                        '${shipping['city']}, ${shipping['state']} ${shipping['postcode']}\n'
                        '${shipping['country'] ?? 'Indonesia'}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(Locale locale) {
    final items = _orderData!['line_items'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locale.languageCode == 'en' ? 'Order Items' : 'Item Pesanan',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _buildItemRow(item, locale)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item, Locale locale) {
    final name = item['name'] ?? (locale.languageCode == 'en' ? 'Unknown Product' : 'Produk Tidak Diketahui');
    final quantity = item['quantity'] ?? 1;
    final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
    final total = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shopping_bag, color: Colors.grey[400]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${locale.languageCode == 'en' ? 'Qty' : 'Jml'}: $quantity × ${CurrencyFormatter.format(price)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(total),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Locale locale) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        displayText = locale.languageCode == 'en' ? 'Waiting Payment' : 'Menunggu Pembayaran';
        break;
      case 'on-hold':
        backgroundColor = Colors.yellow[50]!;
        textColor = Colors.yellow[700]!;
        displayText = locale.languageCode == 'en' ? 'On Hold' : 'Ditahan';
        break;
      case 'processing':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        displayText = locale.languageCode == 'en' ? 'Processing' : 'Diproses';
        break;
      case 'completed':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        displayText = locale.languageCode == 'en' ? 'Delivered' : 'Terkirim';
        break;
      case 'cancelled':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        displayText = locale.languageCode == 'en' ? 'Cancelled' : 'Dibatalkan';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}