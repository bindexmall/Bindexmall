// ============================================================================
// WIDGET: DraggableFloatingLiveButton
// ============================================================================
// Tombol 'sedang live' mengambang yang bisa di-drag, membuka LiveStreamScreen
// saat ditekan — hanya tampil kalau LiveSettingsProvider menandakan live sedang aktif.
// ============================================================================

import 'package:flutter/material.dart';

class DraggableFloatingLiveButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLive;
  final String liveType;

  const DraggableFloatingLiveButton({
    super.key,
    required this.onPressed,
    this.isLive = false,
    this.liveType = 'tiktok',
  });

  @override
  State<DraggableFloatingLiveButton> createState() =>
      _DraggableFloatingLiveButtonState();
}

class _DraggableFloatingLiveButtonState
    extends State<DraggableFloatingLiveButton>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getLiveColor() {
    // TikTok: pink/cyan gradient, YouTube: red
    if (widget.liveType == 'tiktok') {
      return const Color(0xFFFF0050); // TikTok pink
    } else {
      return const Color(0xFFFF0000); // YouTube red
    }
  }

  IconData _getLiveIcon() {
    if (widget.liveType == 'tiktok') {
      return Icons.music_note; // TikTok icon (atau bisa custom)
    } else {
      return Icons.play_arrow; // YouTube icon
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx)
                  .clamp(0.0, screenSize.width - 70),
              (_position.dy + details.delta.dy)
                  .clamp(0.0, screenSize.height - 150),
            );
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        onTap: () {
          if (!_isDragging) {
            widget.onPressed();
          }
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isLive ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.liveType == 'tiktok'
                        ? [
                            const Color.fromARGB(255, 107, 187, 199),
                            const Color.fromARGB(255, 138, 150, 171),
                            const Color.fromARGB(255, 154, 137, 161),
                            const Color.fromARGB(255, 207, 70, 109),
                          ]
                        : [
                            const Color(0xFFFF0000), // YouTube red
                            const Color(0xFFCC0000),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: _getLiveColor().withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Icon utama
                    Center(
                      child: Icon(
                        _getLiveIcon(),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    
                    // Badge LIVE
                    if (widget.isLive)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}