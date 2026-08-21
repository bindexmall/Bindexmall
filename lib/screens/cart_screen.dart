// ============================================================================
// SCREEN: CartScreen
// ============================================================================
// Halaman keranjang belanja: list CartItemCard, ubah quantity, hapus item,
// terapkan kupon (voucher_dialog), lanjut ke checkout_screen.dart.
//
// Catatan:
//  - Terkait riwayat bug PPN ganda — lihat catatan di models/cart.dart & checkout_screen.dart.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/cart_provider.dart';
import '../providers/coupon_provider.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/voucher_dialog.dart';
import '../utils/currency_formatter.dart';
import '../l10n/app_localizations.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    if (mounted) {
      setState(() {
        _currentLocale = Locale(languageCode);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLanguagePreference();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(_currentLocale);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.translate('shoppingCart')),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.isEmpty) return const SizedBox();

              return TextButton(
                onPressed: () {
                  _showClearCartDialog(context, cartProvider);
                },
                child: Text(l10n.translate('removeAll')),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Column(
            children: [
              _buildCartHeader(context, cartProvider),
              Expanded(
                child: _buildCartItems(context, cartProvider),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isEmpty) return const SizedBox.shrink();
          return _buildBottomBar(context, cartProvider);
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    final l10n = AppLocalizations(_currentLocale);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.translate('yourCartIsEmpty'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('addProductsToGetStarted'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/categories');
            },
            icon: const Icon(Icons.shopping_bag),
            label: Text(l10n.translate('startShopping')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartHeader(BuildContext context, CartProvider cartProvider) {
    final l10n = AppLocalizations(_currentLocale);

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            Icons.shopping_cart,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cartProvider.totalQuantity} ${cartProvider.totalQuantity == 1 ? l10n.translate('itemInCart') : l10n.translate('itemsInCart')}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  l10n.translate('readyToCheckout'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(BuildContext context, CartProvider cartProvider) {
    final l10n = AppLocalizations(_currentLocale);

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: cartProvider.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cartItem = cartProvider.items[index];
        return Dismissible(
          key: Key(cartItem.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 32,
            ),
          ),
          confirmDismiss: (direction) async {
            return await _showDeleteConfirmation(
                context, cartItem.product.name);
          },
          onDismissed: (direction) {
            cartProvider.removeProduct(cartItem.product.id);

            _validateAppliedCoupon(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${cartItem.product.name} ${l10n.translate('removedFromCart')}'),
                action: SnackBarAction(
                  label: l10n.translate('cancel'),
                  onPressed: () {
                    cartProvider.addProduct(cartItem.product,
                        quantity: cartItem.quantity);
                  },
                ),
              ),
            );
          },
          child: CartItemCard(
            cartItem: cartItem,
            onRemove: () {
              cartProvider.removeProduct(cartItem.product.id);
              _validateAppliedCoupon(context);
            },
            onQuantityChanged: (newQuantity) {
              cartProvider.updateQuantity(cartItem.product.id, newQuantity);
              _validateAppliedCoupon(context);
            },
          ),
        );
      },
    );
  }

  void _validateAppliedCoupon(BuildContext context) {
    final couponProvider = Provider.of<CouponProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (couponProvider.hasCoupon) {
      final appliedCoupon = couponProvider.appliedCoupon!;
      final subtotal = cartProvider.total;
      final totalQuantity = cartProvider.totalQuantity;
      final productIds = cartProvider.items
          .map((item) => int.tryParse(item.product.id) ?? 0)
          .where((id) => id > 0)
          .toList();
      final categoryIds = cartProvider.items
          .expand((item) => item.product.categoryIds)
          .toSet()
          .toList();
      final hasSaleItems =
          cartProvider.items.any((item) => item.product.onSale);

      final validation = appliedCoupon.validateForCart(
        subtotal: subtotal,
        totalQuantity: totalQuantity,
        productIds: productIds,
        categoryIds: categoryIds,
        hasSaleItems: hasSaleItems,
      );

      if (!validation.isValid) {
        couponProvider.removeCoupon();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Voucher ${appliedCoupon.code} deleted: ${validation.reason}',
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Widget _buildBottomBar(BuildContext context, CartProvider cartProvider) {
    final l10n = AppLocalizations(_currentLocale);

    return Consumer<CouponProvider>(
      builder: (context, couponProvider, child) {
        final subtotal = cartProvider.total;

        if (couponProvider.hasCoupon) {
          final totalQuantity = cartProvider.totalQuantity;
          final productIds = cartProvider.items
              .map((item) => int.tryParse(item.product.id) ?? 0)
              .where((id) => id > 0)
              .toList();
          final categoryIds = cartProvider.items
              .expand((item) => item.product.categoryIds)
              .toSet()
              .toList();
          final hasSaleItems =
              cartProvider.items.any((item) => item.product.onSale);

          final validation = couponProvider.appliedCoupon!.validateForCart(
            subtotal: subtotal,
            totalQuantity: totalQuantity,
            productIds: productIds,
            categoryIds: categoryIds,
            hasSaleItems: hasSaleItems,
          );

          if (!validation.isValid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              couponProvider.removeCoupon();
            });
          }
        }

        final discount = couponProvider.calculateDiscount(subtotal);
        final subtotalAfterDiscount = subtotal - discount;
        final total = subtotalAfterDiscount;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVoucherSection(context, couponProvider, cartProvider),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _buildPriceRow(
                  context,
                  l10n.translate('subtotal'),
                  CurrencyFormatter.format(subtotal),
                ),
                if (discount > 0) ...[
                  const SizedBox(height: 8),
                  _buildPriceRow(
                    context,
                    '${l10n.translate('discount')} (${couponProvider.appliedCoupon?.code ?? ''})',
                    '-${CurrencyFormatter.format(discount)}',
                    isDiscount: true,
                  ),
                ],
                const Divider(height: 24),
                _buildPriceRow(
                  context,
                  l10n.translate('total'),
                  CurrencyFormatter.format(total),
                  isTotal: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/checkout');
                    },
                    icon: const Icon(Icons.payment),
                    label: Text(l10n.translate('continueToPayment')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildVoucherSection(
    BuildContext context,
    CouponProvider couponProvider,
    CartProvider cartProvider,
  ) {
    final l10n = AppLocalizations(_currentLocale);
    final hasCoupon = couponProvider.hasCoupon;
    final appliedCoupon = couponProvider.appliedCoupon;

    String? validationWarning;
    if (hasCoupon && appliedCoupon != null) {
      final subtotal = cartProvider.total;
      final totalQuantity = cartProvider.totalQuantity;
      final productIds = cartProvider.items
          .map((item) => int.tryParse(item.product.id) ?? 0)
          .where((id) => id > 0)
          .toList();
      final categoryIds = cartProvider.items
          .expand((item) => item.product.categoryIds)
          .toSet()
          .toList();
      final hasSaleItems =
          cartProvider.items.any((item) => item.product.onSale);

      final validation = appliedCoupon.validateForCart(
        subtotal: subtotal,
        totalQuantity: totalQuantity,
        productIds: productIds,
        categoryIds: categoryIds,
        hasSaleItems: hasSaleItems,
      );

      if (!validation.isValid) {
        validationWarning = validation.reason;
      }
    }

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => const VoucherDialog(),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: validationWarning != null
                ? Colors.red
                : hasCoupon
                    ? Colors.orange
                    : Colors.grey[300]!,
            width: hasCoupon ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: validationWarning != null
              ? Colors.red[50]
              : hasCoupon
                  ? Colors.orange[50]
                  : Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(
              validationWarning != null ? Icons.warning : Icons.local_offer,
              color: validationWarning != null
                  ? Colors.red
                  : hasCoupon
                      ? Colors.orange
                      : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCoupon
                        ? appliedCoupon!.code
                        : l10n.translate('useVouchers'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: validationWarning != null
                          ? Colors.red[900]
                          : hasCoupon
                              ? Colors.orange[900]
                              : Colors.grey[800],
                    ),
                  ),
                  if (validationWarning != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      validationWarning,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (hasCoupon && appliedCoupon != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      appliedCoupon.description.isNotEmpty
                          ? appliedCoupon.description
                          : l10n.translate('voucherApplied'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (!hasCoupon) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.translate('getDiscountsWithVouchers'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasCoupon)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  couponProvider.removeCoupon();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.translate('voucherDeleted')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: l10n.translate('deleteVoucher'),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    String value, {
    bool isTotal = false,
    bool isShipping = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal
                ? Theme.of(context).colorScheme.primary
                : isShipping
                    ? Colors.green
                    : isDiscount
                        ? Colors.orange
                        : Colors.black,
          ),
        ),
      ],
    );
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    String productName,
  ) {
    final l10n = AppLocalizations(_currentLocale);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('deleteItems')),
        content: Text(
            '${l10n.translate('delete')} "$productName" ${l10n.translate('deleteFromCart')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cartProvider) {
    final l10n = AppLocalizations(_currentLocale);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('emptyCart')),
        content: Text(l10n.translate('emptyCartConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () {
              cartProvider.clearCart();
              final couponProvider =
                  Provider.of<CouponProvider>(context, listen: false);
              couponProvider.removeCoupon();

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.translate('cartIsEmptied')),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.translate('clearIt')),
          ),
        ],
      ),
    );
  }
}
