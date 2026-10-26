import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/game_widgets.dart';
import '../../common/model_loading.dart';
import '../../common/part_name.dart';
import '../../common/view_controls.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import '../../utils/quiz_session.dart';
import 'lesson_controller.dart';

class LessonView extends StatefulWidget {
  LessonView({super.key}) {
    if (!Get.isRegistered<LessonController>()) {
      Get.put(LessonController());
    }
  }

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  var controller = Get.find<LessonController>();

  @override
  void dispose() {
    Get.delete<LessonController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Immersive layout, like the assembly game: the 3D stage fills the whole
    // screen and compact bars float over it.
    return Scaffold(
      body: Stack(
        // Builders may return a SizedBox.shrink; expand keeps the stage (and
        // its WebView) full size.
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
          const _Scrim(top: true),
          const _Scrim(top: false),
          Positioned(
            right: 10.w,
            top: 0,
            bottom: 0,
            child: Center(child: ViewControls(bridge: controller.viewer, size: 36)),
          ),
          Positioned.fill(
            child: GetBuilder<LessonController>(
              builder: (controller) => controller.loading
                  ? Center(child: ModelLoading(detail: controller.systems.map((s) => s.label).join(' · ')))
                  : const SizedBox.shrink(),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _TopBar(controller: controller)),
          Positioned(left: 0, right: 0, bottom: 0, child: _BottomBar(controller: controller)),
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
    final colors = [AppColors.background.withValues(alpha: 0.88), AppColors.background.withValues(alpha: 0)];
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: inset + (top ? 110 : 200).h,
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

/// Back, lesson title and phase, then the progress bar.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
        child: GetBuilder<LessonController>(
          builder: (controller) {
            final session = controller.session;
            final studying = controller.phase == LessonPhase.study;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GameIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: AppText.back,
                      onTap: controller.onBack,
                      size: 38,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.lesson.title,
                            style: AppStyle.title(20),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            controller.lesson.chapter.title,
                            style: AppStyle.body(12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    studying
                        ? StatPill(
                            text: AppText.lessonStep(controller.index + 1, controller.parts.length),
                            icon: Icons.menu_book_rounded,
                            iconColor: AppColors.accent,
                          )
                        : StatPill(text: '${session?.score ?? 0}', icon: Icons.star_rounded, iconColor: AppColors.star),
                  ],
                ),
                SizedBox(height: 8.h),
                studying
                    ? _StudyProgress(index: controller.index, total: controller.parts.length)
                    : _CheckProgress(session: session!),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Thin bar filling up as the parts are studied.
class _StudyProgress extends StatelessWidget {
  const _StudyProgress({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8.h,
      decoration: BoxDecoration(color: AppColors.surfaceDepth, borderRadius: BorderRadius.circular(999)),
      alignment: Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        widthFactor: total == 0 ? 0 : ((index + 1) / total).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
        ),
      ),
    );
  }
}

/// One segment per check question: green scored, red missed, violet current.
class _CheckProgress extends StatelessWidget {
  const _CheckProgress({required this.session});

  final QuizSession session;

  @override
  Widget build(BuildContext context) {
    final results = session.results;
    return Row(
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) SizedBox(width: 5.w),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 8.h,
              decoration: BoxDecoration(
                color: switch (results[i]) {
                  true => AppColors.correct,
                  false => AppColors.wrong,
                  null when i == session.index => AppColors.primary,
                  null => AppColors.surfaceDepth,
                },
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Study card with Prev/Next, or the check question with Skip.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
        child: GetBuilder<LessonController>(
          builder: (controller) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: controller.phase == LessonPhase.study
                ? _StudyPanel(key: const ValueKey('study'), controller: controller)
                : _CheckPanel(key: const ValueKey('check'), controller: controller),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StudyPanel extends StatelessWidget {
  const _StudyPanel({super.key, required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final part = controller.current;
    final enabled = !controller.loading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Panel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(part.system.icon, size: 14.r, color: part.system.color),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            '${AppText.lessonStudy} · ${part.system.label.toUpperCase()}',
                            style: AppStyle.label(color: part.system.color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    // Keyed so the name fades when the part changes.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: PartName(
                        key: ValueKey(part.id),
                        vi: part.displayName,
                        en: part.name,
                        style: AppStyle.display(24),
                        englishSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIconButton(
                    icon: Icons.volume_up_rounded,
                    tooltip: AppText.pronounce,
                    onTap: controller.speak,
                    tone: GameTone.accent,
                    size: 40,
                  ),
                  SizedBox(height: 6.h),
                  GameIconButton(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: AppText.zoomIn,
                    onTap: enabled ? controller.refocus : null,
                    size: 32,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Opacity(
              opacity: enabled && !controller.isFirst ? 1 : 0.4,
              child: GameIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: AppText.lessonPrev,
                onTap: enabled && !controller.isFirst ? controller.prev : null,
                size: 44,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _PanelButton(
                label: controller.isLast ? AppText.lessonStartCheck : AppText.lessonNext,
                icon: controller.isLast ? Icons.task_alt_rounded : Icons.chevron_right_rounded,
                tone: controller.isLast ? GameTone.accent : GameTone.primary,
                onTap: enabled ? controller.next : null,
              ),
            ),
            if (!controller.isLast) ...[
              SizedBox(width: 8.w),
              GameIconButton(
                icon: Icons.task_alt_rounded,
                tooltip: AppText.lessonStartCheck,
                onTap: enabled ? controller.startCheck : null,
                size: 44,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CheckPanel extends StatelessWidget {
  const _CheckPanel({super.key, required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    if (session.finished) return const SizedBox(width: double.infinity);
    final target = session.current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StatPill(text: AppText.quizTapOn, dotColor: AppColors.accent),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      AppText.lessonCheckStep(session.index + 1, session.length),
                      style: AppStyle.body(12, weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _Hearts(left: session.maxAttempts - session.attempts, total: session.maxAttempts),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: PartName(
                      key: ValueKey(target.id),
                      vi: target.displayName,
                      en: target.name,
                      style: AppStyle.display(24),
                      englishSize: 13,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GameIconButton(
                    icon: Icons.volume_up_rounded,
                    tooltip: AppText.pronounce,
                    onTap: controller.speak,
                    tone: GameTone.accent,
                    size: 40,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              _Feedback(kind: controller.feedbackKind, text: controller.feedback),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        _PanelButton(
          label: AppText.quizSkip,
          icon: Icons.skip_next_rounded,
          tone: GameTone.surface,
          onTap: session.answered ? null : controller.skip,
        ),
      ],
    );
  }
}

/// Remaining attempts for the current question.
class _Hearts extends StatelessWidget {
  const _Hearts({required this.left, required this.total});

  final int left;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(left: 2.w),
            child: Icon(
              i < left ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18.r,
              color: i < left ? AppColors.wrong : AppColors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.kind, required this.text});

  final LessonFeedback? kind;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      LessonFeedback.correct => (Icons.check_circle_rounded, AppColors.correct),
      LessonFeedback.wrong => (Icons.cancel_rounded, AppColors.wrong),
      LessonFeedback.revealed => (Icons.lightbulb_rounded, AppColors.accent),
      null => (Icons.touch_app_rounded, AppColors.textSecondary),
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16.r, color: color),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              text ?? AppText.lessonCheckHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.body(
                13,
                color: kind == null ? AppColors.textSecondary : AppColors.textPrimary,
                weight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact wide button of the bottom bar.
class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.label, required this.icon, required this.tone, required this.onTap});

  final String label;
  final IconData icon;
  final GameTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tone == GameTone.accent ? AppColors.onAccent : AppColors.textPrimary;
    final button = GameButton(
      tone: tone,
      onTap: onTap,
      radius: 16,
      depth: 4,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 11.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20.r),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              label,
              style: AppStyle.button(16, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    // Surface buttons don't fade by themselves when disabled.
    return onTap == null && tone == GameTone.surface ? Opacity(opacity: 0.5, child: button) : button;
  }
}
