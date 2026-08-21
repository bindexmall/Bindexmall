// ============================================================================
// SCREEN: HomeScreen
// ============================================================================
// Halaman beranda — merangkai widgets/Home/* (featured_products_section,
// flash_sale_section, new_arrivals_section) + promo_banner_carousel + kategori.
//
// Catatan:
//  - Ini 'halaman kaca depan' toko — kalau ada request ubah tampilan awal app, mulai dari sini
//  -   lalu telusuri ke masing-masing section widget di widgets/Home/.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../providers/cart_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/live_settings_provider.dart';
import '../providers/promo_banner_provider.dart';
import '../providers/language_provider.dart';
import '../repositories/category_repository.dart';
import '../widgets/draggable_floating_chat_button.dart';
import '../widgets/draggable_floating_live_button.dart';
import '../widgets/promo_banner_carousel.dart';
import '../widgets/home/flash_sale_section.dart';
import '../widgets/home/featured_products_section.dart';
import '../widgets/home/new_arrivals_section.dart';
import '../screens/live_stream_screen.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Category> _parentCategories = [];
  bool _isLoading = true;
  String? _error;
  final bool _showChatButton = true;
  late AnimationController _animationController;
  Timer? _liveSettingsTimer;
  Timer? _bannerRefreshTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _loadCategories();
    _loadLiveSettings();
    _loadPromoBanners();

    _liveSettingsTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _loadLiveSettings(),
    );

    _bannerRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshPromoBanners(),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _liveSettingsTimer?.cancel();
    _bannerRefreshTimer?.cancel();
    super.dispose();
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await categoryRepository.fetchTopLevelCategories();

      setState(() {
        _parentCategories = categories;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLiveSettings() async {
    final liveProvider = Provider.of<LiveSettingsProvider>(
      context,
      listen: false,
    );
    await liveProvider.loadSettings();
  }

  Future<void> _loadPromoBanners() async {
    final bannerProvider = Provider.of<PromoBannerProvider>(
      context,
      listen: false,
    );
    await bannerProvider.loadBanners();
  }

  Future<void> _refreshPromoBanners() async {
    final bannerProvider = Provider.of<PromoBannerProvider>(
      context,
      listen: false,
    );
    await bannerProvider.refresh();
  }

  void _openLiveChat() {
    Navigator.pushNamed(context, '/live-chat');
  }

  void _openLiveStream() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final locale = languageProvider.currentLocale;

    final liveSettings =
        Provider.of<LiveSettingsProvider>(context, listen: false).settings;

    if (liveSettings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('unableToLoadLiveStream', locale)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String embedUrl = liveSettings.liveType == 'tiktok'
        ? liveSettings.tiktokUrl
        : liveSettings.youtubeUrl;

    if (embedUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('liveStreamNotAvailable', locale)),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: _t('refresh', locale),
            textColor: Colors.white,
            onPressed: _loadLiveSettings,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          liveType: liveSettings.liveType,
          embedUrl: embedUrl,
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              _buildBody(locale),

              if (_showChatButton)
                DraggableFloatingChatButton(
                  onPressed: _openLiveChat,
                  showUnreadBadge: false,
                  unreadCount: 0,
                ),

              Consumer<LiveSettingsProvider>(
                builder: (context, liveProvider, child) {
                  final settings = liveProvider.settings;

                  if (liveProvider.isLoading || settings == null) {
                    return const SizedBox.shrink();
                  }

                  if (!settings.showButton) {
                    return const SizedBox.shrink();
                  }

                  return DraggableFloatingLiveButton(
                    onPressed: _openLiveStream,
                    isLive: settings.isLive,
                    liveType: settings.liveType,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(Locale locale) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _t('errorLoadingCategories', locale),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCategories,
              icon: const Icon(Icons.refresh),
              label: Text(_t('retry', locale)),
            ),
          ],
        ),
      );
    }

    if (_parentCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _t('noCategoriesAvailable', locale),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadCategories(),
          _loadLiveSettings(),
          _loadPromoBanners(),
        ]);
      },
      child: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────
          _buildSliverAppBar(locale),

          // ── Promo Banner Carousel ────────────────────────────────
          const SliverToBoxAdapter(
            child: PromoBannerCarousel(),
          ),

          // ── Quick Actions ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildQuickActions(locale),
            ),
          ),

          // ── Flash Sale Section ───────────────────────────────────
          const SliverToBoxAdapter(
            child: FlashSaleSection(),
          ),

          // ── Featured Products (Best Sellers) ─────────────────────
          const SliverToBoxAdapter(
            child: FeaturedProductsSection(),
          ),

          // ── New Arrivals ─────────────────────────────────────────
          const SliverToBoxAdapter(
            child: NewArrivalsSection(),
          ),

          // ── Shop by Category header ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('shopByCategory', locale),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('findWhatYouNeed', locale),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // ── Categories Grid ──────────────────────────────────────
          _buildCategoriesGrid(),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(Locale locale) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Theme.of(context).cardColor,
      toolbarHeight: 70,
      title: Row(
        children: [
          Image.asset(
            'assets/images/ic_launcher.png',
            height: 50,
            width: 50,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.shopping_bag,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              );
            },
          ),
        ],
      ),
      actions: [
        // Search button → ShopScreen (already has search bar)
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/shop'),
          icon: Icon(
            Icons.search,
            color: Theme.of(context).iconTheme.color,
          ),
        ),
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            return IconButton(
              onPressed: () => Navigator.pushNamed(context, '/cart'),
              icon: Badge(
                isLabelVisible: cartProvider.isNotEmpty,
                label: Text('${cartProvider.totalQuantity}'),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
            );
          },
        ),
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            return IconButton(
              icon: Icon(
                notificationProvider.notificationsEnabled
                    ? Icons.notifications_outlined
                    : Icons.notifications_off_outlined,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: () {
                _showNotificationSettings(
                    context, notificationProvider, locale);
              },
            );
          },
        ),
        const SizedBox(width: 5),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Notification bottom sheet (unchanged)
  // ─────────────────────────────────────────────────────────────────────────

  void _showNotificationSettings(
    BuildContext context,
    NotificationProvider notificationProvider,
    Locale locale,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _t('notificationSettings', locale),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: Text(_t('enableNotifications', locale)),
              subtitle: Text(_t('receiveAllNotifications', locale)),
              trailing: Switch(
                value: notificationProvider.notificationsEnabled,
                onChanged: (value) async {
                  await notificationProvider.toggleNotifications(value);
                },
              ),
            ),
            if (notificationProvider.notificationsEnabled) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: Text(_t('orderUpdates', locale)),
                subtitle: Text(_t('statusChangesDelivery', locale)),
                trailing: Switch(
                  value: notificationProvider.orderStatusEnabled,
                  onChanged: (value) async {
                    await notificationProvider.toggleOrderStatus(value);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(_t('newsletterPromos', locale)),
                subtitle: Text(_t('dealsSpecialOffers', locale)),
                trailing: Switch(
                  value: notificationProvider.newsletterEnabled,
                  onChanged: (value) async {
                    await notificationProvider.toggleNewsletter(value);
                  },
                ),
              ),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('done', locale)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Quick Actions
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickActions(Locale locale) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.local_offer,
            title: _t('deals', locale),
            color: Colors.orange,
            onTap: () => Navigator.pushNamed(context, '/deals'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.favorite,
            title: _t('wishlist', locale),
            color: Colors.red,
            onTap: () => Navigator.pushNamed(context, '/wishlist'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.local_shipping,
            title: _t('track', locale),
            color: Colors.blue,
            onTap: () => Navigator.pushNamed(context, '/track-order'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Categories Grid
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCategoriesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = _parentCategories[index];
            return _buildCategoryCard(category);
          },
          childCount: _parentCategories.length,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Hero(
      tag: 'category_${category.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/catalog',
              arguments: {
                'category': category.name,
                'categoryId': category.id,
              },
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: category.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: category.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                // Category name overlay
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[300],
      child: Icon(
        Icons.category,
        size: 40,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[600]
            : Colors.grey,
      ),
    );
  }
}
