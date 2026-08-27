import 'package:flutter/material.dart';

/// Wraps [child] with a full-screen, semi-transparent overlay and centered
/// spinner while [isLoading] is true. Used to block interaction during a
/// blocking async operation without navigating away from the screen.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    required this.isLoading,
    required this.child,
    super.key,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
