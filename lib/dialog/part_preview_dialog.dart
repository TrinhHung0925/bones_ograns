import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/anatomy_viewer/anatomy_viewer.dart';
import '../common/game_widgets.dart';
import '../common/model_loading.dart';
import '../common/part_name.dart';
import '../model/anatomy_part.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';

/// Small 3D preview of one part: its system, the part isolated and focused.
class PartPreviewDialog extends StatefulWidget {
  const PartPreviewDialog({super.key, required this.part});

  final AnatomyPart part;

  static Future<void> show(AnatomyPart part) =>
      Get.dialog<void>(PartPreviewDialog(part: part), barrierColor: AppColors.surfaceDepth.withValues(alpha: 0.75));

  @override
  State<PartPreviewDialog> createState() => _PartPreviewDialogState();
}

class _PartPreviewDialogState extends State<PartPreviewDialog> {
  final _viewer = ViewerBridge();
  late final StreamSubscription<ViewerEvent> _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final part = widget.part;
    _sub = _viewer.events.listen((event) {
      if (event is SystemLoaded && event.system == part.system && mounted) setState(() => _loading = false);
    });
    _viewer.setSystemVisible(part.system, true);
    _viewer.isolate(part.id);
    _viewer.select(part.id);
    _viewer.focus(part.id);
  }

  @override
  void dispose() {
    _sub.cancel();
    _viewer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final part = widget.part;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GameButton(
        radius: 26,
        depth: 7,
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconBubble(icon: part.system.icon, color: part.system.color, size: 36),
                SizedBox(width: 10.w),
                Expanded(
                  child: PartName(vi: part.displayName, en: part.name, style: AppStyle.title(18)),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(18.r),
              child: SizedBox(
                height: 340.h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(child: AnatomyViewer(bridge: _viewer)),
                    if (_loading) Center(child: ModelLoading(detail: part.system.label)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                tone: GameTone.raised,
                onTap: () => Get.back(),
                radius: 18,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Center(child: Text(AppText.close, style: AppStyle.button(17))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
