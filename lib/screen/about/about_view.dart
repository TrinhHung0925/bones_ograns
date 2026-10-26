import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
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
    final body = AppStyle.body(14);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            GameHeader(title: AppText.info, subtitle: AppText.appName, onBack: controller.onBack),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                children: [
                  const SectionLabel(AppText.aboutApp),
                  GameButton(
                    tone: GameTone.primary,
                    fadeWhenDisabled: false,
                    radius: 24,
                    depth: 6,
                    padding: EdgeInsets.all(16.r),
                    child: Row(
                      children: [
                        const BrandTile(size: 56),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppText.appName, style: AppStyle.display(26)),
                              SizedBox(height: 4.h),
                              Text(AppText.appDescription, style: AppStyle.body(14, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 22.h),
                  const SectionLabel(AppText.dataSources),
                  _InfoCard(
                    icon: Icons.view_in_ar_rounded,
                    color: AppColors.skeletal,
                    children: [
                      Text(AppText.modelCredit, style: body),
                      SizedBox(height: 10.h),
                      Text(AppText.modelModified, style: body),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _InfoCard(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.joint,
                    children: [Text(AppText.zAnatomyCredit, style: body)],
                  ),
                  SizedBox(height: 12.h),
                  _InfoCard(
                    icon: Icons.code_rounded,
                    color: AppColors.sensory,
                    children: [Text(AppText.rendererCredit, style: body)],
                  ),
                  SizedBox(height: 22.h),
                  GameButton(
                    onTap: controller.openLicenses,
                    radius: 18,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                    child: Row(
                      children: [
                        const IconBubble(icon: Icons.gavel_rounded, color: AppColors.accent, size: 38),
                        SizedBox(width: 12.w),
                        Expanded(child: Text(AppText.openSourceLicenses, style: AppStyle.title(16))),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 26.r),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.color, required this.children});

  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      padding: EdgeInsets.all(14.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: icon, color: color, size: 38),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}
