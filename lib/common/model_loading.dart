import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';

/// Centered "loading the 3D model" state: a pulsing brand tile inside a
/// spinning golden ring, with animated dots after the label. Show it only
/// while loading: it animates forever, which stalls flutter_driver taps.
class ModelLoading extends StatefulWidget {
  const ModelLoading({super.key, this.label = AppText.loadingModel, this.detail});

  final String label;

  /// Optional second line, e.g. the systems being loaded.
  final String? detail;

  @override
  State<ModelLoading> createState() => _ModelLoadingState();
}

class _ModelLoadingState extends State<ModelLoading> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label.replaceAll('…', '');
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Two soft beats per turn of the ring.
          final pulse = 1 + 0.06 * math.sin(t * 4 * math.pi);
          final dots = (t * 4).floor() % 4;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 120.r,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft glow behind everything.
                    Container(
                      width: 104.r,
                      height: 104.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35 + 0.15 * math.sin(t * 2 * math.pi)),
                            blurRadius: 36.r,
                            spreadRadius: 4.r,
                          ),
                        ],
                      ),
                    ),
                    Transform.rotate(
                      angle: t * 2 * math.pi,
                      child: CustomPaint(
                        size: Size.square(120.r),
                        painter: _RingPainter(stroke: 6.r),
                      ),
                    ),
                    Transform.scale(scale: pulse, child: const _BodyTile()),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppStyle.title(19)),
                  // Fixed width so the label doesn't jiggle as dots appear.
                  SizedBox(
                    width: 24.w,
                    child: Text('.' * dots, style: AppStyle.title(19, color: AppColors.accent)),
                  ),
                ],
              ),
              if (widget.detail != null) ...[
                SizedBox(height: 4.h),
                Text(widget.detail!, style: AppStyle.body(13), textAlign: TextAlign.center),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Violet rounded tile with the body glyph and a darker bottom edge.
class _BodyTile extends StatelessWidget {
  const _BodyTile();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22.r);
    return Container(
      width: 70.r,
      height: 70.r,
      padding: EdgeInsets.only(bottom: 6.r),
      decoration: BoxDecoration(color: AppColors.primaryDepth, borderRadius: radius),
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: radius),
        child: Center(
          child: Icon(Icons.accessibility_new_rounded, size: 40.r, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Faint full track plus a golden arc fading into its tail, with a bright
/// dot leading the arc.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.stroke});

  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    canvas.drawArc(
      ring,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.surfaceRaised,
    );
    const sweep = 1.6 * math.pi;
    canvas.drawArc(
      ring,
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: sweep,
          colors: [AppColors.accent.withValues(alpha: 0), AppColors.accentDepth, AppColors.accent],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    final center = rect.center;
    final head = center + Offset(math.cos(sweep), math.sin(sweep)) * (ring.width / 2);
    canvas.drawCircle(head, stroke * 0.95, Paint()..color = AppColors.textPrimary);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.stroke != stroke;
}
