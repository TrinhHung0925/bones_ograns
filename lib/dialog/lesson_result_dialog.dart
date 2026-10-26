import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/game_widgets.dart';
import '../common/star_row.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';

/// End-of-lesson summary: stars, check score and the XP earned. Resolves to
/// true when the user wants to study the lesson again.
class LessonResultDialog extends StatelessWidget {
  const LessonResultDialog({
    super.key,
    required this.title,
    required this.stars,
    required this.score,
    required this.total,
    required this.xp,
    required this.isNewBest,
    this.newLevel,
  });

  final String title;
  final int stars;
  final int score;
  final int total;
  final int xp;
  final bool isNewBest;

  /// Set when the XP made the player level up.
  final int? newLevel;

  static Future<bool> show({
    required String title,
    required int stars,
    required int score,
    required int total,
    required int xp,
    required bool isNewBest,
    int? newLevel,
  }) async {
    final again = await Get.dialog<bool>(
      LessonResultDialog(
        title: title,
        stars: stars,
        score: score,
        total: total,
        xp: xp,
        isNewBest: isNewBest,
        newLevel: newLevel,
      ),
      barrierDismissible: false,
      barrierColor: AppColors.surfaceDepth.withValues(alpha: 0.75),
    );
    return again ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: GameButton(
        radius: 28,
        depth: 8,
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionLabel(AppText.lessonResult),
            Text(
              title,
              style: AppStyle.title(20),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
            StarRow(stars: stars, size: 56, animate: true),
            SizedBox(height: 8.h),
            Text('$score/$total', style: AppStyle.display(48)),
            SizedBox(height: 4.h),
            Text(AppText.lessonResultBody(score, total), textAlign: TextAlign.center, style: AppStyle.body(14)),
            SizedBox(height: 12.h),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                StatPill(
                  text: AppText.lessonXpGain(xp),
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.accent,
                  background: AppColors.primaryDepth,
                ),
                if (newLevel != null)
                  StatPill(
                    text: AppText.lessonLevelUp(newLevel!),
                    icon: Icons.military_tech_rounded,
                    iconColor: AppColors.accent,
                  ),
                if (isNewBest)
                  const StatPill(
                    text: AppText.lessonNewBest,
                    icon: Icons.emoji_events_rounded,
                    iconColor: AppColors.accent,
                  ),
              ],
            ),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                tone: GameTone.accent,
                onTap: () => Get.back(result: false),
                radius: 20,
                depth: 6,
                padding: EdgeInsets.symmetric(vertical: 15.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_rounded, color: AppColors.onAccent, size: 22.r),
                    SizedBox(width: 8.w),
                    Text(AppText.lessonToList, style: AppStyle.button(18, color: AppColors.onAccent)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                tone: GameTone.raised,
                onTap: () => Get.back(result: true),
                radius: 20,
                padding: EdgeInsets.symmetric(vertical: 13.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_rounded, color: AppColors.textPrimary, size: 20.r),
                    SizedBox(width: 6.w),
                    Text(AppText.lessonRestudy, style: AppStyle.button(17)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
