import 'package:flutter/material.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_radius.dart';

/// Google-branded sign-in button for S-01. Shows a "G" mark and
/// "Continue with Google" text; while [isLoading] is true it is disabled and
/// shows a centered spinner instead of its content.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    required this.isLoading,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(color: colors.border, width: 1.5),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _GoogleGIcon(size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple painted approximation of the Google "G" mark — avoids pulling
/// in a new icon/asset dependency for a single glyph.
class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    void arc(double startDegrees, double sweepDegrees, Color color) {
      paint.color = color;
      canvas.drawArc(
        rect,
        startDegrees * 3.1415926535 / 180,
        sweepDegrees * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-90, 90, _blue);
    arc(0, 90, _green);
    arc(90, 90, _yellow);
    arc(180, 90, _red);

    // Horizontal bar of the "G".
    final barPaint = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth / 2,
        radius,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
