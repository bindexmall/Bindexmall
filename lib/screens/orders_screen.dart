// ============================================================================
// SCREEN: OrdersScreen + Order + OrderItem
// ============================================================================
// Daftar riwayat pesanan user (dengan filter status) via OrderRepository.
//
// Catatan:
//  - Order & OrderItem di file ini adalah model LOKAL khusus untuk screen ini —
//  -   bukan model resmi di folder models/. Kalau butuh struktur order di tempat lain,
//  -   pertimbangkan pindahkan ke models/ supaya tidak duplikat definisi.
// ============================================================================

import 'package:bindexmall/services/order_tracking_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../repositories/order_repository.dart';
import '../utils/currency_formatter.dart';
import '../l10n/app_localizations.dart';
import 'order_detail_screen.dart';

class Order {
  final String id;
  final int orderId;
  final DateTime date;
  final double totalAmount;
  final String status;
  final String rawStatus;
  final List<OrderItem> items;
  final Map<String, dynamic>? billing;
  final Map<String, dynamic>? shipping;

  Order({
    required this.id,
    required this.orderId,
    required this.date,
    required this.totalAmount,
    required this.status,
    required this.rawStatus,
    required this.items,
    this.billing,
    this.shipping,
  });

  factory Order.fromWooCommerce(Map<String, dynamic> data, Locale locale) {
    final lineItems = (data['line_items'] as List?) ?? [];
    final rawStatus = data['status'] ?? 'pending';
    
    return Order(
      id: '#${data['id']}',
      orderId: data['id'],
      date: DateTime.parse(data['date_created'] ?? DateTime.now().toIso8601String()),
      totalAmount: double.tryParse(data['total']?.toString() ?? '0') ?? 0.0,
      status: _mapWooCommerceStatus(rawStatus, locale),
      rawStatus: rawStatus,
      items: lineItems.map((item) => OrderItem.fromWooCommerce(item, locale)).toList(),
      billing: data['billing'],
      shipping: data['shipping'],
    );
  }

  static String _mapWooCommerceStatus(String wooStatus, Locale locale) {
    final isEnglish = locale.languageCode == 'en';
    
    switch (wooStatus.toLowerCase()) {
      case 'pending':
        return isEnglish ? 'Waiting Payment' : 'Menunggu Pembayaran';
      case 'on-hold':
        return isEnglish ? 'On Hold' : 'Ditahan';
      case 'processing':
        return isEnglish ? 'Processing' : 'Diproses';
      case 'completed':
        return isEnglish ? 'Delivered' : 'Terkirim';
      case 'cancelled':
        return isEnglish ? 'Cancelled' : 'Dibatalkan';
      case 'refunded':
        return isEnglish ? 'Refunded' : 'Dikembalikan';
      case 'failed':
        return isEnglish ? 'Failed' : 'Gagal';
      default:
        return isEnglish ? 'Processing' : 'Diproses';
    }
  }
}

