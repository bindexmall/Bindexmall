// ============================================================================
// SCREEN: TrackOrderScreen
// ============================================================================
// Halaman lacak status pengiriman pesanan (menampilkan histori status order).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/woocommerce_service.dart';
import '../utils/currency_formatter.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIdController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  Map<String, dynamic>? _orderData;
  String? _errorMessage;

  @override
  void dispose() {
    _orderIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  Future<void> _trackOrder(Locale locale) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _orderData = null;
    });

    try {
      // Parse order ID (remove # if exists)
      final orderIdStr = _orderIdController.text.trim().replaceAll('#', '');
      final orderId = int.tryParse(orderIdStr);
      
      if (orderId == null) {
        throw Exception(
          locale.languageCode == 'en'
              ? 'Invalid order ID format'
              : 'Format ID pesanan tidak valid'
        );
      }

      // Get order from WooCommerce
      final order = await wooCommerceService.getOrderById(orderId);
      
      // Verify email matches
      final billingEmail = order['billing']?['email']?.toString().toLowerCase();
      final inputEmail = _emailController.text.trim().toLowerCase();
      
      if (billingEmail != inputEmail) {
        throw Exception(
          locale.languageCode == 'en'
              ? 'Order not found. Please check your Order ID and email address.'
              : 'Pesanan tidak ditemukan. Silakan periksa ID Pesanan dan alamat email Anda.'
        );
      }

      setState(() {
        _orderData = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              _t('track', locale),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, 
                color: Theme.of(context).iconTheme.color), // ✅ UBAH
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildTrackingForm(locale),
                if (_isLoading) _buildLoadingState(locale),
                if (_errorMessage != null) _buildErrorState(locale),
                if (_orderData != null) _buildOrderTracking(locale),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackingForm(Locale locale) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale.languageCode == 'en'
                            ? 'Track Your Order'
                            : 'Lacak Pesanan Anda',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        locale.languageCode == 'en'
                            ? 'Enter your order details'
                            : 'Masukkan detail pesanan Anda',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Order ID Field
            TextFormField(
              controller: _orderIdController,
              decoration: InputDecoration(
                labelText: locale.languageCode == 'en' ? 'Order ID' : 'ID Pesanan',
                hintText: 'e.g., 12345 or #12345',
                prefixIcon: const Icon(Icons.tag),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50], // ✅ UBAH
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return locale.languageCode == 'en'
                      ? 'Please enter your order ID'
                      : 'Silakan masukkan ID pesanan Anda';
                }
                final orderIdStr = value.trim().replaceAll('#', '');
                if (int.tryParse(orderIdStr) == null) {
                  return locale.languageCode == 'en'
                      ? 'Please enter a valid order ID'
                      : 'Silakan masukkan ID pesanan yang valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Email Field
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: _t('emailAddress', locale),
                hintText: locale.languageCode == 'en' ? 'Enter your email' : 'Masukkan email Anda',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50], // ✅ UBAH
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return locale.languageCode == 'en'
                      ? 'Please enter your email'
                      : 'Silakan masukkan email Anda';
                }
                if (!value.contains('@')) {
                  return locale.languageCode == 'en'
                      ? 'Please enter a valid email'
                      : 'Silakan masukkan email yang valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Track Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : () => _trackOrder(locale),
                icon: const Icon(Icons.search),
                label: Text(
                  locale.languageCode == 'en' ? 'Track Order' : 'Lacak Pesanan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      locale.languageCode == 'en'
                          ? 'You can find your order ID in the confirmation email sent to you.'
                          : 'Anda dapat menemukan ID pesanan Anda di email konfirmasi yang dikirimkan kepada Anda.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
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

  Widget _buildLoadingState(Locale locale) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅ UBAH
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            locale.languageCode == 'en'
                ? 'Tracking your order...'
                : 'Melacak pesanan Anda...',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600], // ✅ UBAH
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Locale locale) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅ UBAH
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            locale.languageCode == 'en'
                ? 'Order Not Found'
                : 'Pesanan Tidak Ditemukan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600], // ✅ UBAH
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTracking(Locale locale) {
    final order = _orderData!;
    final status = order['status'] ?? 'pending';
    final orderNumber = '#${order['id']}';
    final dateCreated = DateTime.parse(order['date_created']);
    final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.languageCode == 'en' ? 'Order Number' : 'Nomor Pesanan',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          orderNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(status, locale),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy - HH:mm').format(dateCreated),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Tracking Timeline
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('orderStatus', locale),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                _buildTrackingTimeline(status, locale),
                
                const Divider(height: 48),
                
                // Order Details
                Text(
                  locale.languageCode == 'en' ? 'Order Details' : 'Detail Pesanan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                _buildDetailRow(
                  locale.languageCode == 'en' ? 'Total Amount' : 'Total Pembayaran',
                  CurrencyFormatter.format(total),
                ),
                _buildDetailRow(
                  _t('paymentMethod', locale),
                  order['payment_method_title'] ?? 'N/A',
                ),
                _buildDetailRow(
                  locale.languageCode == 'en' ? 'Items' : 'Item',
                  '${(order['line_items'] as List).length}',
                ),
                
                // Shipping Address
                if (order['shipping'] != null) ...[
                  const Divider(height: 32),
                  Text(
                    locale.languageCode == 'en' ? 'Shipping Address' : 'Alamat Pengiriman',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[50], // ✅ UBAH
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : Colors.grey[200]!, // ✅ UBAH
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order['shipping']['first_name']} ${order['shipping']['last_name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order['shipping']['address_1'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        if (order['shipping']['address_2'] != null &&
                            order['shipping']['address_2'].toString().isNotEmpty)
                          Text(
                            order['shipping']['address_2'],
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        Text(
                          '${order['shipping']['city']}, ${order['shipping']['state']} ${order['shipping']['postcode']}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        if (order['shipping']['phone'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  order['shipping']['phone'],
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                
                // Order Items
                const Divider(height: 32),
                Text(
                  locale.languageCode == 'en' ? 'Order Items' : 'Item Pesanan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                
                ...(order['line_items'] as List).map((item) {
                  final itemPrice = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                  final quantity = item['quantity'] ?? 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[50], // ✅ UBAH
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? (locale.languageCode == 'en' ? 'Product' : 'Produk'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${locale.languageCode == 'en' ? 'Qty' : 'Jml'}: $quantity',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(itemPrice * quantity),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Locale locale) {
    Color color;
    String displayText;
    
    switch (status.toLowerCase()) {
      case 'pending':
      case 'on-hold':
        color = Colors.orange;
        displayText = locale.languageCode == 'en' ? 'Pending' : 'Tertunda';
        break;
      case 'processing':
        color = Colors.blue;
        displayText = locale.languageCode == 'en' ? 'Processing' : 'Diproses';
        break;
      case 'completed':
        color = Colors.green;
        displayText = locale.languageCode == 'en' ? 'Completed' : 'Selesai';
        break;
      case 'cancelled':
      case 'refunded':
      case 'failed':
        color = Colors.red;
        displayText = locale.languageCode == 'en' ? 'Cancelled' : 'Dibatalkan';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTrackingTimeline(String currentStatus, Locale locale) {
    final stages = [
      {
        'title': locale.languageCode == 'en' ? 'Order Placed' : 'Pesanan Dibuat',
        'status': 'pending',
        'icon': Icons.receipt
      },
      {
        'title': locale.languageCode == 'en' ? 'Processing' : 'Diproses',
        'status': 'processing',
        'icon': Icons.inventory
      },
      {
        'title': locale.languageCode == 'en' ? 'Shipped' : 'Dikirim',
        'status': 'shipped',
        'icon': Icons.local_shipping
      },
      {
        'title': locale.languageCode == 'en' ? 'Delivered' : 'Terkirim',
        'status': 'completed',
        'icon': Icons.check_circle
      },
    ];
    
    int currentIndex = stages.indexWhere((s) => s['status'] == currentStatus);
    if (currentIndex == -1) currentIndex = 0;
    
    return Column(
      children: List.generate(stages.length, (index) {
        final stage = stages[index];
        final isActive = index <= currentIndex;
        final isLast = index == stages.length - 1;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    stage['icon'] as IconData,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isActive ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    if (isActive && index == currentIndex)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          locale.languageCode == 'en' ? 'Current Status' : 'Status Saat Ini',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}