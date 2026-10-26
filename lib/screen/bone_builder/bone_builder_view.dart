import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/game_widgets.dart';
import '../../common/model_loading.dart';
import '../../common/view_controls.dart';
import '../../model/body_system.dart';
import '../../model/bone_builder.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'bone_builder_controller.dart';

class BoneBuilderView extends StatefulWidget {
  BoneBuilderView({super.key}) {
    if (!Get.isRegistered<BoneBuilderController>()) {
      Get.put(BoneBuilderController());
    }
  }

  @override
  State<BoneBuilderView> createState() => _BoneBuilderViewState();
}

class _BoneBuilderViewState extends State<BoneBuilderView> {
  var controller = Get.find<BoneBuilderController>();

  @override
  void dispose() {
    Get.delete<BoneBuilderController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Immersive layout like the assembly game: the 3D stage fills the screen
    // and compact controls float over it.
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Stage(controller: controller),
          const _Scrim(top: true),
          const _Scrim(top: false),
          // Blocks taps on the stage while the physics test runs.
          GetBuilder<BoneBuilderController>(
            builder: (controller) => controller.testing
                ? const Positioned.fill(child: AbsorbPointer())
                : const SizedBox.shrink(),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _TopBar(controller: controller)),
          Positioned(left: 0, right: 0, bottom: 0, child: _BottomBar(controller: controller)),
          _PhaseBanner(controller: controller),
        ],
      ),
    );
  }
}

/// Darkens the screen edge behind a floating bar; never blocks touches.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    final inset = top ? MediaQuery.paddingOf(context).top : MediaQuery.paddingOf(context).bottom;
    final colors = [AppColors.background.withValues(alpha: 0.88), AppColors.background.withValues(alpha: 0)];
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: inset + (top ? 90 : 150).h,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 3D viewer, the zoom/rotate controls and the loading state.
class _Stage extends StatelessWidget {
  const _Stage({required this.controller});

