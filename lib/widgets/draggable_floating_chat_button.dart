// ============================================================================
// WIDGET: DraggableFloatingChatButton
// ============================================================================
// Tombol chat mengambang yang bisa di-drag ke posisi mana saja di layar,
// membuka LiveChatScreen/HelpSupportScreen saat ditekan.
// ============================================================================

import 'package:flutter/material.dart';

class DraggableFloatingChatButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool showUnreadBadge;
  final int unreadCount;

  const DraggableFloatingChatButton({
    super.key,
    required this.onPressed,
    this.showUnreadBadge = false,
    this.unreadCount = 0,
  });

  @override
  State<DraggableFloatingChatButton> createState() =>
      _DraggableFloatingChatButtonState();
}

class _DraggableFloatingChatButtonState
    extends State<DraggableFloatingChatButton>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _isVisible = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for unread messages
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    if (widget.showUnreadBadge) {
      _pulseController.repeat(reverse: true);
    }
    
    // Set initial position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setInitialPosition();
    });
  }

  void _setInitialPosition() {
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      // Position di kanan bawah, dengan margin
      _position = Offset(
        screenSize.width - 80,
        screenSize.height - 150,
      );
    });
  }

  @override
  void didUpdateWidget(DraggableFloatingChatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showUnreadBadge && !oldWidget.showUnreadBadge) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.showUnreadBadge && oldWidget.showUnreadBadge) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _position = Offset(
        _position.dx + details.delta.dx,
        _position.dy + details.delta.dy,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    _snapToEdge();
  }

  void _snapToEdge() {
    final screenSize = MediaQuery.of(context).size;
    final buttonSize = 60.0;
    final labelHeight = 20.0; // Tinggi label "Live Chat"
    final totalHeight = buttonSize + labelHeight + 6; // +6 untuk margin
    final margin = 16.0;

    double newX = _position.dx;
    double newY = _position.dy;

    // Snap ke kiri atau kanan (mana yang lebih dekat)
    if (_position.dx < screenSize.width / 2) {
      newX = margin;
    } else {
      newX = screenSize.width - buttonSize - margin;
    }

    // Batasi posisi Y dengan memperhitungkan label
    if (newY < margin) {
      newY = margin;
    } else if (newY > screenSize.height - totalHeight - margin - 80) {
      // 80 adalah tinggi bottom navigation
      newY = screenSize.height - totalHeight - margin - 80;
    }

    setState(() {
      _position = Offset(newX, newY);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: _onDragStart,
        onPanUpdate: _onDragUpdate,
        onPanEnd: _onDragEnd,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isDragging ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.showUnreadBadge ? _pulseAnimation.value : 1.0,
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main button
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.support_agent_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                    // Online indicator
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    if (widget.showUnreadBadge && widget.unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          child: Center(
                            child: Text(
                              widget.unreadCount > 99
                                  ? '99+'
                                  : '${widget.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Close button (muncul saat dragging)
                    if (_isDragging)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isVisible = false;
                            });
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Label "Live Chat"
                if (!_isDragging)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Live Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}