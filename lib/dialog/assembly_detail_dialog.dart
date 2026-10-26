import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/game_widgets.dart';
import '../common/star_row.dart';
import '../model/assembly_level.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import '../screen/assembly_levels/assembly_levels_controller.dart';

/// Picks how finely a level is cut into pieces; resolves to null when
/// dismissed.
class AssemblyDetailDialog extends StatelessWidget {
  const AssemblyDetailDialog({super.key, required this.controller, required this.level});

  final AssemblyLevelsController controller;
  final AssemblyLevel level;

  static Future<AssemblyDetail?> show(AssemblyLevelsController controller, AssemblyLevel level) {
    return showModalBottomSheet<AssemblyDetail>(
      context: Get.context!,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AssemblyDetailDialog(controller: controller, level: level),
    );
  }

  static const _icons = {
    AssemblyDetail.coarse: Icons.view_agenda_rounded,
    AssemblyDetail.medium: Icons.grid_view_rounded,
    AssemblyDetail.fine: Icons.apps_rounded,
  };

  static const _colors = {
    AssemblyDetail.coarse: AppColors.correct,
    AssemblyDetail.medium: AppColors.accent,
    AssemblyDetail.fine: AppColors.wrong,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(AppText.assemblyPickDetail),
            Text(level.title, style: AppStyle.display(26)),
            SizedBox(height: 2.h),
            Text(AppText.assemblyPickDetailHint, style: AppStyle.body(13)),
            SizedBox(height: 14.h),
            for (final detail in level.details) ...[
              _DetailTile(
                detail: detail,
                icon: _icons[detail]!,
                color: _colors[detail]!,
                pieces: controller.piecesAt(level, detail),
                stars: controller.starsAt(level, detail),
                recommended: detail == level.defaultDetail,
                onTap: () => Navigator.of(context).pop(detail),
              ),
              SizedBox(height: 10.h),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.detail,
    required this.icon,
    required this.color,
    required this.pieces,
    required this.stars,
    required this.recommended,
    required this.onTap,
  });

  final AssemblyDetail detail;
  final IconData icon;
  final Color color;
  final int pieces;
  final int stars;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      onTap: onTap,
      selected: recommended,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      child: Row(
        children: [
          IconBubble(icon: icon, color: color, size: 48),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(detail.label, style: AppStyle.title(19))),
                    if (recommended) ...[
                      SizedBox(width: 8.w),
                      StatPill(text: AppText.assemblyRecommended, background: AppColors.primaryDepth),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Text(detail.description, style: AppStyle.body(12)),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppText.assemblyPieces(pieces), style: AppStyle.title(16, color: color)),
              SizedBox(height: 4.h),
              StarRow(stars: stars, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}
