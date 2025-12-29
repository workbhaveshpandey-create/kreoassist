import 'package:flutter/material.dart';
import '../../main.dart'; // To access navigatorKey/scaffoldMessengerKey

class ToastService {
  static OverlayEntry? _overlayEntry;

  /// Show a success toast (Green)
  static void showSuccess(String message) {
    _showToast(message, const Color(0xFF00C853), Icons.check_circle);
  }

  /// Show an error toast (Red)
  static void showError(String message) {
    _showToast(message, const Color(0xFFFF5252), Icons.error);
  }

  /// Show an info toast (Blue)
  static void showInfo(String message) {
    _showToast(message, const Color(0xFF2196F3), Icons.info);
  }

  /// Show a warning toast (Orange)
  static void showWarning(String message) {
    _showToast(message, const Color(0xFFFF9800), Icons.warning);
  }

  static void _showToast(String message, Color color, IconData icon) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      // Use maybeOf to avoid throwing when overlay not available
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) return; // App is in background, skip toast

      // Remove existing if any
      _overlayEntry?.remove();
      _overlayEntry = null;

      final entry = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _ToastWidget(
              message: message,
              color: color,
              icon: icon,
              onDismiss: () {
                _overlayEntry?.remove();
                _overlayEntry = null;
              },
            ),
          ),
        ),
      );

      overlay.insert(entry);
      _overlayEntry = entry;

      // Auto dismiss
      Future.delayed(const Duration(seconds: 4), () {
        if (_overlayEntry == entry) {
          _overlayEntry?.remove();
          _overlayEntry = null;
        }
      });
    } catch (e) {
      // Silently fail - toast is non-critical
      print('Toast error (non-critical): $e');
    }
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slide =
        Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: GestureDetector(
          onTap: widget.onDismiss, // Dismiss on tap
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.color.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: widget.color.withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
