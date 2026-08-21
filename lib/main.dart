// ============================================================================
// ENTRY POINT: main.dart
// ============================================================================
// Titik masuk aplikasi. Urutan inisialisasi PENTING — jangan diubah urutannya
//
// Isi/tanggung jawab utama:
//  - 1. WidgetsFlutterBinding.ensureInitialized()
//  - 2. NotificationService.initialize() + requestPermissions()
//  - 3. DeepLinkService().initialize() — supaya deep link dari cold-start tertangkap
//  - 4. SentryFlutter.init() — crash/error reporting, membungkus runApp()
//  - 5. runApp(SentryWidget(MyApp())) di dalam appRunner Sentry
//  - MyApp (StatefulWidget) membungkus seluruh app dengan MultiProvider (semua Provider
//  -   didaftarkan di sini — lihat build() method) lalu MaterialApp dengan routing named routes.
//  - Beberapa provider pakai ChangeNotifierProxyProvider (Cart, Product, Address) supaya
//  -   otomatis reset/reload saat AuthProvider (login state) berubah.
//
// ‼️ TODO SEBELUM RILIS BERIKUTNYA: ada baris
//   `await Sentry.captureException(StateError('This is a sample exception.'));`
//   di dalam main() — ini kode contoh/testing Sentry yang KETINGGALAN. Efeknya:
//   app selalu mengirim 1 error palsu ke Sentry setiap kali dibuka. Sebaiknya
//   dihapus supaya dashboard Sentry tidak penuh noise.
// ============================================================================

