import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/game_widgets.dart';
import '../common/star_row.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import '../utils/assembly_score.dart';

enum AssemblyResultAction { next, replay, list }

/// End-of-level summary for the assembly game.
class AssemblyResultDialog extends StatelessWidget {
  const AssemblyResultDialog({
    super.key,
    required this.stars,
    required this.time,
    required this.mistakes,
    required this.hints,
    required this.isRecord,
    required this.hasNext,
    this.score = 0,
    this.timeBonus = 0,
    this.maxCombo = 0,
    this.isBestScore = false,
  });

  final int stars;
  final Duration time;
  final int mistakes;
  final int hints;
  final bool isRecord;
  final bool hasNext;
  final int score;
  final int timeBonus;
  final int maxCombo;
  final bool isBestScore;

  static Future<AssemblyResultAction> show({
    required int stars,
    required Duration time,
    required int mistakes,
    required int hints,
    required bool isRecord,
    required bool hasNext,
    int score = 0,
    int timeBonus = 0,
    int maxCombo = 0,
    bool isBestScore = false,
  }) async {
    final action = await Get.dialog<AssemblyResultAction>(
      AssemblyResultDialog(
        stars: stars,
        time: time,
        mistakes: mistakes,
        hints: hints,
        isRecord: isRecord,
        hasNext: hasNext,
        score: score,
        timeBonus: timeBonus,
        maxCombo: maxCombo,
        isBestScore: isBestScore,
      ),
      barrierDismissible: false,
    );
    return action ?? AssemblyResultAction.list;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.r),
        side: BorderSide(color: AppColors.border, width: 1.5.r),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppText.assemblyComplete, style: AppStyle.display(30)),
            SizedBox(height: 10.h),
            StarRow(stars: stars, size: 52, animate: true),
            SizedBox(height: 10.h),
            _ScoreBanner(score: score, timeBonus: timeBonus, maxCombo: maxCombo),
            SizedBox(height: 6.h),
            SizedBox(
              height: 22.h,
              child: isBestScore || isRecord
                  ? Text(
                      isBestScore ? AppText.assemblyNewBestScore : AppText.assemblyNewRecord,
                      style: AppStyle.body(14, color: AppColors.accent, weight: FontWeight.w800),
                    )
                  : null,
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _Stat(icon: Icons.timer_outlined, label: AppText.assemblyTime, value: formatClock(time)),
                SizedBox(width: 8.w),
                _Stat(
                  icon: Icons.close_rounded,
                  label: AppText.assemblyMistakes,
                  value: '$mistakes',
                  color: AppColors.wrong,
                ),
                SizedBox(width: 8.w),
                _Stat(
                  icon: Icons.lightbulb_outline_rounded,
                  label: AppText.assemblyHints,
                  value: '$hints',
                  color: AppColors.accent,
                ),
              ],
            ),
            SizedBox(height: 20.h),
            if (hasNext) ...[
              _ActionButton(
                label: AppText.assemblyNext,
                icon: Icons.arrow_forward_rounded,
                tone: GameTone.primary,
                onTap: () => Get.back(result: AssemblyResultAction.next),
              ),
              SizedBox(height: 10.h),
            ],
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: AppText.assemblyReplay,
                    icon: Icons.replay_rounded,
                    tone: hasNext ? GameTone.surface : GameTone.primary,
                    onTap: () => Get.back(result: AssemblyResultAction.replay),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _ActionButton(
                    label: AppText.assemblyToList,
                    icon: Icons.grid_view_rounded,
                    onTap: () => Get.back(result: AssemblyResultAction.list),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Total score counting up, with the time bonus and best combo under it.
class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.score, required this.timeBonus, required this.maxCombo});

  final int score;
  final int timeBonus;
  final int maxCombo;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: GameTone.primary,
      fadeWhenDisabled: false,
      radius: 18,
      depth: 5,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.accent, size: 28.r),
              SizedBox(width: 6.w),
              Text(
                AppText.assemblyScore,
                style: AppStyle.body(14, color: AppColors.textPrimary, weight: FontWeight.w800),
              ),
              const Spacer(),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: score),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text('$value', style: AppStyle.display(28)),
              ),
            ],
          ),
          if (_bonusText.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _bonusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.body(11, color: AppColors.textPrimary.withValues(alpha: 0.75)),
              ),
            ),
        ],
      ),
    );
  }

  String get _bonusText => [
    if (timeBonus > 0) '${AppText.assemblyTimeBonus} +$timeBonus',
    if (maxCombo >= 2) '${AppText.assemblyMaxCombo} x$maxCombo',
  ].join(' · ');
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, this.color = AppColors.textSecondary});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceDepth.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18.r, color: color),
            SizedBox(height: 2.h),
            Text(value, style: AppStyle.display(20)),
            Text(label, style: AppStyle.body(11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap, this.tone = GameTone.surface});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final GameTone tone;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: tone,
      onTap: onTap,
      radius: 18,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20.r, color: AppColors.textPrimary),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(label, style: AppStyle.button(16), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
