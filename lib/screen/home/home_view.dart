import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../common/model_loading.dart';
import '../../common/view_controls.dart';
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
import '../../service/progress_service.dart';
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
    // Immersive layout, like the assembly game: the 3D stage fills the whole
    // screen and the header, tiles and actions float over it.
    return Scaffold(
      body: Stack(
        // Builders may return a SizedBox.shrink; expand keeps the stage (and
        // its WebView) full size.
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
          Positioned.fill(
            child: Obx(
              () => controller.isFirstLoad
                  ? Center(child: ModelLoading(detail: controller.loadingLabel))
                  : const SizedBox.shrink(),
            ),
          ),
          const _Scrim(top: true),
          const _Scrim(top: false),
          // Nothing in this layer paints a background over the empty middle,
          // so drags and taps there fall through to the WebView.
          Positioned.fill(
            child: SafeArea(
              bottom:false,
              child: Column(
                children: [
                  _TopBar(controller: controller),
                  // Centred on the right edge, between the floating bars, so the
                  // part card can never cover them.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 10.w),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _ViewerTools(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  _BottomBar(controller: controller),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darkens the screen edge behind a floating bar so its text stays readable;
/// never blocks touches on the stage.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    final inset = top ? MediaQuery.paddingOf(context).top : MediaQuery.paddingOf(context).bottom;
    final colors = [AppColors.background.withValues(alpha: 0.9), AppColors.background.withValues(alpha: 0)];
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: inset + (top ? 130 : 250).h,
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

/// Brand, title and actions, then the stat pills and any error.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandTile(size: 38),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppText.appName, style: AppStyle.display(20), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(AppText.appTagline, style: AppStyle.body(12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GameIconButton(
                icon: Icons.search_rounded,
                tooltip: AppText.search,
                onTap: controller.openSearch,
                size: 36,
              ),
              SizedBox(width: 6.w),
              GameIconButton(
                icon: Icons.settings_rounded,
                tooltip: AppText.settings,
                onTap: controller.openSettings,
                size: 36,
              ),
              SizedBox(width: 6.w),
              GameIconButton(
                icon: Icons.info_outline_rounded,
                tooltip: AppText.info,
                onTap: controller.openAbout,
                size: 36,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
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
                // Later loads (another system switched on) keep the model visible.
                if (controller.isLoading && !controller.isFirstLoad) ...[SizedBox(height: 6.h), const LoadingChip()],
                if (controller.error.value != null) ...[
                  SizedBox(height: 8.h),
                  _ErrorBanner(message: controller.error.value!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera tools on the right edge: drag mode, zoom, reset and show all.
class _ViewerTools extends StatelessWidget {
  const _ViewerTools({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ViewControls(bridge: controller.viewer, size: 36),
          SizedBox(height: 8.h),
          GameIconButton(
            icon: Icons.center_focus_strong_rounded,
            tooltip: AppText.resetCamera,
            onTap: controller.resetCamera,
            size: 36,
          ),
          if (controller.partStates.isNotEmpty) ...[
            SizedBox(height: 8.h),
            GameIconButton(
              icon: Icons.visibility_rounded,
              tooltip: AppText.showAll,
              onTap: controller.showAll,
              tone: GameTone.primary,
              size: 36,
            ),
          ],
        ],
      ),
    );
  }
}

/// Selected part card, then the system tiles and the game modes.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 8.h),
      margin: EdgeInsets.only(bottom: 8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sits right above the tiles; the bar grows upwards into the stage,
          // so the card never covers them.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
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
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        key: ValueKey(part.id),
                        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
                        child: _PartCard(part: part, controller: controller),
                      ),
              );
            }),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: const SectionLabel(AppText.bodySystems),
          ),
          _SystemTiles(controller: controller),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: _ActionPanel(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.wrong, width: 1.5.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.wrong, size: 18.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(message, style: AppStyle.body(12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Name and actions for the selected part.
class _PartCard extends StatelessWidget {
  const _PartCard({required this.part, required this.controller});

  final AnatomyPart part;
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      radius: 18,
      depth: 4,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 10.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: part.system.icon, color: part.system.color, size: 34),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.system.label.toUpperCase(),
                      style: AppStyle.label(color: part.system.color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    PartName(
                      vi: part.displayName,
                      en: part.name,
                      style: AppStyle.display(18),
                      englishSize: 11,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              GameIconButton(
                icon: Icons.volume_up_rounded,
                tooltip: AppText.pronounce,
                onTap: controller.speakSelected,
                tone: GameTone.primary,
                size: 34,
              ),
              SizedBox(width: 6.w),
              GameIconButton(
                icon: Icons.close_rounded,
                tooltip: AppText.close,
                onTap: controller.clearSelection,
                tone: GameTone.raised,
                size: 30,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Obx(() {
            final ghosted = controller.stateOf(part.id) == PartState.ghost;
            return Row(
              children: [
                _ActionTile(icon: Icons.zoom_in_rounded, label: AppText.zoomIn, onTap: controller.focusSelected),
                SizedBox(width: 6.w),
                _ActionTile(icon: Icons.visibility_off_rounded, label: AppText.hide, onTap: controller.hideSelected),
                SizedBox(width: 6.w),
                _ActionTile(
                  icon: Icons.opacity_rounded,
                  label: ghosted ? AppText.unghost : AppText.ghost,
                  selected: ghosted,
                  onTap: controller.toggleGhostSelected,
                ),
                SizedBox(width: 6.w),
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
        radius: 12,
        depth: 3,
        padding: EdgeInsets.symmetric(vertical: 5.h),
        child: Column(
          children: [
            Icon(icon, size: 17.r, color: AppColors.textPrimary),
            SizedBox(height: 2.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.body(11, color: AppColors.textPrimary, weight: FontWeight.w800),
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
    // Sized in .r like the tiles: mixing .h with the tiles' .r overflowed
    // on phones whose height ratio is below their width ratio.
    return SizedBox(
      height: 68.r,
      child: ListView.separated(
        controller: controller.tileScroll,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: systems.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, i) => AutoScrollTag(
          key: ValueKey(systems[i]),
          controller: controller.tileScroll,
          index: i,
          child: Obx(
            () => _SystemTile(
              system: systems[i],
              visible: controller.visibleSystems.contains(systems[i]),
              loading: controller.loadingSystems.contains(systems[i]),
              onTap: () => controller.toggleSystem(systems[i]),
            ),
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
        radius: 14,
        depth: 4,
        padding: EdgeInsets.symmetric(horizontal: 4.r, vertical: 5.r),
        child: SizedBox(
          width: 56.r,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox.square(
                  dimension: 28.r,
                  child: Padding(
                    padding: EdgeInsets.all(6.r),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: system.color),
                  ),
                )
              else
                IconBubble(icon: system.icon, color: system.color, size: 28),
              SizedBox(height: 3.r),
              // Longer names ("Khớp & sụn") shrink instead of being cut off.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  system.label,
                  maxLines: 1,
                  style: AppStyle.body(
                    11.5,
                    color: visible ? AppColors.textPrimary : AppColors.textSecondary,
                    weight: FontWeight.w800,
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

/// Floating panel with the game and learning modes.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 6.h),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _ModeButton(
                  label: AppText.assembly,
                  icon: Icons.extension_rounded,
                  tone: GameTone.accent,
                  onTap: controller.openAssembly,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                flex: 3,
                child: _ModeButton(
                  label: AppText.learnShort,
                  icon: Icons.school_rounded,
                  tone: GameTone.primary,
                  onTap: controller.openLearn,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                flex: 3,
                child: _ModeButton(
                  label: AppText.quizShort,
                  icon: Icons.quiz_rounded,
                  tone: GameTone.raised,
                  tooltip: AppText.quiz,
                  onTap: controller.openQuiz,
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppText.viewerHint,
                  style: AppStyle.body(11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Small profile hint: level and streak.
              Obx(
                () => Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: AppText.learnLevel(ProgressService.levelFor(controller.progress.xp.value))),
                      const TextSpan(text: ' · '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(Icons.local_fire_department_rounded, size: 13.r, color: AppColors.accent),
                      ),
                      TextSpan(text: '${controller.progress.streak.value}'),
                    ],
                  ),
                  style: AppStyle.body(11, color: AppColors.textSecondary, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact mode button of the action panel; long labels shrink to fit.
class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.icon, required this.tone, required this.onTap, this.tooltip});

  final String label;
  final IconData icon;
  final GameTone tone;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = tone == GameTone.accent ? AppColors.onAccent : AppColors.textPrimary;
    return GameButton(
      tone: tone,
      onTap: onTap,
      tooltip: tooltip,
      radius: 16,
      depth: 4,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 10.h),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17.r),
            SizedBox(width: 5.w),
            Text(label, style: AppStyle.button(15, color: color), maxLines: 1),
          ],
        ),
      ),
    );
  }
}
