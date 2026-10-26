import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../model/exam_config.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'exam_setup_controller.dart';

class ExamSetupView extends StatefulWidget {
  ExamSetupView({super.key}) {
    if (!Get.isRegistered<ExamSetupController>()) {
      Get.put(ExamSetupController());
    }
  }

  @override
  State<ExamSetupView> createState() => _ExamSetupViewState();
}

class _ExamSetupViewState extends State<ExamSetupView> {
  var controller = Get.find<ExamSetupController>();

  @override
  void dispose() {
    Get.delete<ExamSetupController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.2,
            colors: [AppColors.backgroundGlow, AppColors.background],
          ),
        ),
        child: GetBuilder<ExamSetupController>(
          builder: (controller) => Column(
            children: [
              SafeArea(
                bottom: false,
                child: GameHeader(
                  title: AppText.examSetupTitle,
                  subtitle: AppText.examSetupSubtitle,
                  onBack: controller.onBack,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
                  children: [
                    const SectionLabel(AppText.examScope),
                    _ScopeGrid(controller: controller),
                    SizedBox(height: 18.h),
                    const SectionLabel(AppText.examLength),
                    Row(
                      children: [
                        for (final length in ExamConfig.lengths) ...[
                          if (length != ExamConfig.lengths.first) SizedBox(width: 10.w),
                          Expanded(
                            child: GameButton(
                              selected: controller.length == length,
                              onTap: () => controller.selectLength(length),
                              radius: 16,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Center(child: Text(AppText.examQuestions(length), style: AppStyle.title(17))),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 18.h),
                    const SectionLabel(AppText.examMode),
                    _ModeTile(
                      icon: Icons.school_rounded,
                      color: AppColors.correct,
                      title: AppText.examModePractice,
                      hint: AppText.examModePracticeHint,
                      selected: controller.mode == ExamMode.practice,
                      onTap: () => controller.selectMode(ExamMode.practice),
                    ),
                    SizedBox(height: 10.h),
                    _ModeTile(
                      icon: Icons.timer_rounded,
                      color: AppColors.accent,
                      title: AppText.examModeTest,
                      hint: AppText.examModeTestHint(ExamConfig.secondsPerQuestion),
                      selected: controller.mode == ExamMode.test,
                      onTap: () => controller.selectMode(ExamMode.test),
                    ),
                  ],
                ),
              ),
              BottomPanel(
                child: SizedBox(
                  width: double.infinity,
                  child: GameButton(
                    tone: GameTone.accent,
                    onTap: controller.start,
                    radius: 20,
                    depth: 6,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: AppColors.onAccent, size: 26.r),
                        SizedBox(width: 6.w),
                        Text(AppText.examStart, style: AppStyle.button(19, color: AppColors.onAccent)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 'Toàn thân' and every system with parts, each with its best score.
class _ScopeGrid extends StatelessWidget {
  const _ScopeGrid({required this.controller});

  final ExamSetupController controller;

  @override
  Widget build(BuildContext context) {
    final scopes = [null, ...controller.systems];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: scopes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10.h,
        crossAxisSpacing: 10.w,
        mainAxisExtent: 122.h,
      ),
      itemBuilder: (context, i) {
        final system = scopes[i];
        final best = controller.best(system);
        return Align(
          alignment: Alignment.topCenter,
          child: GameButton(
            selected: controller.system == system,
            onTap: () => controller.selectSystem(system),
            radius: 20,
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 10.h),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconBubble(
                    icon: system?.icon ?? Icons.accessibility_new_rounded,
                    color: system?.color ?? AppColors.primary,
                    size: 40,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    system?.label ?? AppText.examWholeBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.title(14),
                  ),
                  Text(
                    AppText.partCount(controller.partCount(system)),
                    maxLines: 1,
                    style: AppStyle.body(10, color: AppColors.textMuted, weight: FontWeight.w700),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 12.r,
                        color: best > 0 ? AppColors.star : AppColors.textMuted,
                      ),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          best > 0 ? AppText.examBest(best) : AppText.examNoBest,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyle.body(10, color: AppColors.textSecondary, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      selected: selected,
      onTap: onTap,
      radius: 18,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          IconBubble(icon: icon, color: color, size: 40),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppStyle.title(17)),
                Text(hint, style: AppStyle.body(13)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? AppColors.primary : AppColors.textMuted,
            size: 22.r,
          ),
        ],
      ),
    );
  }
}
