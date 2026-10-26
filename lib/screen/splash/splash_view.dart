import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../resource/app_colors.dart';
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.accessibility_new, size: 72.r, color: AppColors.skeletal),
            SizedBox(height: 16.h),
            Text(
              AppText.appName,
              style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 32.h),
            Obx(() {
              final error = controller.error.value;
              if (error == null) {
                return SizedBox.square(
                  dimension: 24.r,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              }
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Text(
                  AppText.loadError(error),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: Theme.of(context).colorScheme.error),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
