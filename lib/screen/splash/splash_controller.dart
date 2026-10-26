import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/asset_server.dart';

class SplashController extends GetxController {
  final error = RxnString();

  @override
  void onReady() {
    super.onReady();
    _init();
  }

  Future<void> _init() async {
    try {
      await Get.putAsync(() => AnatomyService().init(), permanent: true);
      await Get.putAsync(() => AssetServer().init(), permanent: true);
      Get.offAllNamed(AppPage.home.routeName);
    } catch (e, stack) {
      debugPrint('Splash init failed: $e\n$stack');
      error.value = e.toString();
    }
  }

  void onBack() {
    Get.back();
  }
}
