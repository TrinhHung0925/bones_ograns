import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

const fontDisplay = 'Baloo2';
const fontBody = 'Nunito';

/// Text styles. Sizes are design pixels (390 x 884) scaled with ScreenUtil.
abstract class AppStyle {
  /// Big rounded numbers and names, e.g. the selected part.
  static TextStyle display(double size, {Color color = AppColors.textPrimary}) =>
      TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w800, fontSize: size.sp, height: 1.1, color: color);

  static TextStyle title(double size, {Color color = AppColors.textPrimary}) =>
      TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w700, fontSize: size.sp, height: 1.15, color: color);

  static TextStyle body(double size, {Color color = AppColors.textSecondary, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: fontBody, fontWeight: weight, fontSize: size.sp, height: 1.35, color: color);

  /// Uppercase, letter-spaced section heading ("CHỌN HỆ CƠ QUAN").
  static TextStyle label({Color color = AppColors.textMuted}) =>
      TextStyle(fontFamily: fontBody, fontWeight: FontWeight.w800, fontSize: 12.sp, letterSpacing: 1.4, color: color);

  static TextStyle button(double size, {Color color = AppColors.textPrimary}) =>
      TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w800, fontSize: size.sp, height: 1.1, color: color);

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.wrong,
    );
    return ThemeData(
      colorScheme: scheme,
      fontFamily: fontBody,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.accent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: fontBody, color: AppColors.textPrimary),
      ),
    );
  }
}
