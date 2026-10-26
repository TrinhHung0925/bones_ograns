import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/game_widgets.dart';
import '../../common/loading_chip.dart';
import '../../common/part_name.dart';
import '../../model/anatomy_part.dart';
import '../../model/body_system.dart';
import '../../model/part_state.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'home_controller.dart';

class HomeView extends StatefulWidget {
  HomeView({super.key}) {
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }
  }

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  var controller = Get.find<HomeController>();

  @override
  void dispose() {
    Get.delete<HomeController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GameHeader(
              title: AppText.appName,
              subtitle: AppText.appTagline,
              actions: [
                GameIconButton(
                  icon: Icons.search_rounded,
                  tooltip: AppText.search,
                  onTap: controller.openSearch,
                  size: 42,
                ),
                GameIconButton(
                  icon: Icons.settings_rounded,
                  tooltip: AppText.settings,
                  onTap: controller.openSettings,
                  size: 42,
                ),
                GameIconButton(
                  icon: Icons.info_outline_rounded,
                  tooltip: AppText.info,
                  onTap: controller.openAbout,
                  size: 42,
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: StageFrame(child: _Stage(controller: controller)),
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: const Align(alignment: Alignment.centerLeft, child: SectionLabel(AppText.bodySystems)),
            ),
            _SystemTiles(controller: controller),
            SizedBox(height: 12.h),
            _ActionPanel(controller: controller),
          ],
        ),
      ),
    );
  }
}

/// The 3D viewer with its overlays: stats, camera tools and the part card.
class _Stage extends StatelessWidget {
  const _Stage({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Overlays may build a SizedBox.shrink; without expand the Stack would
      // shrink to it and the WebView would vanish.
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
        Positioned(
          top: 12.h,
          left: 12.w,
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const StatPill(text: AppText.live3d, dotColor: AppColors.correct),
                    SizedBox(width: 6.w),
                    StatPill(
                      text: AppText.partCount(controller.visiblePartCount),
                      icon: Icons.layers_rounded,
                      iconColor: AppColors.accent,
                    ),
                  ],
                ),
                if (controller.isLoading) ...[SizedBox(height: 6.h), const LoadingChip()],
              ],
            ),
          ),
        ),
        Positioned(
          top: 12.h,
          right: 12.w,
          child: Obx(
            () => Column(
              children: [
                GameIconButton(
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: AppText.resetCamera,
                  onTap: controller.resetCamera,
                  size: 40,
                ),
                if (controller.partStates.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  GameIconButton(
                    icon: Icons.visibility_rounded,
                    tooltip: AppText.showAll,
                    onTap: controller.showAll,
                    tone: GameTone.primary,
                    size: 40,
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 64.h,
          left: 12.w,
          right: 64.w,
          child: Obx(() {
            final error = controller.error.value;
            return error == null ? const SizedBox.shrink() : _ErrorBanner(message: error);
          }),
        ),
        Positioned(
          left: 10.w,
          right: 10.w,
          bottom: 10.h,
          child: Obx(() {
            final part = controller.selected.value;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: part == null
                  ? const SizedBox.shrink()
                  : _PartCard(key: ValueKey(part.id), part: part, controller: controller),
            );
          }),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.wrong, width: 1.5.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.wrong, size: 20.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(message, style: AppStyle.body(13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Name and actions for the selected part.
class _PartCard extends StatelessWidget {
  const _PartCard({super.key, required this.part, required this.controller});

  final AnatomyPart part;
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: part.system.icon, color: part.system.color, size: 30),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(part.system.label.toUpperCase(), style: AppStyle.label(color: part.system.color)),
              ),
              GameIconButton(
                icon: Icons.close_rounded,
                tooltip: AppText.close,
                onTap: controller.clearSelection,
                tone: GameTone.raised,
                size: 34,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: PartName(vi: part.displayName, en: part.name, style: AppStyle.display(24)),
              ),
              SizedBox(width: 8.w),
              GameIconButton(
                icon: Icons.volume_up_rounded,
                tooltip: AppText.pronounce,
                onTap: controller.speakSelected,
                tone: GameTone.primary,
                size: 40,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Obx(() {
            final ghosted = controller.stateOf(part.id) == PartState.ghost;
            return Row(
              children: [
                _ActionTile(icon: Icons.zoom_in_rounded, label: AppText.zoomIn, onTap: controller.focusSelected),
                SizedBox(width: 8.w),
                _ActionTile(icon: Icons.visibility_off_rounded, label: AppText.hide, onTap: controller.hideSelected),
                SizedBox(width: 8.w),
                _ActionTile(
                  icon: Icons.opacity_rounded,
                  label: ghosted ? AppText.unghost : AppText.ghost,
                  selected: ghosted,
                  onTap: controller.toggleGhostSelected,
                ),
                SizedBox(width: 8.w),
                _ActionTile(
                  icon: Icons.filter_center_focus_rounded,
                  label: AppText.isolate,
                  onTap: controller.isolateSelected,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GameButton(
        tone: GameTone.raised,
        selected: selected,
        onTap: onTap,
        radius: 16,
        depth: 4,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          children: [
            Icon(icon, size: 22.r, color: AppColors.textPrimary),
            SizedBox(height: 3.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.body(12, color: AppColors.textPrimary, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal row of body system tiles; the outlined ones are drawn.
class _SystemTiles extends StatelessWidget {
  const _SystemTiles({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final systems = controller.systems;
    return SizedBox(
      height: 98.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: systems.length,
        separatorBuilder: (_, _) => SizedBox(width: 10.w),
        itemBuilder: (context, i) => Obx(
          () => _SystemTile(
            system: systems[i],
            visible: controller.visibleSystems.contains(systems[i]),
            loading: controller.loadingSystems.contains(systems[i]),
            onTap: () => controller.toggleSystem(systems[i]),
          ),
        ),
      ),
    );
  }
}

class _SystemTile extends StatelessWidget {
  const _SystemTile({required this.system, required this.visible, required this.loading, required this.onTap});

  final BodySystem system;
  final bool visible;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: GameButton(
        selected: visible,
        onTap: onTap,
        radius: 18,
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: SizedBox(
          width: 76.w,
          child: Column(
            children: [
              if (loading)
                SizedBox.square(
                  dimension: 40.r,
                  child: Padding(
                    padding: EdgeInsets.all(8.r),
                    child: CircularProgressIndicator(strokeWidth: 3, color: system.color),
                  ),
                )
              else
                IconBubble(icon: system.icon, color: system.color, size: 40),
              SizedBox(height: 6.h),
              Text(
                system.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.body(
                  13,
                  color: visible ? AppColors.textPrimary : AppColors.textSecondary,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom panel with the two game modes.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GameButton(
                  tone: GameTone.accent,
                  onTap: controller.openAssembly,
                  radius: 20,
                  depth: 6,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.extension_rounded, color: AppColors.onAccent, size: 24.r),
                      SizedBox(width: 8.w),
                      Text(AppText.assembly, style: AppStyle.button(18, color: AppColors.onAccent)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: GameButton(
                  tone: GameTone.primary,
                  onTap: controller.openQuiz,
                  tooltip: AppText.quiz,
                  radius: 20,
                  depth: 6,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_rounded, color: AppColors.textPrimary, size: 22.r),
                      SizedBox(width: 6.w),
                      Text(AppText.quizShort, style: AppStyle.button(18)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(AppText.viewerHint, style: AppStyle.body(12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
