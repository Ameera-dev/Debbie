import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashIcon extends StatefulWidget {
  const SplashIcon({super.key, this.size = 140});

  final double size;

  @override
  State<SplashIcon> createState() => _SplashIconState();
}

class _SplashIconState extends State<SplashIcon>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _loopController;

  late final Animation<double> _wave1;
  late final Animation<double> _wave2;
  late final Animation<double> _wave3;
  late final Animation<double> _sunRise;
  late final Animation<double> _sunFade;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _wave3 = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _wave2 = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.12, 0.65, curve: Curves.easeOutCubic),
    );
    _wave1 = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.22, 0.78, curve: Curves.easeOutCubic),
    );
    _sunRise = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );
    _sunFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 0.95, curve: Curves.easeOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryController, _loopController]),
        builder: (context, _) {
          final loop = _loopController.value;
          // Gentle bob: a small sine wave on a continuous 0..1..0 ping-pong.
          final bob = math.sin(loop * math.pi * 2) * (s * 0.012);
          // Wave drift: shift the wave phase subtly side-to-side.
          final drift = math.sin(loop * math.pi * 2);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Wave 3 — back, palest
              _waveLayer(
                progress: _wave3.value,
                color: const Color(0xFFA8BCC9),
                amplitudeFactor: 0.055,
                heightFactor: 0.18,
                bottomFactor: 0.18,
                phase: drift * 0.25,
                size: s,
              ),
              // Wave 2 — mid, medium teal
              _waveLayer(
                progress: _wave2.value,
                color: const Color(0xFF4F7787),
                amplitudeFactor: 0.06,
                heightFactor: 0.20,
                bottomFactor: 0.10,
                phase: -drift * 0.30,
                size: s,
              ),
              // Wave 1 — front, deepest
              _waveLayer(
                progress: _wave1.value,
                color: const Color(0xFF2C5664),
                amplitudeFactor: 0.045,
                heightFactor: 0.24,
                bottomFactor: 0.02,
                phase: drift * 0.20,
                size: s,
              ),
              // Sun — rises from behind the waves and bobs
              Positioned(
                top: s * 0.18 + (1 - _sunRise.value) * s * 0.20 + bob,
                child: Opacity(
                  opacity: _sunFade.value,
                  child: Container(
                    width: s * 0.22,
                    height: s * 0.22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(-0.2, -0.3),
                        radius: 0.85,
                        colors: [
                          Color(0xFFE8C97A),
                          Color(0xFFC9A655),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _waveLayer({
    required double progress,
    required Color color,
    required double amplitudeFactor,
    required double heightFactor,
    required double bottomFactor,
    required double phase,
    required double size,
  }) {
    // Slide each wave up from below (translateY = +size at progress 0).
    final dy = (1 - progress) * size * 0.5;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: CustomPaint(
          size: Size(size, size),
          painter: _WavePainter(
            color: color,
            amplitudeFactor: amplitudeFactor,
            heightFactor: heightFactor,
            bottomFactor: bottomFactor,
            phase: phase,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.color,
    required this.amplitudeFactor,
    required this.heightFactor,
    required this.bottomFactor,
    required this.phase,
  });

  final Color color;
  final double amplitudeFactor; // wave amplitude as fraction of canvas
  final double heightFactor;    // base height as fraction from bottom
  final double bottomFactor;    // distance from bottom edge
  final double phase;           // -1..1, shifts the wave horizontally

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final amplitude = h * amplitudeFactor;
    final baseY = h - h * bottomFactor - h * heightFactor;
    final shapeWidth = w * 0.78;
    final left = (w - shapeWidth) / 2;
    final right = left + shapeWidth;
    final shift = phase * w * 0.04;

    final path = Path();
    // Start on the left at base height
    path.moveTo(left, baseY);
    // Smooth S-curve top using two cubic beziers
    final mid = (left + right) / 2;
    path.cubicTo(
      left + shapeWidth * 0.20 + shift, baseY - amplitude * 1.6,
      mid - shapeWidth * 0.05 + shift,  baseY - amplitude * 1.4,
      mid + shift,                       baseY - amplitude * 0.2,
    );
    path.cubicTo(
      mid + shapeWidth * 0.18 + shift,  baseY + amplitude * 0.9,
      right - shapeWidth * 0.18 + shift, baseY + amplitude * 0.4,
      right,                             baseY - amplitude * 0.3,
    );
    // Rounded bottom
    final bottomY = h - h * bottomFactor;
    path.lineTo(right, bottomY - 12);
    path.quadraticBezierTo(right, bottomY, right - 18, bottomY);
    path.lineTo(left + 18, bottomY);
    path.quadraticBezierTo(left, bottomY, left, bottomY - 12);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.color != color ||
      old.amplitudeFactor != amplitudeFactor ||
      old.heightFactor != heightFactor ||
      old.bottomFactor != bottomFactor ||
      old.phase != phase;
}
