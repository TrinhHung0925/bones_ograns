import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/game_widgets.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import '../utils/quiz_session.dart';

/// End-of-quiz summary; resolves to true when the user wants to play again.
class QuizResultDialog extends StatelessWidget {
  const QuizResultDialog({
    super.key,
    required this.score,
    required this.total,
    required this.best,
    required this.isNewBest,
  });

  final int score;
  final int total;
  final int best;
  final bool isNewBest;

  static Future<bool> show({required int score, required int total, required int best, required bool isNewBest}) async {
    final again = await Get.dialog<bool>(
      QuizResultDialog(score: score, total: total, best: best, isNewBest: isNewBest),
      barrierDismissible: false,
      barrierColor: AppColors.surfaceDepth.withValues(alpha: 0.75),
    );
    return again ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final stars = QuizSession.starsFor(score, total);
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
            SectionLabel(AppText.quizResult),
            _Stars(filled: stars),
            SizedBox(height: 10.h),
            Text('$score/$total', style: AppStyle.display(56)),
            SizedBox(height: 4.h),
            Text(AppText.quizResultBody(score, total), textAlign: TextAlign.center, style: AppStyle.body(14)),
            SizedBox(height: 12.h),
            isNewBest
                ? const StatPill(
                    text: AppText.quizNewBest,
                    icon: Icons.emoji_events_rounded,
                    iconColor: AppColors.accent,
                  )
                : StatPill(text: AppText.quizBest(best), icon: Icons.emoji_events_outlined),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                tone: GameTone.accent,
                onTap: () => Get.back(result: true),
                radius: 20,
                depth: 6,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_rounded, color: AppColors.onAccent, size: 24.r),
                    SizedBox(width: 8.w),
                    Text(AppText.quizAgain, style: AppStyle.button(19, color: AppColors.onAccent)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                tone: GameTone.raised,
                onTap: () => Get.back(result: false),
                radius: 20,
                padding: EdgeInsets.symmetric(vertical: 13.h),
                child: Center(child: Text(AppText.quizExit, style: AppStyle.button(17))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three stars, the middle one raised and larger, like a level result.
class _Stars extends StatelessWidget {
  const _Stars({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    Widget star(int i, double size) => Icon(
      Icons.star_rounded,
      size: size.r,
      color: i < filled ? AppColors.star : AppColors.surfaceRaised,
      shadows: i < filled ? [Shadow(color: AppColors.accentDepth, offset: Offset(0, 3.h))] : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: star(0, 54),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 18.h),
          child: star(1, 72),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: star(2, 54),
        ),
      ],
    );
  }
}
