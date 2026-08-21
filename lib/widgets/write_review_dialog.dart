// ============================================================================
// WIDGET: WriteReviewDialog
// ============================================================================
// Dialog form untuk menulis/mengedit review produk (rating bintang + komentar + foto),
// memanggil ReviewProvider.createReview/updateReview.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/review_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class WriteReviewDialog extends StatefulWidget {
  final int productId;
  final String productName;
  final String? productImageUrl;
  final int orderId;

  const WriteReviewDialog({
    super.key,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.orderId,
  });

  @override
  State<WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<WriteReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final reviewProvider = context.read<ReviewProvider>();
    final languageProvider = context.read<LanguageProvider>();
    final locale = languageProvider.currentLocale;

    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.languageCode == 'en'
                ? 'Please login to write a review'
                : 'Silakan login untuk menulis ulasan',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await reviewProvider.createReview(
        productId: widget.productId,
        review: _reviewController.text.trim(),
        reviewerName: authProvider.userName ?? 'Customer',
        reviewerEmail: authProvider.userEmail ?? '',
        rating: _rating,
      );

      if (!mounted) return;

      Navigator.pop(context, true); // Return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  locale.languageCode == 'en'
                      ? 'Thank you for your review!'
                      : 'Terima kasih atas ulasan Anda!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${locale.languageCode == 'en' ? 'Error' : 'Kesalahan'}: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            locale.languageCode == 'en'
                                ? 'Write a Review'
                                : 'Tulis Ulasan',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Product Info
                    Row(
                      children: [
                        if (widget.productImageUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.productImageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            widget.productName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Rating Section
                    Text(
                      locale.languageCode == 'en'
                          ? 'Your Rating'
                          : 'Penilaian Anda',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final rating = index + 1;
                        return IconButton(
                          onPressed: () {
                            setState(() {
                              _rating = rating;
                            });
                          },
                          icon: Icon(
                            rating <= _rating ? Icons.star : Icons.star_border,
                            size: 40,
                            color: Colors.amber,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Review Text
                    Text(
                      locale.languageCode == 'en'
                          ? 'Your Review'
                          : 'Ulasan Anda',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _reviewController,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: locale.languageCode == 'en'
                            ? 'Share your experience with this product...'
                            : 'Bagikan pengalaman Anda dengan produk ini...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return locale.languageCode == 'en'
                              ? 'Please write your review'
                              : 'Silakan tulis ulasan Anda';
                        }
                        if (value.trim().length < 10) {
                          return locale.languageCode == 'en'
                              ? 'Review must be at least 10 characters'
                              : 'Ulasan minimal 10 karakter';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                locale.languageCode == 'en'
                                    ? 'Submit Review'
                                    : 'Kirim Ulasan',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Info Text
                    Text(
                      locale.languageCode == 'en'
                          ? 'Your review will be visible to other customers after approval.'
                          : 'Ulasan Anda akan terlihat setelah disetujui.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper function to show write review dialog
Future<bool?> showWriteReviewDialog({
  required BuildContext context,
  required int productId,
  required String productName,
  String? productImageUrl,
  required int orderId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => WriteReviewDialog(
      productId: productId,
      productName: productName,
      productImageUrl: productImageUrl,
      orderId: orderId,
    ),
  );
}