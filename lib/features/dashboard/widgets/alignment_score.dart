import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Circular progress indicator comparing actual spending vs plan.
class AlignmentScore extends StatefulWidget {
  const AlignmentScore({super.key, required this.score});

  /// 0.0 to 1.0
  final double score;

  @override
  State<AlignmentScore> createState() => _AlignmentScoreState();
}

class _AlignmentScoreState extends State<AlignmentScore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AlignmentScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.score * 100).round();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final animatedScore = widget.score * _animation.value;
        final animatedPercent = (animatedScore * 100).round();

        return SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _ScorePainter(progress: animatedScore),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$animatedPercent%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w700,
                      color: _scoreColor(percent / 100),
                    ),
                  ),
                  Text(
                    'aligned',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _scoreColor(double score) {
    if (score >= 0.7) return AppColors.secondary;
    if (score >= 0.4) return AppColors.primary;
    return AppColors.expense;
  }
}

class _ScorePainter extends CustomPainter {
  _ScorePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    // Background track
    final bgPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = _color(progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  static Color _color(double p) {
    if (p >= 0.7) return AppColors.secondary;
    if (p >= 0.4) return AppColors.primary;
    return AppColors.expense;
  }

  @override
  bool shouldRepaint(_ScorePainter old) => old.progress != progress;
}
