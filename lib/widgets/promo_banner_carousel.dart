// ============================================================================
// WIDGET: PromoBannerCarousel
// ============================================================================
// Carousel banner promo di HomeScreen, data dari PromoBannerProvider.
// ============================================================================

// lib/widgets/promo_banner_carousel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/promo_banner.dart';
import '../providers/promo_banner_provider.dart';

class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final bannerProvider = Provider.of<PromoBannerProvider>(
        context,
        listen: false,
      );

      if (bannerProvider.banners.isEmpty) return;

      final nextPage = (_currentPage + 1) % bannerProvider.banners.length;

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handleBannerTap(PromoBanner banner) {
    if (banner.linkType == 'none' || banner.linkValue == null) {
      return;
    }

    switch (banner.linkType) {
      case 'product':
        // Navigate to product detail
        Navigator.pushNamed(
          context,
          '/product-detail',
          arguments: {'productId': int.parse(banner.linkValue!)},
        );
        break;

      case 'category':
        // Navigate to catalog with category
        Navigator.pushNamed(
          context,
          '/catalog',
          arguments: {'categoryId': int.parse(banner.linkValue!)},
        );
        break;

      case 'url':
      case 'webview':
        // Open in webview
        Navigator.pushNamed(
          context,
          '/webview',
          arguments: {
            'url': banner.linkValue!,
            'title': banner.title,
          },
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PromoBannerProvider>(
      builder: (context, bannerProvider, child) {
        // If loading on first load
        if (bannerProvider.isLoading && !bannerProvider.hasBanners) {
          return _buildLoadingShimmer();
        }

        // If no banners, don't show anything
        if (!bannerProvider.hasBanners) {
          return const SizedBox.shrink();
        }

        final banners = bannerProvider.banners;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Banner Carousel
              SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: banners.length,
                  itemBuilder: (context, index) {
                    return _buildBannerItem(banners[index]);
                  },
                ),
              ),

              // Indicators
              if (banners.length > 1) ...[
                const SizedBox(height: 12),
                _buildIndicators(banners.length),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBannerItem(PromoBanner banner) {
    return GestureDetector(
      onTap: () => _handleBannerTap(banner),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Banner Image
              Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image not available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),

              if (banner.linkType != 'none' && banner.linkValue != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.touch_app,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}