import 'package:bindexmall/providers/address_provider.dart';
import 'package:bindexmall/providers/language_provider.dart';
import 'package:bindexmall/providers/live_settings_provider.dart';
import 'package:bindexmall/providers/notification_provider.dart';
import 'package:bindexmall/providers/coupon_provider.dart';
import 'package:bindexmall/providers/shipping_provider.dart';
import 'package:bindexmall/providers/promo_banner_provider.dart';
import 'package:bindexmall/providers/theme_provider.dart';
import 'package:bindexmall/screens/about_screen.dart';
import 'package:bindexmall/screens/address_screen.dart';
import 'package:bindexmall/screens/deals_screen.dart';
import 'package:bindexmall/screens/edit_profile_screen.dart';
import 'package:bindexmall/screens/auth/forgot_password_screen.dart';
import 'package:bindexmall/screens/help_support_screen.dart';
import 'package:bindexmall/screens/live_chat_screen.dart';
import 'package:bindexmall/screens/orders_screen.dart';
import 'package:bindexmall/screens/shop_screen.dart';
import 'package:bindexmall/screens/track_order_screen.dart';
import 'package:bindexmall/services/live_settings_service.dart';
import 'package:bindexmall/services/notification_service.dart';
import 'package:bindexmall/services/order_tracking_service.dart';
import 'package:bindexmall/services/deep_link_service.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart'; // ✅ ADDED
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'providers/cart_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/locale_provider.dart';
import 'repositories/cart_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/wishlist_repository.dart';
import 'screens/auth/intro_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/main_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/wishlist_screen.dart';
import 'theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Initializing NotificationService...');
  await notificationService.initialize();

  final permissionGranted = await notificationService.requestPermissions();
  debugPrint(
      '📱 Notification permission: ${permissionGranted ? "GRANTED" : "DENIED"}');

  debugPrint('🔗 Initializing Deep Link Service...');
  await DeepLinkService().initialize();

  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://30f6545e9ba52f1387d316ac791db470@o4510338365456384.ingest.us.sentry.io/4510338366963712';
      options.sendDefaultPii = true;
      options.enableLogs = true;
      options.tracesSampleRate = 1.0;
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(SentryWidget(child: const MyApp())),
  );
  await Sentry.captureException(StateError('This is a sample exception.'));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _deepLinkService.linkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) async {
    debugPrint('📲 Deep Link received in MyApp: $uri');

    final productSlug = DeepLinkService.parseProductSlug(uri);

    if (productSlug != null) {
      debugPrint('🔍 Fetching product by slug: $productSlug');

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _navigatorKey.currentContext == null) {
        debugPrint('⚠️ Navigator not ready, deferring deep link...');
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted || _navigatorKey.currentContext == null) {
          debugPrint('❌ Navigator still not ready, deep link failed');
          return;
        }
      }

      try {
        if (_navigatorKey.currentContext != null) {
          showDialog(
            context: _navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final product = await productRepository.fetchProductBySlug(productSlug);
        debugPrint('✅ Product fetched: ${product.name}');

        if (_navigatorKey.currentContext != null) {
          Navigator.of(_navigatorKey.currentContext!).pop();
        }

        if (_navigatorKey.currentState != null) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Failed to open product: $e');

        if (_navigatorKey.currentContext != null) {
          Navigator.of(_navigatorKey.currentContext!).pop();
        }

        if (_navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text('Produk tidak ditemukan: $productSlug'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Tutup',
                textColor: Colors.white,
                onPressed: () {},
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      debugPrint('⚠️ No product slug found in deep link');

      if (_navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text('Link tidak valid'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => LiveSettingsProvider(
            LiveSettingsService(baseUrl: 'https://bindexmall.com'),
          )..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => ShippingProvider()),
        ChangeNotifierProvider(create: (_) => PromoBannerProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(cartRepository),
          update: (context, auth, previous) {
            final cartProvider = previous ?? CartProvider(cartRepository);
            cartProvider.syncWithUser(auth.userId);
            return cartProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => CouponProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
          create: (_) => ProductProvider(productRepository, wishlistRepository),
          update: (context, auth, previous) {
            final productProvider = previous ??
                ProductProvider(productRepository, wishlistRepository);
            productProvider.syncWithUser(auth.userId);
            return productProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AddressProvider>(
          create: (_) => AddressProvider(),
          update: (context, auth, previous) {
            final addressProvider = previous ?? AddressProvider();
            addressProvider.initialize(auth.userId);
            return addressProvider;
          },
        ),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, localeProvider, themeProvider, child) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Bindexmall',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('id')],
            home: const InitializationScreen(),
            routes: {
              '/intro': (context) => const IntroScreen(),
              '/signin': (context) => const SignInScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/main': (context) => const MainScreen(),
              '/cart': (context) => const CartScreen(),
              '/checkout': (context) => const CheckoutScreen(),
              '/wishlist': (context) => const WishlistScreen(),
              '/deals': (context) => const DealsScreen(),
              '/orders': (context) => const OrdersScreen(),
              '/addresses': (context) => const AddressesScreen(),
              '/edit-profile': (context) => const EditProfileScreen(),
              '/track-order': (context) => const TrackOrderScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/help-support': (context) => const HelpSupportScreen(),
              '/about': (context) => const AboutScreen(),
              '/live-chat': (context) => const LiveChatScreen(),
              '/shop': (context) => const ShopScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/catalog') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => CatalogScreen(
                    category: args['category'] as String? ?? '',
                    categoryId: args['categoryId'] as String? ?? '',
                    tag: args['tag'] as String?,
                    initialSort: args['initialSort'] as String?,
                  ),
                );
              }
              if (settings.name == '/product-detail') {
                return MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    product: settings.arguments as dynamic,
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ✅ ADDED — cek update dari Play Store, paksa update jika ada
  Future<void> _checkForUpdate() async {
    try {
      debugPrint('🔄 Checking for app update...');
      final updateInfo = await InAppUpdate.checkForUpdate();
      debugPrint('📦 Update availability: ${updateInfo.updateAvailability}');

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('⬆️ Update available, launching immediate update...');
        await InAppUpdate.performImmediateUpdate();
        // Setelah update selesai, app akan di-restart otomatis oleh Play Store
      } else {
        debugPrint('✅ App is up to date');
      }
    } catch (e) {
      // Jangan crash app jika update check gagal
      // (misal: tidak ada koneksi, bukan dari Play Store, emulator, dll)
      debugPrint('⚠️ In-app update check failed (non-fatal): $e');
    }
  }

  Future<void> _initialize() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // ✅ ADDED — cek update sebelum lanjut, jika ada update wajib
      // app akan freeze di layar ini sampai user selesai update
      await _checkForUpdate();

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();

      if (authProvider.isLoading) {
        debugPrint('⏳ Auth still loading, waiting...');
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;

      final notificationProvider = context.read<NotificationProvider>();
      final permissionGranted = await notificationProvider.requestPermissions();

      if (!permissionGranted) {
        debugPrint('⚠️ Notification permission not granted by user');
      }

      if (authProvider.isAuthenticated && authProvider.userId != null) {
        debugPrint('✅ User authenticated: ${authProvider.userEmail}');
        debugPrint('📋 User ID: ${authProvider.userId}');

        orderTrackingService.startTracking(authProvider.userId);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        debugPrint('ℹ️ User not authenticated, showing intro...');

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/intro');
      }
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/intro');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/ic_launcher.png',
              height: 100,
              width: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.shopping_bag,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Bindexmall',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Shopping Companion',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
