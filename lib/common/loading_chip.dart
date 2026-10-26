import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';

/// Dark pill with a small spinner. Show it only while something is actually
/// loading: the spinner animates forever, which stalls flutter_driver taps.
class LoadingChip extends StatelessWidget {
  const LoadingChip({super.key, this.label = AppText.loadingModel});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 14.r,
            child: const CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accent),
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: AppStyle.body(13, color: AppColors.textPrimary, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
