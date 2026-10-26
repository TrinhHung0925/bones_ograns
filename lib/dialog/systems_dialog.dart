import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/system_avatar.dart';
import '../model/body_system.dart';
import '../resource/app_text.dart';
import '../screen/home/home_controller.dart';

/// Bottom sheet that toggles which body systems the home viewer draws.
class SystemsDialog extends StatelessWidget {
  const SystemsDialog({super.key, required this.controller});

  final HomeController controller;

  static Future<void> show(HomeController controller) {
    return showModalBottomSheet<void>(
      context: Get.context!,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SystemsDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.7.sh),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
              child: Text(
                AppText.bodySystems,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
              ),
            ),
            for (final system in BodySystem.values)
              if (controller.anatomy.countIn(system) > 0)
                Obx(() => SwitchListTile(
                      secondary: SystemAvatar(system: system),
                      title: Text(system.label, style: TextStyle(fontSize: 16.sp)),
                      subtitle: Text(
                        controller.loadingSystems.contains(system)
                            ? AppText.loading
                            : '${controller.anatomy.countIn(system)} ${AppText.parts}',
                        style: TextStyle(fontSize: 13.sp),
                      ),
                      value: controller.visibleSystems.contains(system),
                      onChanged: (v) => controller.setSystemVisible(system, v),
                    )),
          ],
        ),
      ),
    );
  }
}
