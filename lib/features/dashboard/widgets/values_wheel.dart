import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/value_model.dart';

/// Data for one segment of the Values Wheel.
class WheelSegment {
  const WheelSegment({
    required this.value,
    required this.amount,
    required this.color,
  });

  final ValueModel value;
  final int amount;
  final Color color;
}

/// Animated donut chart showing spending distribution by value.
class ValuesWheel extends StatefulWidget {
  const ValuesWheel({
    super.key,
    required this.segments,
    required this.totalSpending,
  });

  final List<WheelSegment> segments;
  final int totalSpending;

  @override
  State<ValuesWheel> createState() => _ValuesWheelState();
}

class _ValuesWheelState extends State<ValuesWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int? _tappedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
    if (widget.segments.isEmpty || widget.totalSpending == 0) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'No spending this month yet',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Find top segment
    final topSegment = widget.segments.reduce(
      (a, b) => a.amount >= b.amount ? a : b,
    );

    return SizedBox(
      height: 240,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return GestureDetector(
            onTapDown: (details) => _handleTap(details, context),
            child: CustomPaint(
              painter: _WheelPainter(
                segments: widget.segments,
                totalSpending: widget.totalSpending,
                progress: _animation.value,
                tappedIndex: _tappedIndex,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tappedIndex != null
                          ? widget.segments[_tappedIndex!].value.icon
                          : topSegment.value.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tappedIndex != null
                          ? widget.segments[_tappedIndex!].value.name
                          : topSegment.value.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(TapDownDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final center = Offset(box.size.width / 2, box.size.height / 2);
    final pos = details.localPosition - center;
    final dist = pos.distance;
    final outerRadius = math.min(box.size.width, box.size.height) / 2 - 8;
    final innerRadius = outerRadius * 0.55;

    if (dist < innerRadius || dist > outerRadius) {
      setState(() => _tappedIndex = null);
      return;
    }

    var angle = math.atan2(pos.dy, pos.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    double cumulative = 0;
    for (int i = 0; i < widget.segments.length; i++) {
      final sweep =
          (widget.segments[i].amount / widget.totalSpending) * 2 * math.pi;
      cumulative += sweep;
      if (angle <= cumulative) {
        setState(() => _tappedIndex = i);
        return;
      }
    }
    setState(() => _tappedIndex = null);
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.segments,
    required this.totalSpending,
    required this.progress,
    this.tappedIndex,
  });

  final List<WheelSegment> segments;
  final int totalSpending;
  final double progress;
  final int? tappedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 8;
    final innerRadius = outerRadius * 0.55;
    const startAngle = -math.pi / 2; // 12 o'clock
    const gap = 0.02; // gap between segments in radians

    double currentAngle = startAngle;

    for (int i = 0; i < segments.length; i++) {
      final fraction = segments[i].amount / totalSpending;
      final sweepAngle = (fraction * 2 * math.pi - gap) * progress;

      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = segments[i].color
        ..style = PaintingStyle.fill;

      if (tappedIndex == i) {
        paint.color = segments[i].color;
      } else if (tappedIndex != null) {
        paint.color = segments[i].color.withValues(alpha: 0.4);
      }

      final path = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: outerRadius),
          currentAngle,
          sweepAngle,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          currentAngle + sweepAngle,
          -sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);
      currentAngle += sweepAngle + gap;
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.progress != progress || old.tappedIndex != tappedIndex;
}