class OrderItem {
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.imageUrl,
  });

  factory OrderItem.fromWooCommerce(Map<String, dynamic> data, Locale locale) {
    return OrderItem(
      productId: data['product_id'] ?? 0,
      productName: data['name'] ?? (locale.languageCode == 'en' ? 'Unknown Product' : 'Produk Tidak Diketahui'),
      quantity: data['quantity'] ?? 1,
      price: double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: data['image']?['src'],
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _allOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  Future<void> _loadOrders() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (!authProvider.isAuthenticated || authProvider.userId == null) {
        setState(() {
          _allOrders = [];
          _isLoading = false;
        });
        return;
      }

      final customerId = int.tryParse(authProvider.userId!);
      
      if (customerId == null) {
        throw Exception(
          locale.languageCode == 'en'
              ? 'Invalid customer ID'
              : 'ID pelanggan tidak valid'
        );
      }


      final ordersData = await orderRepository.fetchOrdersWithFallback(
        customerId: customerId,
        email: authProvider.userEmail,
        perPage: 50,
      );


      final orders = ordersData.map((data) {
        return Order.fromWooCommerce(data, locale);
      }).toList();

      orders.sort((a, b) => b.date.compareTo(a.date));

      await orderTrackingService.checkNow();

      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
      
      for (var order in _allOrders) {
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale.languageCode == 'en'
                  ? 'Failed to load orders: $e'
                  : 'Gagal memuat pesanan: $e'
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<Order> _getOrdersByStatus(String status) {
    if (status == 'All') return _allOrders;
    return _allOrders.where((order) => order.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        final authProvider = Provider.of<AuthProvider>(context);

        if (!authProvider.isAuthenticated) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                _t('myOrders', locale),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: _buildLoginRequired(locale),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              _t('myOrders', locale),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              isScrollable: true,
              tabs: [
                Tab(text: _t('all', locale)),
                Tab(text: locale.languageCode == 'en' ? 'Waiting Payment' : 'Menunggu Pembayaran'),
                Tab(text: locale.languageCode == 'en' ? 'On Hold' : 'Ditahan'),
                Tab(text: locale.languageCode == 'en' ? 'Processing' : 'Diproses'),
                Tab(text: locale.languageCode == 'en' ? 'Delivered' : 'Terkirim'),
                Tab(text: locale.languageCode == 'en' ? 'Cancelled' : 'Dibatalkan'),
                Tab(text: locale.languageCode == 'en' ? 'Refunded' : 'Dikembalikan'),
                Tab(text: locale.languageCode == 'en' ? 'Failed' : 'Gagal'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorState(locale)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrdersList('All', locale),
                        _buildOrdersList(locale.languageCode == 'en' ? 'Waiting Payment' : 'Menunggu Pembayaran', locale),
                        _buildOrdersList(locale.languageCode == 'en' ? 'On Hold' : 'Ditahan', locale),
                        _buildOrdersList(locale.languageCode == 'en' ? 'Processing' : 'Diproses', locale),
                        _buildOrdersList(locale.languageCode == 'en' ? 'Delivered' : 'Terkirim', locale),
                        _buildOrdersList(locale.languageCode == 'en' ? 'Cancelled' : 'Dibatalkan', locale),
                        _buildOrdersList(locale.languageCode == 'en' ? 'Refunded' : 'Dikembalikan', locale),
                        _buildOrdersList(locale.languageCode == 'en' ? 'Failed' : 'Gagal', locale),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildLoginRequired(Locale locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _t('loginRequired', locale),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            locale.languageCode == 'en'
                ? 'Please login to view your orders'
                : 'Silakan login untuk melihat pesanan Anda',
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            child: Text(_t('loginNow', locale)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Locale locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            locale.languageCode == 'en'
                ? 'Error Loading Orders'
                : 'Kesalahan Memuat Pesanan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? (locale.languageCode == 'en' 
                  ? 'Unknown error occurred' 
                  : 'Terjadi kesalahan yang tidak diketahui'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loadOrders,
            child: Text(_t('retry', locale)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String status, Locale locale) {
    final orders = _getOrdersByStatus(status);

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              locale.languageCode == 'en' ? 'No Orders' : 'Tidak Ada Pesanan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              status == 'All'
                  ? (locale.languageCode == 'en'
                      ? 'You haven\'t placed any orders yet'
                      : 'Anda belum membuat pesanan')
                  : (locale.languageCode == 'en'
                      ? 'No $status orders'
                      : 'Tidak ada pesanan $status'),
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order, locale);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order, Locale locale) {
    final needsPaymentProof = order.rawStatus == 'pending' || 
        order.rawStatus == 'on-hold';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).cardColor, // ✅ TAMBAHKAN
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[200]!, // ✅ UBAH
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToOrderDetail(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      order.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('dd MMM yyyy, HH:mm').format(order.date),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              
              if (needsPaymentProof) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locale.languageCode == 'en'
                              ? 'Tap to upload payment proof'
                              : 'Ketuk untuk upload bukti pembayaran',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, 
                        size: 14, 
                        color: Colors.orange[700]
                      ),
                    ],
                  ),
                ),
              ],
              
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${order.items.length} ${locale.languageCode == 'en' ? (order.items.length > 1 ? 'items' : 'item') : 'item'}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(order.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToOrderDetail(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(
          orderId: order.orderId,
        ),
      ),
    ).then((_) {
      _loadOrders();
    });
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    // English status names
    final statusLower = status.toLowerCase();
    if (statusLower.contains('waiting') || statusLower.contains('menunggu')) {
      backgroundColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
    } else if (statusLower.contains('hold') || statusLower.contains('ditahan')) {
      backgroundColor = Colors.yellow[50]!;
      textColor = Colors.yellow[700]!;
    } else if (statusLower.contains('processing') || statusLower.contains('diproses')) {
      backgroundColor = Colors.blue[50]!;
      textColor = Colors.blue[700]!;
    } else if (statusLower.contains('delivered') || statusLower.contains('terkirim')) {
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
    } else if (statusLower.contains('cancelled') || statusLower.contains('dibatalkan')) {
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
    } else if (statusLower.contains('refunded') || statusLower.contains('dikembalikan')) {
      backgroundColor = Colors.purple[50]!;
      textColor = Colors.purple[700]!;
    } else if (statusLower.contains('failed') || statusLower.contains('gagal')) {
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
    } else {
      backgroundColor = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}