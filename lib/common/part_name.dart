import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';

/// A part name: Vietnamese first, with the English (FMA) name below it,
/// smaller and muted, behind a small "EN" tag. The English line is hidden
/// when both names are the same (no translation yet).
class PartName extends StatelessWidget {
  const PartName({
    super.key,
    required this.vi,
    required this.en,
    required this.style,
    this.englishSize = 13,
    this.maxLines = 2,
    this.englishColor = AppColors.textSecondary,
  });

  final String vi;
  final String en;
  final TextStyle style;
  final double englishSize;
  final int maxLines;
  final Color englishColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vi, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis),
        if (en != vi) ...[
          SizedBox(height: 2.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                decoration: BoxDecoration(
                  color: englishColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  AppText.englishTag,
                  style: AppStyle.body(englishSize - 4, color: englishColor, weight: FontWeight.w800),
                ),
              ),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  en,
                  style: AppStyle.body(englishSize, color: englishColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
