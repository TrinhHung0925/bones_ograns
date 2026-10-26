import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/loading_chip.dart';
import '../../model/anatomy_part.dart';
import '../../model/part_state.dart';
import '../../resource/app_colors.dart';
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
      appBar: AppBar(
        title: Text(AppText.appName, style: TextStyle(fontSize: 20.sp)),
        actions: [
          IconButton(
            tooltip: AppText.search,
            icon: const Icon(Icons.search),
            onPressed: controller.openSearch,
          ),
          IconButton(
            tooltip: AppText.quiz,
            icon: const Icon(Icons.quiz_outlined),
            onPressed: controller.openQuiz,
          ),
          IconButton(
            tooltip: AppText.info,
            icon: const Icon(Icons.info_outline),
            onPressed: controller.openAbout,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
          SafeArea(
            top: false,
            child: Stack(
              children: [
                Obx(() => controller.isLoading
                    ? Positioned(
                        top: 12.h,
                        left: 0,
                        right: 0,
                        child: const Center(child: LoadingChip()),
                      )
                    : const SizedBox.shrink()),
                Obx(() {
                  final error = controller.error.value;
                  if (error == null) return const SizedBox.shrink();
                  return Positioned(
                    top: 12.h,
                    left: 16.w,
                    right: 16.w,
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12.r),
                      child: Padding(
                        padding: EdgeInsets.all(12.r),
                        child: Text(error, style: TextStyle(fontSize: 13.sp)),
                      ),
                    ),
                  );
                }),
                Positioned(right: 12.w, top: 12.h, child: _Toolbar(controller: controller)),
                Positioned(
                  left: 12.w,
                  right: 12.w,
                  bottom: 12.h,
                  child: Obx(() {
                    final part = controller.selected.value;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: part == null
                          ? const _Hint(key: ValueKey('hint'))
                          : _PartCard(key: ValueKey(part.id), part: part, controller: controller),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppText.bodySystems,
                icon: const Icon(Icons.layers_outlined),
                onPressed: controller.openSystems,
              ),
              IconButton(
                tooltip: AppText.resetCamera,
                icon: const Icon(Icons.center_focus_strong_outlined),
                onPressed: controller.resetCamera,
              ),
              if (controller.partStates.isNotEmpty)
                IconButton(
                  tooltip: AppText.showAll,
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: controller.showAll,
                ),
            ],
          )),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.hintBackground,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          child: Text(
            AppText.viewerHint,
            style: TextStyle(color: AppColors.hintText, fontSize: 12.sp),
          ),
        ),
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 4.w, 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12.r, color: part.system.color),
                SizedBox(width: 6.w),
                Text(part.system.label, style: TextStyle(fontSize: 13.sp)),
                const Spacer(),
                IconButton(
                  tooltip: AppText.close,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: controller.clearSelection,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    part.name,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20.sp),
                  ),
                ),
                IconButton(
                  tooltip: AppText.pronounce,
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: controller.speakSelected,
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Obx(() {
              final ghosted = controller.stateOf(part.id) == PartState.ghost;
              return Wrap(
                spacing: 4.w,
                children: [
                  _Action(icon: Icons.zoom_in, label: AppText.zoomIn, onTap: controller.focusSelected),
                  _Action(
                    icon: Icons.visibility_off_outlined,
                    label: AppText.hide,
                    onTap: controller.hideSelected,
                  ),
                  _Action(
                    icon: Icons.opacity,
                    label: ghosted ? AppText.unghost : AppText.ghost,
                    onTap: controller.toggleGhostSelected,
                  ),
                  _Action(
                    icon: Icons.filter_center_focus,
                    label: AppText.isolate,
                    onTap: controller.isolateSelected,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      icon: Icon(icon, size: 18.r),
      label: Text(label, style: TextStyle(fontSize: 14.sp)),
      onPressed: onTap,
    );
  }
}
