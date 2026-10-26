import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/assembly_tutorial.dart';
import '../../common/game_widgets.dart';
import '../../common/loading_chip.dart';
import '../../common/part_name.dart';
import '../../common/star_row.dart';
import '../../model/assembly_level.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import '../../utils/assembly_score.dart';
import 'assembly_controller.dart';

class AssemblyView extends StatefulWidget {
  AssemblyView({super.key}) {
    if (!Get.isRegistered<AssemblyController>()) {
      Get.put(AssemblyController());
    }
  }

  @override
  State<AssemblyView> createState() => _AssemblyViewState();
}

class _AssemblyViewState extends State<AssemblyView> {
  var controller = Get.find<AssemblyController>();

  @override
  void dispose() {
    Get.delete<AssemblyController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // The tutorial builder may return a SizedBox.shrink; expand keeps the
        // game (and its WebView) full size.
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                GetBuilder<AssemblyController>(
                  builder: (controller) => GameHeader(
                    title: controller.level.title,
                    subtitle:
                        '${controller.level.difficulty.label} · '
                        '${AppText.assemblyPieces(controller.pieces.length)}',
                    onBack: controller.onBack,
                    actions: [
                      GameIconButton(
                        icon: Icons.question_mark_rounded,
                        tooltip: AppText.assemblyHelp,
                        onTap: controller.openTutorial,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                  child: GetBuilder<AssemblyController>(builder: (controller) => _Hud(controller: controller)),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: StageFrame(child: _Stage(controller: controller)),
                  ),
                ),
                SizedBox(height: 12.h),
                BottomPanel(
                  child: GetBuilder<AssemblyController>(
                    builder: (controller) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NameBanner(controller: controller),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: _PanelButton(
                                label: AppText.assemblyHintCount(controller.hints),
                                icon: Icons.lightbulb_rounded,
                                tone: GameTone.accent,
                                onTap: controller.loading || controller.finished ? null : controller.hint,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: _PanelButton(
                                label: AppText.assemblyRestart,
                                icon: Icons.replay_rounded,
                                tone: GameTone.surface,
                                onTap: controller.loading ? null : controller.restart,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          GetBuilder<AssemblyController>(
            builder: (controller) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: controller.showTutorial
                  ? AssemblyTutorial(key: const ValueKey('tutorial'), onStart: controller.closeTutorial)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clock, placed pieces, mistakes, score and a progress bar.
class _Hud extends StatelessWidget {
  const _Hud({required this.controller});

  final AssemblyController controller;

  @override
  Widget build(BuildContext context) {
    final progress = controller.pieces.isEmpty ? 0.0 : controller.placed / controller.pieces.length;
    return Column(
      children: [
        Row(
          children: [
            GetBuilder<AssemblyController>(
              id: AssemblyController.clockId,
              builder: (controller) => StatPill(
                icon: Icons.timer_outlined,
                iconColor: AppColors.accent,
                text: formatClock(controller.elapsed),
              ),
            ),
            SizedBox(width: 6.w),
            StatPill(
              icon: Icons.extension_rounded,
              iconColor: AppColors.correct,
              text: '${controller.placed}/${controller.pieces.length}',
            ),
            SizedBox(width: 6.w),
            StatPill(icon: Icons.close_rounded, iconColor: AppColors.wrong, text: '${controller.mistakes}'),
            const Spacer(),
            _ScorePill(score: controller.score),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          height: 8.h,
          decoration: BoxDecoration(color: AppColors.surfaceDepth, borderRadius: BorderRadius.circular(999)),
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(color: AppColors.correct, borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Score pill that pops when the score changes.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(score),
      tween: Tween(begin: 1.2, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: StatPill(
        icon: Icons.bolt_rounded,
        iconColor: AppColors.accent,
        background: AppColors.primaryDepth,
        text: '$score',
      ),
    );
  }
}

/// The 3D viewer with the loading chip, combo badge and level intro card.
class _Stage extends StatelessWidget {
  const _Stage({required this.controller});

  final AssemblyController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Overlay builders return non-positioned SizedBoxes; without expand the
      // Stack (and the WebView) shrinks to 0x0.
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
        GetBuilder<AssemblyController>(
          builder: (controller) => controller.loading && !controller.showIntro
              ? Positioned(
                  top: 12.h,
                  left: 0,
                  right: 0,
                  child: const Center(child: LoadingChip()),
                )
              : const SizedBox.shrink(),
        ),
        Positioned(
          top: 14.h,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: GetBuilder<AssemblyController>(
              id: AssemblyController.comboId,
              builder: (controller) => Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.elasticOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: controller.combo >= 2
                      ? _ComboBadge(key: ValueKey(controller.comboTick), count: controller.combo)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        GetBuilder<AssemblyController>(
          builder: (controller) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
            ),
            child: controller.showIntro
                ? _IntroCard(key: ValueKey(controller.level.id), controller: controller)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: GameButton(
        tone: GameTone.accent,
        fadeWhenDisabled: false,
        radius: 18,
        depth: 5,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, color: AppColors.wrong, size: 24.r),
            SizedBox(width: 6.w),
            Text(AppText.assemblyCombo(count), style: AppStyle.display(24, color: AppColors.onAccent)),
            SizedBox(width: 6.w),
            Text(
              AppText.assemblyComboBonus(assemblyComboBonus(count)),
              style: AppStyle.body(14, color: AppColors.onAccent, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card shown when a level starts: title, pieces, difficulty and best record.
/// Dismissed on tap or after a few seconds.
class _IntroCard extends StatelessWidget {
  const _IntroCard({super.key, required this.controller});

  final AssemblyController controller;

  Color get _difficultyColor => switch (controller.level.difficulty) {
    AssemblyDifficulty.easy => AppColors.correct,
    AssemblyDifficulty.medium => AppColors.accent,
    AssemblyDifficulty.hard || AssemblyDifficulty.extreme => AppColors.wrong,
  };

  @override
  Widget build(BuildContext context) {
    final level = controller.level;
    final stars = controller.bestStars;
    final seconds = controller.bestSeconds;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.dismissIntro,
      child: ColoredBox(
        color: AppColors.surfaceDepth.withValues(alpha: 0.55),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: GameButton(
              tone: GameTone.primary,
              fadeWhenDisabled: false,
              radius: 26,
              depth: 6,
              padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconBubble(icon: level.icon, color: AppColors.textPrimary, size: 56),
                  SizedBox(height: 8.h),
                  Text(
                    level.chapter.title.toUpperCase(),
                    style: AppStyle.label(color: AppColors.textPrimary.withValues(alpha: 0.7)),
                  ),
                  SizedBox(height: 4.h),
                  Text(level.title, style: AppStyle.display(30), textAlign: TextAlign.center),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    alignment: WrapAlignment.center,
                    children: [
                      StatPill(
                        icon: Icons.extension_rounded,
                        iconColor: AppColors.correct,
                        text: AppText.assemblyPieces(controller.pieces.length),
                      ),
                      StatPill(text: level.difficulty.label, dotColor: _difficultyColor),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  if (stars > 0 && seconds != null) ...[
                    StarRow(stars: stars, size: 22),
                    SizedBox(height: 4.h),
                    Text(
                      '${AppText.assemblyIntroBest}: '
                      '${AppText.assemblyIntroRecord(stars, formatClock(Duration(seconds: seconds)), controller.bestScore)}',
                      style: AppStyle.body(13, color: AppColors.textPrimary, weight: FontWeight.w700),
                    ),
                  ] else
                    Text(
                      AppText.assemblyIntroNoRecord,
                      style: AppStyle.body(13, color: AppColors.textPrimary, weight: FontWeight.w700),
                    ),
                  SizedBox(height: 10.h),
                  Text(
                    AppText.assemblyIntroTapHint,
                    style: AppStyle.body(12, color: AppColors.textPrimary.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Name of the grabbed/hinted piece, Vietnamese first and English below, with
/// a speak button (English); an instruction until something is picked up.
class _NameBanner extends StatelessWidget {
  const _NameBanner({required this.controller});

  final AssemblyController controller;

  @override
  Widget build(BuildContext context) {
    final piece = controller.focused;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: SizedBox(
        key: ValueKey('${piece?.id}-${controller.focusedByHint}'),
        height: 52.h,
        child: piece == null
            ? Row(
                children: [
                  IconBubble(icon: Icons.pan_tool_alt_rounded, color: AppColors.primary, size: 40),
                  SizedBox(width: 10.w),
                  Expanded(child: Text(AppText.assemblyDragHint, style: AppStyle.body(14), maxLines: 2)),
                ],
              )
            : Row(
                children: [
                  controller.focusedByHint
                      ? IconBubble(icon: Icons.lightbulb_rounded, color: AppColors.accent, size: 40)
                      : IconBubble(icon: piece.system.icon, color: piece.system.color, size: 40),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: PartName(
                      vi: piece.nameVi,
                      en: piece.nameEn,
                      style: AppStyle.title(17),
                      englishSize: 12,
                      maxLines: 1,
                    ),
                  ),
                  GameIconButton(
                    icon: Icons.volume_up_rounded,
                    tooltip: AppText.pronounce,
                    size: 40,
                    onTap: controller.speakFocused,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.label, required this.icon, required this.tone, required this.onTap});

  final String label;
  final IconData icon;
  final GameTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tone == GameTone.accent ? AppColors.onAccent : AppColors.textPrimary;
    return GameButton(
      tone: tone,
      onTap: onTap,
      radius: 18,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20.r, color: color),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              label,
              style: AppStyle.button(17, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
