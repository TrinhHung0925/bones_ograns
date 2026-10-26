import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/assembly_tutorial.dart';
import '../common/game_widgets.dart';
import '../model/graphics_quality.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import '../service/local_service.dart';

/// Settings bottom sheet: sound, graphics quality and the game tutorial.
/// Changes are saved at once and live viewers follow them.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static Future<void> show() => showModalBottomSheet<void>(
    context: Get.context!,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SettingsDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final local = Get.find<LocalService>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppText.settings, style: AppStyle.display(26)),
            SizedBox(height: 16.h),
            _SettingRow(
              icon: Icons.volume_up_rounded,
              title: AppText.settingsSound,
              child: Obx(
                () => _Segmented<bool>(
                  values: const [true, false],
                  labels: const [AppText.settingsOn, AppText.settingsOff],
                  selected: local.soundEnabled.value,
                  onChanged: local.setSoundEnabled,
                ),
              ),
            ),
            SizedBox(height: 14.h),
            _SettingRow(
              icon: Icons.auto_awesome_rounded,
              title: AppText.settingsQuality,
              hint: AppText.settingsQualityHint,
              child: Obx(
                () => _Segmented<GraphicsQuality>(
                  values: GraphicsQuality.values,
                  labels: [for (final q in GraphicsQuality.values) q.label],
                  selected: local.graphicsQuality.value,
                  onChanged: local.setGraphicsQuality,
                ),
              ),
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                tone: GameTone.primary,
                radius: 18,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                onTap: () {
                  Navigator.of(context).pop();
                  AssemblyTutorial.show();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_rounded, color: AppColors.textPrimary, size: 22.r),
                    SizedBox(width: 8.w),
                    Text(AppText.settingsTutorial, style: AppStyle.button(17)),
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.child, this.hint});

  final IconData icon;
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      radius: 20,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: icon, color: AppColors.accent, size: 34),
              SizedBox(width: 10.w),
              Expanded(child: Text(title, style: AppStyle.title(18))),
            ],
          ),
          if (hint != null) ...[
            SizedBox(height: 4.h),
            Text(hint!, style: AppStyle.body(12, color: AppColors.textMuted)),
          ],
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

/// Row of chunky toggle buttons; the selected one is outlined.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.values, required this.labels, required this.selected, required this.onChanged});

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(
            child: GameButton(
              tone: GameTone.raised,
              selected: values[i] == selected,
              radius: 14,
              depth: 4,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              onTap: () => onChanged(values[i]),
              child: Center(
                child: Text(
                  labels[i],
                  style: AppStyle.button(
                    16,
                    color: values[i] == selected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
