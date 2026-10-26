import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_colors.dart';

/// [stars] filled stars out of [max] (★★☆). With [animate] each earned star
/// pops in one after another, for result screens.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.max = 3, this.size = 18, this.animate = false});

  final int stars;
  final int max;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: (size * 0.06).w),
            child: _star(i < stars, i),
          ),
      ],
    );
  }

  Widget _star(bool earned, int index) {
    final icon = Icon(
      earned ? Icons.star_rounded : Icons.star_outline_rounded,
      size: size.r,
      color: earned ? AppColors.star : AppColors.textMuted,
    );
    if (!animate || !earned) return icon;
    // Each star waits for the previous one, then overshoots into place.
    final start = 0.15 + index * 0.25;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      builder: (context, t, child) {
        final local = ((t - start) / 0.4).clamp(0.0, 1.0);
        return Transform.scale(scale: Curves.elasticOut.transform(local), child: child);
      },
      child: icon,
    );
  }
}
