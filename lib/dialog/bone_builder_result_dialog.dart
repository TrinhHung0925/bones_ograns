import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/anatomy_viewer/viewer_bridge.dart';
import '../common/game_widgets.dart';
import '../common/star_row.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';

enum BoneBuilderResultAction { edit, playAgain }

/// Score of a creative bone builder test: the stiffness score against the
/// anatomical 100, stars, the test stats and what to do next.
class BoneBuilderResultDialog extends StatelessWidget {
  const BoneBuilderResultDialog({
    super.key,
    required this.result,
    required this.stars,
    required this.xp,
    required this.isNewBest,
    this.previousBest,
  });

  final BuilderResult result;
  final int stars;
  final int xp;
  final bool isNewBest;
  final int? previousBest;

  static Future<BoneBuilderResultAction> show({
    required BuilderResult result,
    required int stars,
    required int xp,
    required bool isNewBest,
    int? previousBest,
  }) async {
    final action = await Get.dialog<BoneBuilderResultAction>(
      BoneBuilderResultDialog(
        result: result,
        stars: stars,
        xp: xp,
        isNewBest: isNewBest,
        previousBest: previousBest,
      ),
      barrierDismissible: false,
    );
    return action ?? BoneBuilderResultAction.edit;
  }

  @override
  Widget build(BuildContext context) {
    final height = (result.heightKept.clamp(0, 1) * 100).round();
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.r),
        side: BorderSide(color: AppColors.border, width: 1.5.r),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppText.builderResultTitle, style: AppStyle.display(26), textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            StarRow(stars: stars, size: 48, animate: true),
            SizedBox(height: 8.h),
            _ScoreBanner(score: result.score),
            SizedBox(height: 6.h),
            SizedBox(
              height: 26.r,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isNewBest) ...[
                    StatPill(
                      text: AppText.builderNewBest,
                      icon: Icons.emoji_events_rounded,
                      iconColor: AppColors.onAccent,
                      background: AppColors.accentDepth,
                    ),
                    SizedBox(width: 6.w),
                  ],
                  if (xp > 0)
                    StatPill(
                      text: AppText.builderXp(xp),
                      icon: Icons.bolt_rounded,
                      iconColor: AppColors.accent,
                      background: AppColors.primaryDepth,
                    ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            _StatRow(icon: Icons.height_rounded, label: AppText.builderHeightKept, value: '$height%'),
            _StatRow(
              icon: Icons.link_rounded,
              label: AppText.builderJointsKept,
              value: '${result.jointsKept}/${result.jointsTotal}',
            ),
            _StatRow(icon: Icons.extension_rounded, label: AppText.builderPiecesUsed, value: '${result.piecesUsed}'),
            _StatRow(
              icon: result.stable ? Icons.check_circle_rounded : Icons.cancel_rounded,
              label: AppText.builderStable,
              value: result.stable ? AppText.builderStableYes : AppText.builderStableNo,
              color: result.stable ? AppColors.correct : AppColors.wrong,
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: AppText.builderEdit,
                    icon: Icons.construction_rounded,
                    tone: GameTone.primary,
                    onTap: () => Get.back(result: BoneBuilderResultAction.edit),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _ActionButton(
                    label: AppText.builderPlayAgain,
                    icon: Icons.replay_rounded,
                    onTap: () => Get.back(result: BoneBuilderResultAction.playAgain),
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

/// The score counting up, with the anatomical reference under it.
class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final beat = score >= 100;
    return GameButton(
      tone: beat ? GameTone.accent : GameTone.primary,
      fadeWhenDisabled: false,
      radius: 20,
      depth: 5,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: score),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '$value',
                style: AppStyle.display(52, color: beat ? AppColors.onAccent : AppColors.textPrimary),
              ),
            ),
            Text(
              AppText.builderVsAnatomical,
              style: AppStyle.body(
                13,
                color: (beat ? AppColors.onAccent : AppColors.textPrimary).withValues(alpha: 0.8),
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value, this.color = AppColors.textSecondary});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38.r,
      margin: EdgeInsets.only(bottom: 6.r),
      padding: EdgeInsets.symmetric(horizontal: 12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18.r, color: color),
          SizedBox(width: 8.r),
          Expanded(
            child: Text(label, style: AppStyle.body(13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: AppStyle.title(16)),
        ],
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
