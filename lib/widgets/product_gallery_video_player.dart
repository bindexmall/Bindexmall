// ============================================================================
// WIDGET: ProductGalleryVideoPlayer
// ============================================================================
// Video player untuk galeri produk, support 3 sumber: video upload sendiri (self-hosted),
// YouTube, dan Vimeo.
//
// Catatan:
//  - RIWAYAT BUG (sudah diperbaiki): video self-hosted sempat tidak jalan di app Android
//  -   native (padahal jalan di web) karena (1) exception di _start() ke-swallow diam-diam,
//  -   dan (2) request video tidak menyertakan header User-Agent/Referer yang mirip browser
//  -   sehingga diblok proteksi hotlink di sisi hosting. Fix: log + tampilkan state retry,
//  -   dan tambahkan header yang sama seperti dipakai di jalur YouTube/Vimeo.
//  -   Kalau video self-hosted bermasalah lagi di kemudian hari, mulai investigasi dari sini.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product_video.dart';

/// Renders one WoodMart "gallery video" item inside the product image
/// gallery: a tap-to-play thumbnail that swaps into either a native
/// [VideoPlayer] (self-hosted MP4) or an embedded [WebViewWidget]
/// (YouTube / Vimeo), matching WoodMart's own autoplay/mute/size settings.
class ProductGalleryVideoPlayer extends StatefulWidget {
  final ProductVideo video;

  /// Fallback preview image used when the provider has no free static
  /// thumbnail endpoint (Vimeo, self-hosted MP4) — pass the product's
  /// main image here.
  final String? fallbackThumbnailUrl;
  final bool isDarkMode;

  const ProductGalleryVideoPlayer({
    super.key,
    required this.video,
    this.fallbackThumbnailUrl,
    this.isDarkMode = false,
  });

  @override
  State<ProductGalleryVideoPlayer> createState() =>
      _ProductGalleryVideoPlayerState();
}

class _ProductGalleryVideoPlayerState extends State<ProductGalleryVideoPlayer> {
  VideoPlayerController? _videoController;
  WebViewController? _webViewController;
  bool _started = false;
  bool _loading = false;
  bool _failed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ✅ UBAH - selalu langsung play pas produk dibuka (samain kayak di web),
    // gak nunggu di-tap dan gak tergantung flag autoplay WoodMart doang.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (_started || _loading || !widget.video.isValid) return;
    setState(() {
      _loading = true;
      _failed = false;
      _errorMessage = null;
    });

    try {
      if (widget.video.isSelfHosted) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.video.uploadVideoUrl!),
          // ✅ ADDED - skip format-sniffing round-trip yang bikin delay awal
          formatHint: VideoFormat.other,
          // ✅ UBAH - WAF/plugin security WordPress sering nge-block default
          // User-Agent ExoPlayer ("ExoPlayerLib/...") karena gak keliatan
          // kayak browser asli. Samain kayak cabang YouTube/Vimeo di bawah
          // biar gak ke-block/hotlink-protected di device native.
          httpHeaders: const {
            'Connection': 'keep-alive',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Referer': 'https://bindexmall.com',
          },
        );
        await controller.initialize();
        controller
          ..setLooping(false)
          ..setVolume(widget.video.muted ? 0 : 1)
          ..addListener(_onVideoTick)
          ..play();
        _videoController = controller;
      } else {
        final embedUrl =
            widget.video.isYoutube ? _youtubeEmbedUrl() : _vimeoEmbedUrl();
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          // ✅ ADDED - samain kayak live_stream_screen.dart biar autoplay reliable
          ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          )
          ..loadRequest(
            Uri.parse(embedUrl),
            headers: const {'Referer': 'https://bindexmall.com'},
          );
      }
    } catch (e, st) {
      // ✅ UBAH - jangan gagal diam. Log biar kelihatan di `flutter logs`/adb,
      // dan tandai gagal biar UI kasih tombol retry, bukan macet di thumbnail.
      debugPrint('[ProductGalleryVideoPlayer] failed to start '
          '(id=${widget.video.id}, url=${widget.video.sourceUrl}): $e');
      debugPrintStack(stackTrace: st);
      _videoController?.dispose();
      _videoController = null;
      _webViewController = null;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
        _errorMessage = e.toString();
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _started = true;
      _loading = false;
    });
  }

  String _youtubeEmbedUrl() {
    final id = widget.video.youtubeId ?? '';
    return 'https://www.youtube.com/embed/$id'
        '?autoplay=1&playsinline=1&rel=0&modestbranding=1'
        '${widget.video.muted ? '&mute=1' : ''}';
  }

  String _vimeoEmbedUrl() {
    final id = widget.video.vimeoId ?? '';
    return 'https://player.vimeo.com/video/$id'
        '?autoplay=1${widget.video.muted ? '&muted=1' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.video.isValid) {
      return Center(
        child: Icon(
          Icons.videocam_off,
          size: 60,
          color: widget.isDarkMode ? Colors.grey[700] : Colors.grey,
        ),
      );
    }

    if (_failed) {
      return _buildThumbnail(showSpinner: false, failed: true);
    }

    if (!_started || _loading) {
      return _buildThumbnail(showSpinner: _loading);
    }

    if (widget.video.isSelfHosted && _videoController != null) {
      return _buildSelfHostedPlayer(_videoController!);
    }

    if (_webViewController != null) {
      return WebViewWidget(controller: _webViewController!);
    }

    return _buildThumbnail(showSpinner: false);
  }

  Widget _buildSelfHostedPlayer(VideoPlayerController controller) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.isInitialized
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white70,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.play_arrow, color: Colors.black, size: 32),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail({required bool showSpinner, bool failed = false}) {
    final thumb = widget.video.thumbnailUrl ?? widget.fallbackThumbnailUrl;
    return GestureDetector(
      // ✅ ADDED - `_start()` sendiri sudah nge-guard `_started`, jadi reset
      // dulu biar tap retry beneran jalan lagi setelah gagal.
      onTap: () {
        if (failed) {
          setState(() => _started = false);
        }
        _start();
      },
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (thumb != null)
            CachedNetworkImage(
              imageUrl: thumb,
              fit: widget.video.boxFit,
              errorWidget: (context, url, error) => Container(
                color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[200],
              ),
            )
          else
            Container(
              color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[200],
            ),
          Container(color: Colors.black26),
          if (showSpinner)
            const CircularProgressIndicator(color: Colors.white)
          else if (failed)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 40),
                const SizedBox(height: 6),
                const Text(
                  'Video gagal dimuat — tap untuk coba lagi',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.play_arrow, color: Colors.black, size: 34),
            ),
        ],
      ),
    );
  }
}
