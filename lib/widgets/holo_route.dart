import 'package:flutter/material.dart';

class HoloRoute<T> extends PageRouteBuilder<T> {
  HoloRoute({required Widget page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final t = animation.value;

                // Phase 1 (0-0.35): Sky builds, building shrinks below
                final skyOpacity = (t / 0.35).clamp(0.0, 1.0).toDouble();

                // Phase 2 (0.35-0.55): Sky hold
                // Phase 3 (0.55-1.0): Floor plan rises up
                final planProgress = ((t - 0.5) / 0.45).clamp(0.0, 1.0).toDouble();
                final planY = 60 * (1.0 - planProgress);
                final planScale = 0.88 + 0.12 * planProgress;
                final planOpacity = planProgress;

                return Stack(
                  children: [
                    // Sky background
                    Positioned.fill(
                      child: Opacity(
                        opacity: skyOpacity,
                        child: CustomPaint(
                          painter: _DronePainter(progress: t),
                        ),
                      ),
                    ),
                    // Floor plan rises from below
                    Positioned.fill(
                      child: Opacity(
                        opacity: planOpacity,
                        child: Transform.translate(
                          offset: Offset(0, planY),
                          child: Transform.scale(
                            scale: planScale,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 900),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

class _DronePainter extends CustomPainter {
  final double progress;

  _DronePainter({this.progress = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Sky gradient: pale blue at top, lighter at bottom
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF87CEEB).withValues(alpha: progress),
          const Color(0xFFE0F0FF).withValues(alpha: progress * 0.8),
          Colors.white.withValues(alpha: progress * 0.6),
        ],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    if (progress <= 0 || progress >= 1) return;

    // Building silhouette that shrinks and falls below
    final buildingPhase = (progress / 0.35).clamp(0.0, 1.0);
    final buildingScale = 1.0 - buildingPhase * 0.7;
    final buildingY = buildingPhase * size.height * 0.4;

    if (buildingScale > 0.05) {
      final c = Offset(size.width / 2, size.height * 0.4 + buildingY);
      final bw = 80 * buildingScale;
      final bh = 160 * buildingScale;

      final buildingPaint = Paint()
        ..color = const Color(0xFF2C3E50).withValues(alpha: (1.0 - buildingPhase * 0.6));

      // Main building body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: bw, height: bh),
          const Radius.circular(4),
        ),
        buildingPaint,
      );

      // Roof
      canvas.drawRect(
        Rect.fromCenter(center: Offset(c.dx, c.dy - bh / 2), width: bw * 1.05, height: 4 * buildingScale),
        buildingPaint,
      );

      // Windows (small dots)
      if (buildingScale > 0.3) {
        final winPaint = Paint()
          ..color = const Color(0xFFF1C40F).withValues(alpha: 0.5 * (1.0 - buildingPhase * 0.5));
        for (int row = 0; row < 5; row++) {
          for (int col = 0; col < 3; col++) {
            final wx = c.dx - bw * 0.3 + col * bw * 0.3;
            final wy = c.dy - bh * 0.35 + row * bh * 0.15;
            canvas.drawRect(
              Rect.fromCenter(center: Offset(wx, wy), width: 4 * buildingScale, height: 6 * buildingScale),
              winPaint,
            );
          }
        }
      }
    }

    // Clouds that fade in and drift
    if (progress > 0.1) {
      final cloudPhase = ((progress - 0.1) / 0.3).clamp(0.0, 1.0);
      final cloudPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * cloudPhase * (1.0 - (progress - 0.4).clamp(0.0, 0.6) / 0.6));

      if (cloudPaint.color.a > 0.01) {
        // Cloud 1 (left)
        canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.2 - cloudPhase * 30, size.height * 0.2), width: 100, height: 40), cloudPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.25 - cloudPhase * 30, size.height * 0.19), width: 60, height: 30), cloudPaint);
        // Cloud 2 (right)
        canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.75 + cloudPhase * 20, size.height * 0.3), width: 80, height: 35), cloudPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.8 + cloudPhase * 20, size.height * 0.28), width: 50, height: 25), cloudPaint);
      }
    }

    // Sun glow at top
    if (progress > 0.05) {
      final sunPhase = ((progress - 0.05) / 0.3).clamp(0.0, 1.0);
      final sunGlow = Paint()
        ..color = const Color(0xFFFFF3E0).withValues(alpha: 0.3 * sunPhase)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.1), 50, sunGlow);
    }
  }

  @override
  bool shouldRepaint(covariant _DronePainter old) => old.progress != progress;
}
