import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_text.dart';
import 'anatomy_viewer/viewer_bridge.dart';
import 'game_button.dart';

/// Buttons over a 3D stage: one-finger drag mode (rotate ↔ move, like a
/// photo) and zoom in/out. Pinching and two-finger dragging always work too.
class ViewControls extends StatefulWidget {
  const ViewControls({super.key, required this.bridge, this.size = 40});

  final ViewerBridge bridge;
  final double size;

  @override
  State<ViewControls> createState() => _ViewControlsState();
}

class _ViewControlsState extends State<ViewControls> {
  bool _pan = false;

  void _toggleMode() {
    setState(() => _pan = !_pan);
    widget.bridge.setPanMode(_pan);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIconButton(
          // Shows the current mode; tapping switches to the other one.
          icon: _pan ? Icons.open_with_rounded : Icons.threed_rotation_rounded,
          tooltip: _pan ? AppText.panModeTooltip : AppText.rotateModeTooltip,
          tone: _pan ? GameTone.primary : GameTone.surface,
          onTap: _toggleMode,
          size: widget.size,
        ),
        SizedBox(height: 8.h),
        GameIconButton(
          icon: Icons.add_rounded,
          tooltip: AppText.zoomInTooltip,
          onTap: widget.bridge.zoomIn,
          size: widget.size,
        ),
        SizedBox(height: 8.h),
        GameIconButton(
          icon: Icons.remove_rounded,
          tooltip: AppText.zoomOutTooltip,
          onTap: widget.bridge.zoomOut,
          size: widget.size,
        ),
      ],
    );
  }
}
