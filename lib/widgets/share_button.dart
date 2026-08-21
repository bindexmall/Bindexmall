// ============================================================================
// WIDGET: ShareButton + ShareOptionsSheet
// ============================================================================
// Tombol share produk + bottom sheet pilihan platform share (WA, dll),
// memakai ShareService untuk generate link produk.
// ============================================================================

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/share_service.dart';

class ShareButton extends StatelessWidget {
  final Product product;
  final bool showLabel;

  const ShareButton({
    super.key,
    required this.product,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // ✅ TAMBAHKAN
    
    return IconButton(
      onPressed: () => _showShareOptions(context),
      icon: Icon(
        Icons.share,
        color: isDarkMode ? Colors.white : Colors.black, // ✅ TAMBAHKAN
      ),
      tooltip: 'Bagikan Produk',
    );
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).cardColor, // ✅ TAMBAHKAN
      builder: (context) => ShareOptionsSheet(product: product),
    );
  }
}

class ShareOptionsSheet extends StatelessWidget {
  final Product product;

  const ShareOptionsSheet({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; // ✅ TAMBAHKAN
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅ TAMBAHKAN
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300], // ✅ UBAH
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bagikan Produk',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShareOption(
                context,
                icon: Icons.call,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _shareToWhatsApp(context),
              ),
              _buildShareOption(
                context,
                icon: Icons.facebook,
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                onTap: () => _shareToFacebook(context),
              ),
              _buildShareOption(
                context,
                icon: Icons.camera_alt,
                label: 'Instagram',
                color: const Color(0xFFE4405F),
                onTap: () => _shareToInstagram(context),
              ),
              _buildShareOption(
                context,
                iconData: Icons.flutter_dash,
                label: 'Twitter',
                color: const Color(0xFF1DA1F2),
                onTap: () => _shareToTwitter(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(
              Icons.link,
              color: Theme.of(context).iconTheme.color, // ✅ TAMBAHKAN
            ),
            title: Text(
              'Salin Link',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color, // ✅ TAMBAHKAN
              ),
            ),
            onTap: () => _copyLink(context),
          ),
          ListTile(
            leading: Icon(
              Icons.more_horiz,
              color: Theme.of(context).iconTheme.color, // ✅ TAMBAHKAN
            ),
            title: Text(
              'Opsi Lainnya',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color, // ✅ TAMBAHKAN
              ),
            ),
            onTap: () => _shareGeneric(context),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    IconData? icon,
    IconData? iconData,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? iconData,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color, // ✅ TAMBAHKAN
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareToWhatsApp(BuildContext context) async {
    try {
      await ShareService.shareToWhatsApp(product);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _shareToFacebook(BuildContext context) async {
    try {
      await ShareService.shareToFacebook(product);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _shareToInstagram(BuildContext context) async {
    try {
      await ShareService.shareToInstagram(product);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _shareToTwitter(BuildContext context) async {
    try {
      await ShareService.shareToTwitter(product);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _copyLink(BuildContext context) async {
    await ShareService.copyProductLink(product);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link berhasil disalin')),
      );
    }
  }

  void _shareGeneric(BuildContext context) async {
    try {
      await ShareService.shareProduct(product);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}