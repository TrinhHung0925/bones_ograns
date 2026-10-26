import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/game_widgets.dart';
import '../common/part_name.dart';
import '../common/star_row.dart';
import '../model/exam_config.dart';
import '../model/exam_result.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import '../service/progress_service.dart';
import '../utils/assembly_score.dart';
import '../utils/quiz_session.dart';

/// End-of-exam summary; resolves to true when the user wants to play again.
class ExamResultDialog extends StatelessWidget {
  const ExamResultDialog({super.key, required this.result});

  final ExamResult result;

  static Future<bool> show(ExamResult result) async {
    final again = await Get.dialog<bool>(
      ExamResultDialog(result: result),
      barrierDismissible: false,
      barrierColor: AppColors.surfaceDepth.withValues(alpha: 0.75),
    );
    return again ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.86.sh),
        child: GameButton(
          radius: 28,
          depth: 8,
          padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionLabel(r.kind == ExamKind.daily ? AppText.examDailyTitle : AppText.examResult),
              StarRow(stars: QuizSession.starsFor(r.correct, r.total), size: 48, animate: true),
              SizedBox(height: 6.h),
              Text(AppText.examScore(r.score), style: AppStyle.display(40)),
              Text(AppText.examCorrectCount(r.correct, r.total), style: AppStyle.body(14)),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: AppText.examAccuracy,
                      value: '${(r.accuracy * 100).round()}%',
                      icon: Icons.track_changes_rounded,
                      color: AppColors.correct,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _Stat(
                      label: AppText.examTime,
                      value: formatClock(r.time),
                      icon: Icons.timer_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _Stat(
                      label: AppText.examXp,
                      value: AppText.examXpValue(r.xp),
                      icon: Icons.bolt_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  if (r.isNewBest)
                    const StatPill(
                      text: AppText.examNewBest,
                      icon: Icons.emoji_events_rounded,
                      iconColor: AppColors.accent,
                    )
                  else if (r.best != null)
                    StatPill(text: AppText.examBestScore(r.best!), icon: Icons.emoji_events_outlined),
                  if (r.levelUp)
                    const StatPill(
                      text: AppText.examLevelUp,
                      icon: Icons.arrow_upward_rounded,
                      iconColor: AppColors.correct,
                    ),
                  if (r.streak != null)
                    StatPill(
                      text: AppText.examStreakDays(r.streak!),
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppColors.accent,
                    ),
                  if (r.dailyFirst == true)
                    StatPill(
                      text: AppText.examDailyBonus(ProgressService.xpDailyBonus),
                      icon: Icons.card_giftcard_rounded,
                      iconColor: AppColors.accent,
                    ),
                  if (r.dailyFirst == false)
                    const StatPill(text: AppText.examDailyClaimed, icon: Icons.check_circle_outline_rounded),
                ],
              ),
              SizedBox(height: 14.h),
              Align(alignment: Alignment.centerLeft, child: SectionLabel(AppText.examMissedTitle(r.missed.length))),
              Flexible(child: _MissedList(missed: r)),
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  tone: GameTone.accent,
                  onTap: () => Get.back(result: true),
                  radius: 20,
                  depth: 6,
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.replay_rounded, color: AppColors.onAccent, size: 24.r),
                      SizedBox(width: 8.w),
                      Text(AppText.examAgain, style: AppStyle.button(19, color: AppColors.onAccent)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  tone: GameTone.raised,
                  onTap: () => Get.back(result: false),
                  radius: 20,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  child: Center(child: Text(AppText.examBack, style: AppStyle.button(17))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18.r, color: color),
          SizedBox(height: 2.h),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppStyle.title(16)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyle.body(11, color: AppColors.textMuted, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Wrong or missed parts with both names, scrollable when long.
class _MissedList extends StatelessWidget {
  const _MissedList({required this.missed});

  final ExamResult missed;

  @override
  Widget build(BuildContext context) {
    final parts = missed.missed;
    if (parts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Text(
          AppText.examAllCorrect,
          style: AppStyle.body(14, color: AppColors.correct, weight: FontWeight.w800),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 200.h),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: parts.length,
        separatorBuilder: (_, _) => SizedBox(height: 6.h),
        itemBuilder: (context, i) {
          final part = parts[i];
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(14.r)),
            child: Row(
              children: [
                IconBubble(icon: part.system.icon, color: part.system.color, size: 32),
                SizedBox(width: 10.w),
                Expanded(
                  child: PartName(vi: part.displayName, en: part.name, style: AppStyle.title(15), englishSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
