import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../resource/app_text.dart';
import 'about_controller.dart';

/// Attribution required by the CC BY-SA licence of the 3D models.
class AboutView extends StatefulWidget {
  AboutView({super.key}) {
    if (!Get.isRegistered<AboutController>()) {
      Get.put(AboutController());
    }
  }

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  var controller = Get.find<AboutController>();

  @override
  void dispose() {
    Get.delete<AboutController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = TextStyle(fontSize: 14.sp, height: 1.4);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: controller.onBack),
        title: Text(AppText.info, style: TextStyle(fontSize: 20.sp)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          Text(AppText.appName, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          Text(AppText.appDescription, style: body),
          SizedBox(height: 24.h),
          Text(AppText.dataSources, style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 8.h),
          Text(AppText.modelCredit, style: body),
          SizedBox(height: 8.h),
          Text(AppText.modelModified, style: body),
          SizedBox(height: 16.h),
          Text(AppText.rendererCredit, style: body),
          SizedBox(height: 16.h),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.openLicenses,
              child: Text(AppText.openSourceLicenses, style: TextStyle(fontSize: 14.sp)),
            ),
          ),
        ],
      ),
    );
  }
}
