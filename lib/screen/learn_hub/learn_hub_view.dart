import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'learn_hub_controller.dart';

class LearnHubView extends StatefulWidget {
  LearnHubView({super.key}) {
    if (!Get.isRegistered<LearnHubController>()) {
      Get.put(LearnHubController());
    }
  }

  @override
  State<LearnHubView> createState() => _LearnHubViewState();
}

class _LearnHubViewState extends State<LearnHubView> {
  var controller = Get.find<LearnHubController>();

  @override
  void dispose() {
    Get.delete<LearnHubController>();
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
        child: SafeArea(
          child: GetBuilder<LearnHubController>(
            builder: (controller) => Column(
              children: [
                GameHeader(title: AppText.learnHubTitle, subtitle: AppText.learnHubSubtitle, onBack: controller.onBack),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                    children: [
                      _ProfileCard(controller: controller),
                      SizedBox(height: 20.h),
                      const SectionLabel(AppText.learnModes),
                      _BuilderCard(best: controller.builderBest, onTap: controller.openBoneBuilder),
                      SizedBox(height: 10.h),
                      _ModeCard(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.accent,
                        title: AppText.learnDaily,
                        subtitle: controller.dailyDone
                            ? AppText.learnDailyDone(controller.dailyScore ?? 0)
                            : AppText.learnDailyTodo,
                        trailing: controller.dailyDone
                            ? Icon(Icons.check_circle_rounded, color: AppColors.correct, size: 24.r)
                            : const StatPill(text: AppText.learnDailyNew, dotColor: AppColors.accent),
                        highlight: !controller.dailyDone,
                        onTap: controller.openDaily,
                      ),
                      SizedBox(height: 10.h),
                      _ModeCard(
                        icon: Icons.menu_book_rounded,
                        color: AppColors.correct,
                        title: AppText.learnByRegion,
                        subtitle: AppText.learnByRegionHint(controller.lessonsDone, controller.lessonCount),
                        onTap: controller.openLessons,
                      ),
                      SizedBox(height: 10.h),
                      _ModeCard(
                        icon: Icons.assignment_rounded,
                        color: AppColors.endocrine,
                        title: AppText.learnExam,
                        subtitle: AppText.learnExamHint,
                        onTap: controller.openExam,
                      ),
                      SizedBox(height: 10.h),
                      _ModeCard(
                        icon: Icons.bookmark_rounded,
                        color: AppColors.wrong,
                        title: AppText.learnMistakeBook,
                        subtitle: AppText.learnMistakeHint(controller.mistakeCount),
                        trailing: controller.mistakeCount > 0
                            ? StatPill(text: '${controller.mistakeCount}', background: AppColors.wrong)
                            : null,
                        onTap: controller.openMistakes,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Level badge, XP bar, streak and mistake count.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.controller});

  final LearnHubController controller;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: GameTone.primary,
      fadeWhenDisabled: false,
      radius: 24,
      depth: 6,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LevelBadge(level: controller.level),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppText.learnLevel(controller.level), style: AppStyle.display(26)),
                    SizedBox(height: 2.h),
                    Text(
                      AppText.learnXpToNext(controller.xpToNextLevel),
                      style: AppStyle.body(13, color: AppColors.textPrimary.withValues(alpha: 0.8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatPill(
                text: AppText.learnXp(controller.xp),
                icon: Icons.bolt_rounded,
                iconColor: AppColors.accent,
                background: AppColors.primaryDepth,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            height: 10.h,
            decoration: BoxDecoration(color: AppColors.primaryDepth, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: controller.levelProgress,
              child: Container(
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.accent,
                  value: AppText.learnStreakDays(controller.streak),
                  label: '${AppText.learnStreak} · ${AppText.learnBestStreak(controller.bestStreak)}',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _StatTile(
                  icon: Icons.bookmark_rounded,
                  color: AppColors.wrong,
                  value: '${controller.mistakeCount}',
                  label: AppText.learnMistakes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Golden medal with the level number.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58.r,
      height: 58.r,
      padding: EdgeInsets.only(bottom: 4.r),
      decoration: const BoxDecoration(color: AppColors.accentDepth, shape: BoxShape.circle),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        child: Text('$level', style: AppStyle.display(26, color: AppColors.onAccent)),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.primaryDepth.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppStyle.title(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  label,
                  style: AppStyle.body(11, color: AppColors.textPrimary.withValues(alpha: 0.75)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.highlight = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Outlines the card, for today's challenge while it's not done.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      child: GameButton(
        onTap: onTap,
        selected: highlight,
        radius: 18,
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
        child: Row(
          children: [
            IconBubble(icon: icon, color: color, size: 46),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppStyle.title(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2.h),
                  Text(subtitle, style: AppStyle.body(12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            trailing ?? Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 26.r),
          ],
        ),
      ),
    );
  }
}

/// Eye-catching entry of the creative bone builder, with a "MỚI" ribbon and
/// the best score.
class _BuilderCard extends StatelessWidget {
  const _BuilderCard({required this.best, required this.onTap});

  final int? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppText.builderTitle,
      child: GameButton(
        tone: GameTone.accent,
        onTap: onTap,
        radius: 20,
        depth: 6,
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
        child: Row(
          children: [
            Container(
              width: 50.r,
              height: 50.r,
              decoration: const BoxDecoration(color: AppColors.onAccent, shape: BoxShape.circle),
              child: Icon(Icons.construction_rounded, color: AppColors.accent, size: 28.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          AppText.builderTitle,
                          style: AppStyle.title(18, color: AppColors.onAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.r, vertical: 2.r),
                        decoration: BoxDecoration(color: AppColors.wrong, borderRadius: BorderRadius.circular(6.r)),
                        child: Text(AppText.builderNew, style: AppStyle.button(11)),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    AppText.builderSubtitle,
                    style: AppStyle.body(12, color: AppColors.onAccent.withValues(alpha: 0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            StatPill(
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.accent,
              background: AppColors.onAccent,
              text: AppText.builderBestShort(best),
            ),
          ],
        ),
      ),
    );
  }
}
