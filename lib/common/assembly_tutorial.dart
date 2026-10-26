import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import 'game_widgets.dart';

/// "How to play" overlay of the assembly game: a dim backdrop, a hand that
/// drags a piece into its ghost slot, three short steps and a start button.
class AssemblyTutorial extends StatelessWidget {
  const AssemblyTutorial({super.key, required this.onStart});

  final VoidCallback onStart;

  /// Shows the tutorial on its own, e.g. from the settings sheet.
  static Future<void> show() => Get.dialog<void>(
    Material(
      type: MaterialType.transparency,
      child: AssemblyTutorial(onStart: () => Get.back()),
    ),
    barrierColor: Colors.transparent,
    useSafeArea: false,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: ColoredBox(color: AppColors.surfaceDepth.withValues(alpha: 0.82)),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: GameButton(
              fadeWhenDisabled: false,
              radius: 28,
              depth: 6,
              padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppText.tutorialTitle, style: AppStyle.display(28)),
                  SizedBox(height: 12.h),
                  const _DragDemo(),
                  SizedBox(height: 16.h),
                  const _Step(number: 1, icon: Icons.pan_tool_alt_rounded, text: AppText.tutorialStep1),
                  SizedBox(height: 10.h),
                  const _Step(number: 2, icon: Icons.threesixty_rounded, text: AppText.tutorialStep2),
                  SizedBox(height: 10.h),
                  const _Step(number: 3, icon: Icons.lightbulb_rounded, text: AppText.tutorialStep3),
                  SizedBox(height: 18.h),
                  SizedBox(
                    width: double.infinity,
                    child: GameButton(
                      tone: GameTone.accent,
                      onTap: onStart,
                      radius: 18,
                      depth: 6,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: AppColors.onAccent, size: 24.r),
                          SizedBox(width: 6.w),
                          Text(AppText.tutorialStart, style: AppStyle.button(18, color: AppColors.onAccent)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.icon, required this.text});

  final int number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26.r,
          height: 26.r,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text('$number', style: AppStyle.button(14)),
        ),
        SizedBox(width: 10.w),
        Icon(icon, size: 20.r, color: AppColors.accent),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: AppStyle.body(14, color: AppColors.textPrimary, weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Looping animation: a hand carries a piece along an arc into its ghost.
class _DragDemo extends StatefulWidget {
  const _DragDemo();

  @override
  State<_DragDemo> createState() => _DragDemoState();
}

class _DragDemoState extends State<_DragDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = 240.w;
    final height = 120.h;
    final piece = 34.r;
    const start = Offset(0.12, 0.72);
    const control = Offset(0.45, -0.1);
    const end = Offset(0.8, 0.35);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          // 0–0.15 press, 0.15–0.7 drag, 0.7–1 snapped.
          final t = _anim.value;
          final drag = Curves.easeInOut.transform(((t - 0.15) / 0.55).clamp(0.0, 1.0));
          final u = 1 - drag;
          final pos = start * (u * u) + control * (2 * u * drag) + end * (drag * drag);
          final snapped = t >= 0.7;
          final pressed = t >= 0.08 && t < 0.7;
          final left = pos.dx * width - piece / 2;
          final top = pos.dy * height - piece / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Ghost slot.
              Positioned(
                left: end.dx * width - piece / 2,
                top: end.dy * height - piece / 2,
                child: Container(
                  width: piece,
                  height: piece,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    color: (snapped ? AppColors.correct : AppColors.textPrimary).withValues(alpha: 0.15),
                    border: Border.all(color: snapped ? AppColors.correct : AppColors.textMuted, width: 2.r),
                  ),
                ),
              ),
              // Piece.
              Positioned(
                left: left,
                top: top,
                child: Transform.scale(
                  scale: snapped ? lerpDouble(1.15, 1, ((t - 0.7) / 0.1).clamp(0.0, 1.0))! : 1,
                  child: Container(
                    width: piece,
                    height: piece,
                    decoration: BoxDecoration(
                      color: snapped ? AppColors.correct : AppColors.skeletal,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.extension_rounded, size: 20.r, color: AppColors.onAccent),
                  ),
                ),
              ),
              // Hand, slightly below-right of the finger tip.
              Positioned(
                left: left + piece * 0.35,
                top: top + piece * 0.45,
                child: Opacity(
                  opacity: snapped ? (1 - ((t - 0.7) / 0.15)).clamp(0.0, 1.0) : 1,
                  child: Transform.scale(
                    scale: pressed ? 0.88 : 1,
                    child: Icon(Icons.touch_app_rounded, size: 40.r, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
