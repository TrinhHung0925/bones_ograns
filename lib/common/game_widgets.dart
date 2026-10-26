import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import 'game_button.dart';

export 'game_button.dart';

/// Uppercase, letter-spaced heading above a group ("CHỌN HỆ CƠ QUAN").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Text(text.toUpperCase(), style: AppStyle.label()),
    );
  }
}

/// Icon on a soft tinted circle, in the style of category tiles.
class IconBubble extends StatelessWidget {
  const IconBubble({super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.r,
      height: size.r,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: (size * 0.52).r),
    );
  }
}

/// Small dark rounded pill for stats and status ("● LIVE", "292 bộ phận").
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.text,
    this.icon,
    this.iconColor = AppColors.textSecondary,
    this.dotColor,
    this.background = AppColors.surfaceDepth,
  });

  final String text;
  final IconData? icon;
  final Color iconColor;
  final Color? dotColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(color: background.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            SizedBox(width: 6.w),
          ],
          if (icon != null) ...[Icon(icon, size: 16.r, color: iconColor), SizedBox(width: 5.w)],
          Text(
            text,
            style: AppStyle.body(13, color: AppColors.textPrimary, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Rounded violet square with the app glyph, used as the brand mark.
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, this.size = 48, this.icon = Icons.accessibility_new});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: GameTone.primary,
      fadeWhenDisabled: false,
      radius: size * 0.3,
      depth: size * 0.09,
      child: SizedBox.square(
        dimension: size.r,
        child: Icon(icon, color: AppColors.textPrimary, size: (size * 0.55).r),
      ),
    );
  }
}

/// Screen header: brand mark or back button, title/subtitle, and actions.
class GameHeader extends StatelessWidget {
  const GameHeader({super.key, required this.title, this.subtitle, this.onBack, this.actions = const []});

  final String title;
  final String? subtitle;

  /// Shows a back button instead of the brand mark when set.
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      child: Row(
        children: [
          if (onBack != null)
            GameIconButton(icon: Icons.arrow_back_rounded, onTap: onBack, tooltip: AppText.back)
          else
            const BrandTile(),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppStyle.display(24), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, style: AppStyle.body(13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          for (final action in actions) ...[SizedBox(width: 8.w), action],
        ],
      ),
    );
  }
}

/// Edge-to-edge band that hosts the 3D viewer, like a game stage: full
/// screen width, hairlines above and below.
class StageFrame extends StatelessWidget {
  const StageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(color: AppColors.border, width: 1.r);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(top: line, bottom: line),
      ),
      child: ClipRect(child: child),
    );
  }
}

/// Rounded-top panel pinned to the bottom of a screen, holding the main CTA.
class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
