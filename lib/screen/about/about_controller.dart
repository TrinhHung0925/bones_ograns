import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resource/app_text.dart';

class AboutController extends GetxController {
  void openLicenses() {
    showLicensePage(context: Get.context!, applicationName: AppText.appName);
  }

  void onBack() {
    Get.back();
  }
}
