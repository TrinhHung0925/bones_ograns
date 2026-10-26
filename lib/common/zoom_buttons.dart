import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_text.dart';
import 'anatomy_viewer/viewer_bridge.dart';
import 'game_button.dart';

/// "+" / "−" buttons over a 3D stage. Pinching works too; these help on the
/// simulator and one-handed.
class ZoomButtons extends StatelessWidget {
  const ZoomButtons({super.key, required this.bridge, this.size = 40});

  final ViewerBridge bridge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIconButton(icon: Icons.add_rounded, tooltip: AppText.zoomInTooltip, onTap: bridge.zoomIn, size: size),
        SizedBox(height: 8.h),
        GameIconButton(icon: Icons.remove_rounded, tooltip: AppText.zoomOutTooltip, onTap: bridge.zoomOut, size: size),
      ],
    );
  }
}
