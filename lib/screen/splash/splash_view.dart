import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'splash_controller.dart';

class SplashView extends StatefulWidget {
  SplashView({super.key}) {
    if (!Get.isRegistered<SplashController>()) {
      Get.put(SplashController());
    }
  }

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  var controller = Get.find<SplashController>();

  @override
  void dispose() {
    Get.delete<SplashController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 0.9,
            colors: [AppColors.backgroundGlow, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandTile(size: 108),
                SizedBox(height: 28.h),
                Text(AppText.appName, style: AppStyle.display(40), textAlign: TextAlign.center),
                SizedBox(height: 6.h),
                Text(AppText.appTagline, style: AppStyle.body(16), textAlign: TextAlign.center),
                SizedBox(height: 40.h),
                Obx(() {
                  final error = controller.error.value;
                  return error == null ? const _ProgressBar() : _ErrorCard(error: error);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chunky yellow bar that eases towards full while services start. It is a
/// finite animation, so it never keeps frames scheduled.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Container(
      height: 22.h,
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth,
        borderRadius: radius,
        border: Border.all(color: AppColors.border, width: 1.5.r),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.08, end: 0.92),
        duration: const Duration(milliseconds: 2400),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            // Darker bottom edge, like the game buttons.
            child: Container(
              padding: EdgeInsets.only(bottom: 4.h),
              decoration: BoxDecoration(color: AppColors.accentDepth, borderRadius: radius),
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: radius),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      padding: EdgeInsets.all(16.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBubble(icon: Icons.error_outline_rounded, color: AppColors.wrong, size: 40),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppText.loadFailed, style: AppStyle.title(17)),
                SizedBox(height: 4.h),
                Text(AppText.loadError(error), style: AppStyle.body(13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
