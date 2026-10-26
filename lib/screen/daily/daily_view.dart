import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../model/exam_config.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import '../../service/progress_service.dart';
import 'daily_controller.dart';

class DailyView extends StatefulWidget {
  DailyView({super.key}) {
    if (!Get.isRegistered<DailyController>()) {
      Get.put(DailyController());
    }
  }

  @override
  State<DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends State<DailyView> {
  var controller = Get.find<DailyController>();

  @override
  void dispose() {
    Get.delete<DailyController>();
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
        child: GetBuilder<DailyController>(
          builder: (controller) => Column(
            children: [
              SafeArea(
                bottom: false,
                child: GameHeader(
                  title: AppText.examDailyTitle,
                  subtitle: AppText.examDailySubtitle,
                  onBack: controller.onBack,
                  actions: [
                    Obx(
                      () => StatPill(
                        text: '${controller.progress.streak.value}',
                        icon: Icons.local_fire_department_rounded,
                        iconColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
                  children: [
                    _HeroCard(controller: controller),
                    SizedBox(height: 16.h),
                    _InfoRow(
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.accent,
                      title: AppText.examStreak,
                      child: Obx(
                        () => Text(AppText.examStreakDays(controller.progress.streak.value), style: AppStyle.title(17)),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _InfoRow(
                      icon: Icons.card_giftcard_rounded,
                      color: AppColors.correct,
                      title: controller.done ? AppText.examDailyClaimed : AppText.examXp,
                      child: Text(
                        controller.done
                            ? AppText.examDailyToday(controller.todayScore ?? 0)
                            : AppText.examDailyReward(ProgressService.xpDailyBonus),
                        style: AppStyle.body(14, color: AppColors.textPrimary, weight: FontWeight.w700),
                      ),
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
                        Icon(
                          controller.done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                          color: AppColors.onAccent,
                          size: 26.r,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          controller.done ? AppText.examDailyReplay : AppText.examDailyStart,
                          style: AppStyle.button(19, color: AppColors.onAccent),
                        ),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});

  final DailyController controller;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: GameTone.primary,
      fadeWhenDisabled: false,
      radius: 26,
      depth: 7,
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatPill(text: AppText.examDailyDate(controller.date), icon: Icons.calendar_today_rounded),
              const Spacer(),
              if (controller.done)
                const Icon(Icons.check_circle_rounded, color: AppColors.correct)
              else
                const Icon(Icons.bolt_rounded, color: AppColors.accent),
            ],
          ),
          SizedBox(height: 14.h),
          Text(AppText.examDailyTitle, style: AppStyle.display(28)),
          SizedBox(height: 4.h),
          Text(
            AppText.examDailyInfo(ExamConfig.dailyLength, ExamConfig.secondsPerQuestion),
            style: AppStyle.body(14, color: AppColors.textPrimary.withValues(alpha: 0.85)),
          ),
          if (controller.done) ...[
            SizedBox(height: 12.h),
            const StatPill(text: AppText.examDailyClaimed, icon: Icons.check_rounded, iconColor: AppColors.correct),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.color, required this.title, required this.child});

  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GameButton(
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
                Text(title.toUpperCase(), style: AppStyle.label()),
                SizedBox(height: 2.h),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