  final BoneBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The loading builder returns a SizedBox; expand keeps the WebView full size.
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
        Positioned(
          right: 10.w,
          top: 0,
          bottom: 0,
          child: Center(child: ViewControls(bridge: controller.viewer)),
        ),
        GetBuilder<BoneBuilderController>(
          builder: (controller) => controller.loading
              ? Positioned.fill(child: Center(child: ModelLoading(detail: BodySystem.skeletal.label)))
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Back, title, best score and the rules.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final BoneBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
        child: GetBuilder<BoneBuilderController>(
          builder: (controller) => Row(
            children: [
              GameIconButton(icon: Icons.arrow_back_rounded, tooltip: AppText.back, onTap: controller.onBack, size: 38),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  AppText.builderTitle,
                  style: AppStyle.title(19),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6.w),
              StatPill(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.accent,
                background: AppColors.primaryDepth,
                text: AppText.builderBestShort(controller.best),
              ),
              SizedBox(width: 6.w),
              GameIconButton(
                icon: Icons.question_mark_rounded,
                tooltip: AppText.builderHelp,
                onTap: () => _showRules(),
                size: 38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRules() {
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBubble(icon: Icons.construction_rounded, color: AppColors.accent, size: 40),
                  SizedBox(width: 10.w),
                  Expanded(child: Text(AppText.builderHelp, style: AppStyle.title(20))),
                ],
              ),
              SizedBox(height: 12.h),
              Text(AppText.builderRules, style: AppStyle.body(14, color: AppColors.textPrimary)),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: GameButton(
                  tone: GameTone.primary,
                  onTap: Get.back,
                  radius: 18,
                  padding: EdgeInsets.symmetric(vertical: 12.r),
                  child: Center(child: Text(AppText.builderRulesOk, style: AppStyle.button(16))),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

/// Selected-piece chip, the rotate toolbar, edit buttons and the test button.
/// Hidden while loading and during a test.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});

  final BoneBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
        child: GetBuilder<BoneBuilderController>(
          builder: (controller) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: controller.loading || controller.testing
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.selected != null) ...[
                        _RotateToolbar(controller: controller),
                        SizedBox(height: 6.r),
                      ],
                      _PieceChip(controller: controller),
                      SizedBox(height: 6.r),
                      Row(
                        children: [
                          GameIconButton(
                            icon: Icons.undo_rounded,
                            tooltip: AppText.builderUndo,
                            onTap: controller.canUndo ? controller.undo : null,
                            size: 40,
                          ),
                          SizedBox(width: 6.r),
                          GameIconButton(
                            icon: Icons.restart_alt_rounded,
                            tooltip: AppText.builderReset,
                            onTap: controller.reset,
                            size: 40,
                          ),
                          SizedBox(width: 6.r),
                          Expanded(
                            child: _SmallButton(
                              icon: Icons.accessibility_new_rounded,
                              label: AppText.builderAnatomical,
                              onTap: controller.anatomical,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.r),
                      _TestButton(controller: controller),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Name of the selected piece (or how to pick one) and the placed count.
class _PieceChip extends StatelessWidget {
  const _PieceChip({required this.controller});

  final BoneBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final piece = controller.selected;
    return Container(
      height: 40.r,
      padding: EdgeInsets.symmetric(horizontal: 6.r),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: piece == null ? AppColors.border : AppColors.accent),
      ),
      child: Row(
        children: [
          IconBubble(
            icon: piece == null ? Icons.touch_app_rounded : Icons.check_rounded,
            color: piece == null ? AppColors.primary : AppColors.accent,
            size: 30,
          ),
          SizedBox(width: 8.r),
          Expanded(
            child: Text(
              piece?.nameVi ?? AppText.builderPickHint,
              style: piece == null ? AppStyle.body(13) : AppStyle.title(15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StatPill(
            icon: Icons.extension_rounded,
            iconColor: AppColors.correct,
            text: AppText.builderPlaced(controller.placed, controller.pieces.length),
          ),
        ],
      ),
    );
  }
}

/// X / Y / Z rotation of the selected piece and the 15° fine-step toggle.
class _RotateToolbar extends StatelessWidget {
  const _RotateToolbar({required this.controller});

  final BoneBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final axis in const ['x', 'y', 'z']) ...[
            _AxisButton(axis: axis, onTap: () => controller.rotate(axis)),
            SizedBox(width: 6.r),
          ],
          Tooltip(
            message: AppText.builderRotateFine,
            child: GameButton(
              tone: controller.fineStep ? GameTone.accent : GameTone.raised,
              onTap: controller.toggleFineStep,
              radius: 12,
              depth: 3,
              child: SizedBox(
                width: 52.r,
                height: 34.r,
                child: Center(
                  child: Text(
                    controller.fineStep ? AppText.builderFineStep : AppText.builderCoarseStep,
                    style: AppStyle.button(
                      14,
                      color: controller.fineStep ? AppColors.onAccent : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisButton extends StatelessWidget {
  const _AxisButton({required this.axis, required this.onTap});

  final String axis;
  final VoidCallback onTap;

  Color get _color => switch (axis) {
    'x' => AppColors.wrong,
    'y' => AppColors.correct,
    _ => AppColors.sensory,
  };

  @override
  Widget build(BuildContext context) {
    final label = axis.toUpperCase();
    return GameButton(
      tone: GameTone.surface,
      onTap: onTap,
      tooltip: AppText.builderRotateAxis(label),
      radius: 12,
      depth: 3,
      child: SizedBox(
        width: 48.r,
        height: 34.r,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rotate_right_rounded, size: 16.r, color: _color),
            SizedBox(width: 2.r),
            Text(label, style: AppStyle.button(15, color: _color)),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      onTap: onTap,
      radius: 14,
      depth: 4,
      child: SizedBox(
        height: 40.r,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.r, color: AppColors.textPrimary),
            SizedBox(width: 6.r),
            Flexible(
              child: Text(label, style: AppStyle.button(14), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Kiểm tra độ cứng"; disabled until enough pieces are placed.
class _TestButton extends StatelessWidget {
  const _TestButton({required this.controller});

  final BoneBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.canTest;
    return GameButton(
      tone: GameTone.accent,
      onTap: enabled ? controller.runTest : null,
      radius: 18,
      depth: 5,
      child: SizedBox(
        height: 50.r,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 24.r, color: AppColors.onAccent),
            SizedBox(width: 6.r),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppText.builderTest,
                    style: AppStyle.button(18, color: AppColors.onAccent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!enabled)
                    Text(
                      AppText.builderNeedPieces(BoneBuilder.minPlaced),
                      style: AppStyle.body(11, color: AppColors.onAccent, weight: FontWeight.w700),
                      maxLines: 1,
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

/// "Ổn định…", "Động đất!", "Va chạm!" while the test runs.
class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.controller});

  final BoneBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 64.h,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: GetBuilder<BoneBuilderController>(
          builder: (controller) {
            final phase = controller.testing ? controller.phase : null;
            return Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.elasticOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: phase == null ? const SizedBox.shrink() : _PhaseBadge(key: ValueKey(phase), phase: phase),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({super.key, required this.phase});

  final BuilderPhase phase;

  @override
  Widget build(BuildContext context) {
    final (label, icon, tone) = switch (phase) {
      BuilderPhase.settle => (AppText.builderPhaseSettle, Icons.hourglass_top_rounded, GameTone.primary),
      BuilderPhase.quake => (AppText.builderPhaseQuake, Icons.vibration_rounded, GameTone.accent),
      BuilderPhase.impact => (AppText.builderPhaseImpact, Icons.sports_baseball_rounded, GameTone.accent),
    };
    final color = tone == GameTone.accent ? AppColors.onAccent : AppColors.textPrimary;
    return Transform.rotate(
      angle: phase == BuilderPhase.settle ? 0 : -0.05,
      child: GameButton(
        tone: tone,
        fadeWhenDisabled: false,
        radius: 18,
        depth: 5,
        padding: EdgeInsets.symmetric(horizontal: 18.r, vertical: 8.r),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24.r, color: color),
            SizedBox(width: 8.r),
            Text(label, style: AppStyle.display(24, color: color)),
          ],
        ),
      ),
    );
  }
}
