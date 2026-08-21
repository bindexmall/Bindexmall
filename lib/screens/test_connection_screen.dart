// ============================================================================
// SCREEN: TestConnectionScreen (DEV/DEBUG TOOL)
// ============================================================================
// Halaman utilitas untuk cek koneksi ke API (WooCommerce/RajaOngkir/dll) saat development.
//
// Catatan:
//  - Kemungkinan TIDAK dimaksudkan untuk end-user produksi — cek apakah screen ini
//  -   masih di-route/diakses dari UI publik atau cuma dipanggil manual saat debugging.
//  -   Kalau tidak dipakai lagi, aman untuk dihapus dari routing (tapi simpan filenya
//  -   dulu sampai yakin).
// ============================================================================

import 'package:flutter/material.dart';
import '../services/woocommerce_service.dart';
import '../models/product.dart';
import '../models/category.dart';

class TestConnectionScreen extends StatefulWidget {
  const TestConnectionScreen({super.key});

  @override
  State<TestConnectionScreen> createState() => _TestConnectionScreenState();
}

class _TestConnectionScreenState extends State<TestConnectionScreen> {
  bool _isLoading = false;
  String _status = 'Ready to test';
  List<Product> _products = [];
  List<Category> _categories = [];
  String? _error;

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing connection...';
      _error = null;
      _products = [];
      _categories = [];
    });

    try {
      // Test products
      setState(() => _status = 'Fetching products...');
      final productsResponse = await wooCommerceService.getProducts(perPage: 5);

      _products = productsResponse
          .map(
              (json) => Product.fromWooCommerce(json as Map<String, dynamic>))
          .toList();
    
      // Test categories
      setState(() => _status = 'Fetching categories...');
      final categoriesResponse =
          await wooCommerceService.getCategories(perPage: 5);

      _categories = categoriesResponse
          .map((json) =>
              Category.fromWooCommerce(json as Map<String, dynamic>))
          .toList();
    
      setState(() {
        _isLoading = false;
        _status = 'Connection successful!';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Connection failed';
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test WooCommerce Connection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (!_isLoading &&
                            _error == null &&
                            _products.isNotEmpty)
                          const Icon(Icons.check_circle, color: Colors.green),
                        if (_error != null)
                          const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: _error != null ? Colors.red : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testConnection,
              icon: const Icon(Icons.refresh),
              label: const Text('Test Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            if (_products.isNotEmpty || _categories.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Products
                      if (_products.isNotEmpty) ...[
                        Text(
                          'Products (${_products.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...List<Widget>.from(_products.map((product) => Card(
                              child: ListTile(
                                leading: product.imageUrl.isNotEmpty
                                    ? Image.network(
                                        product.imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                Icons.image_not_supported),
                                      )
                                    : const Icon(Icons.image_not_supported),
                                title: Text(product.name),
                                subtitle: Text(product.displayPrice),
                                trailing: product.inStock
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green)
                                    : const Icon(Icons.cancel,
                                        color: Colors.red),
                              ),
                            ))),
                        const SizedBox(height: 16),
                      ],

                      // Categories
                      if (_categories.isNotEmpty) ...[
                        Text(
                          'Categories (${_categories.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...List<Widget>.from(_categories.map((category) => Card(
                              child: ListTile(
                                leading: category.imageUrl.isNotEmpty
                                    ? Image.network(
                                        category.imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.category),
                                      )
                                    : const Icon(Icons.category),
                                title: Text(category.name),
                                subtitle: Text('${category.count} products'),
                              ),
                            ))),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
