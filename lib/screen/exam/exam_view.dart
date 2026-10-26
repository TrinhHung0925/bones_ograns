import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/game_widgets.dart';
import '../../common/model_loading.dart';
import '../../common/part_name.dart';
import '../../common/view_controls.dart';
import '../../model/anatomy_part.dart';
import '../../model/exam_config.dart';
import '../../model/exam_question.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import '../../utils/assembly_score.dart';
import 'exam_controller.dart';

class ExamView extends StatefulWidget {
  ExamView({super.key}) {
    if (!Get.isRegistered<ExamController>()) {
      Get.put(ExamController());
    }
  }

  @override
  State<ExamView> createState() => _ExamViewState();
}

class _ExamViewState extends State<ExamView> {
  var controller = Get.find<ExamController>();

  @override
  void dispose() {
    Get.delete<ExamController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Immersive layout: the 3D stage fills the screen; the HUD and the
    // question card float over it.
    return Scaffold(
      body: Stack(
        // Builders may return a SizedBox.shrink; expand keeps the WebView full size.
        fit: StackFit.expand,
        children: [
          _Stage(controller: controller),
          const _Scrim(top: true),
          const _Scrim(top: false),
          Positioned(top: 0, left: 0, right: 0, child: _TopHud(controller: controller)),
          Positioned(left: 0, right: 0, bottom: 0, child: _BottomCard(controller: controller)),
        ],
      ),
    );
  }
}

/// The 3D viewer with zoom controls and the loading state.
class _Stage extends StatelessWidget {
  const _Stage({required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
        Positioned(
          right: 10.w,
          top: 0,
          bottom: 0,
          child: Center(child: ViewControls(bridge: controller.viewer, size: 36)),
        ),
        GetBuilder<ExamController>(
          builder: (controller) => controller.loading
              ? Positioned.fill(
                  child: Center(child: ModelLoading(detail: controller.loadingDetail)),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Darkens a screen edge behind a floating bar; never blocks touches.
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
      height: inset + (top ? 120 : 160).h,
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

/// Back, title and progress, score, total time, then the question timer.
class _TopHud extends StatelessWidget {
  const _TopHud({required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
        child: GetBuilder<ExamController>(
          builder: (controller) {
            final session = controller.session;
            final number = (session.index + 1).clamp(1, session.length == 0 ? 1 : session.length);
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
                            controller.title,
                            style: AppStyle.title(19),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(AppText.quizProgress(number, session.length), style: AppStyle.body(12), maxLines: 1),
                        ],
                      ),
                    ),
                    GetBuilder<ExamController>(
                      id: ExamController.clockId,
                      builder: (controller) =>
                          StatPill(icon: Icons.schedule_rounded, text: formatClock(controller.totalTime)),
                    ),
                    SizedBox(width: 6.w),
                    _ScorePill(score: session.score),
                  ],
                ),
                SizedBox(height: 8.h),
                _ProgressSegments(results: session.results, index: session.index),
                if (controller.config.timed && !controller.empty) ...[
                  SizedBox(height: 6.h),
                  GetBuilder<ExamController>(
                    id: ExamController.clockId,
                    builder: (controller) => _Countdown(
                      fraction: controller.timeFraction,
                      seconds: (controller.remaining.inMilliseconds / 1000).ceil(),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(score),
      tween: Tween(begin: 1.2, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: StatPill(
        icon: Icons.bolt_rounded,
        iconColor: AppColors.accent,
        background: AppColors.primaryDepth,
        text: '$score',
      ),
    );
  }
}

/// One thin segment per question: green right, red missed, violet current.
class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.results, required this.index});

  final List<bool?> results;
  final int index;

  @override
  Widget build(BuildContext context) {
    final gap = results.length > 20 ? 2.w : 4.w;
    return Row(
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 6.h,
              decoration: BoxDecoration(
                color: switch (results[i]) {
                  true => AppColors.correct,
                  false => AppColors.wrong,
                  null when i == index => AppColors.primary,
                  null => AppColors.surfaceRaised,
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

/// Seconds left for the question, as a pill and a draining bar.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.fraction, required this.seconds});

  final double fraction;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final color = fraction > 0.5
        ? AppColors.correct
        : fraction > 0.25
        ? AppColors.accent
        : AppColors.wrong;
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 16.r, color: color),
        SizedBox(width: 4.w),
        SizedBox(
          width: 28.w,
          child: Text(
            '${seconds}s',
            style: AppStyle.body(13, color: AppColors.textPrimary, weight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Container(
            height: 8.h,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: AppColors.surfaceDepth, borderRadius: BorderRadius.circular(999)),
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Question card: type tag, prompt, the answers, then feedback.
class _BottomCard extends StatelessWidget {
  const _BottomCard({required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
        child: GetBuilder<ExamController>(
          builder: (controller) {
            if (controller.empty) return _EmptyCard(onBack: controller.onBack);
            if (controller.session.finished) return const SizedBox.shrink();
            final question = controller.current;
            return Container(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Prompt(controller: controller, question: question),
                  if (question.hasOptions) ...[
                    SizedBox(height: 10.h),
                    _Options(controller: controller, question: question),
                  ],
                  if (controller.session.answered) ...[
                    SizedBox(height: 10.h),
                    _Feedback(controller: controller, question: question),
                  ] else if (question.type == QuestionType.tapPart) ...[
                    SizedBox(height: 10.h),
                    _SkipButton(onTap: controller.canSkip ? controller.skip : null),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.controller, required this.question});

  final ExamController controller;
  final ExamQuestion question;

  @override
  Widget build(BuildContext context) {
    final (tag, dot) = switch (question.type) {
      QuestionType.tapPart => (AppText.examTagTapPart, AppColors.accent),
      QuestionType.namePart => (AppText.examTagNamePart, AppColors.correct),
      QuestionType.enToVi => (AppText.examTagEnToVi, AppColors.primary),
      QuestionType.viToEn => (AppText.examTagViToEn, AppColors.sensory),
    };
    final speakable = question.type == QuestionType.tapPart || question.type == QuestionType.enToVi;
    final Widget text = switch (question.type) {
      QuestionType.tapPart => PartName(
        vi: question.target.displayName,
        en: question.target.name,
        style: AppStyle.display(24),
        englishSize: 13,
      ),
      QuestionType.namePart => Text(AppText.examNamePartPrompt, style: AppStyle.display(22)),
      _ => Text(question.prompt, style: AppStyle.display(24), maxLines: 3, overflow: TextOverflow.ellipsis),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              StatPill(text: tag, dotColor: dot),
              SizedBox(height: 6.h),
              text,
            ],
          ),
        ),
        if (speakable) ...[
          SizedBox(width: 8.w),
          GameIconButton(
            icon: Icons.volume_up_rounded,
            tooltip: AppText.pronounce,
            onTap: controller.speakTarget,
            tone: GameTone.accent,
            size: 40,
          ),
        ],
      ],
    );
  }
}

/// The 4 answers: a compact 2×2 grid over the model for [QuestionType.namePart],
/// full-width rows for the text questions.
class _Options extends StatelessWidget {
  const _Options({required this.controller, required this.question});

  final ExamController controller;
  final ExamQuestion question;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    Widget option(AnatomyPart part, double height) => _OptionButton(
      label: question.optionLabel(part),
      height: height,
      state: !session.answered
          ? _OptionState.open
          : question.optionLabel(part) == question.optionLabel(question.target)
          ? _OptionState.right
          : part.id == session.chosenId
          ? _OptionState.wrong
          : _OptionState.faded,
      onTap: controller.loading ? null : () => controller.pickOption(part),
    );
    final options = question.options;
    if (question.type == QuestionType.namePart) {
      return Column(
        children: [
          for (var row = 0; row < options.length; row += 2) ...[
            if (row > 0) SizedBox(height: 8.h),
            Row(
              children: [
                for (var i = row; i < row + 2 && i < options.length; i++) ...[
                  if (i > row) SizedBox(width: 8.w),
                  Expanded(child: option(options[i], 54)),
                ],
              ],
            ),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[if (i > 0) SizedBox(height: 8.h), option(options[i], 52)],
      ],
    );
  }
}

enum _OptionState { open, right, wrong, faded }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.label, required this.height, required this.state, required this.onTap});

  final String label;
  final double height;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppStyle.body(15, color: AppColors.textPrimary, weight: FontWeight.w800).copyWith(height: 1.2),
    );
    if (state == _OptionState.open) {
      return GameButton(
        tone: GameTone.raised,
        onTap: onTap,
        radius: 16,
        depth: 4,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: SizedBox(
          height: height.h,
          width: double.infinity,
          child: Center(child: text),
        ),
      );
    }
    final color = switch (state) {
      _OptionState.right => AppColors.correct,
      _OptionState.wrong => AppColors.wrong,
      _ => AppColors.surfaceRaised,
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: state == _OptionState.faded ? 0.45 : 1,
      child: Container(
        height: height.h,
        width: double.infinity,
        // Same footprint as the raised button, its edge included.
        margin: EdgeInsets.only(top: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: state == _OptionState.faded ? 1 : 0.28),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color, width: 2.r),
        ),
        child: Row(
          children: [
            if (state == _OptionState.right || state == _OptionState.wrong) ...[
              Icon(
                state == _OptionState.right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18.r,
                color: color,
              ),
              SizedBox(width: 6.w),
            ],
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}

/// Result of the answer; in practice mode also the explanation and "next".
class _Feedback extends StatelessWidget {
  const _Feedback({required this.controller, required this.question});

  final ExamController controller;
  final ExamQuestion question;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final (icon, color, text) = switch (controller.feedback) {
      ExamFeedback.correct => (Icons.check_circle_rounded, AppColors.correct, AppText.examCorrect),
      ExamFeedback.wrong => (Icons.cancel_rounded, AppColors.wrong, AppText.examWrong),
      ExamFeedback.timeout => (Icons.timer_off_rounded, AppColors.wrong, AppText.examTimeout),
      ExamFeedback.skipped || null => (Icons.lightbulb_rounded, AppColors.accent, AppText.examSkipped),
    };
    final target = question.target;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceDepth.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18.r, color: color),
                  SizedBox(width: 6.w),
                  Text(
                    text,
                    style: AppStyle.body(14, color: color, weight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (session.lastPoints > 0)
                    Text(AppText.examPoints(session.lastPoints), style: AppStyle.title(16, color: AppColors.accent)),
                ],
              ),
              // The explanation: both names and the system of the answer.
              if (!controller.config.timed || controller.feedback != ExamFeedback.correct) ...[
                SizedBox(height: 6.h),
                Row(
                  children: [
                    IconBubble(icon: target.system.icon, color: target.system.color, size: 30),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: PartName(
                        vi: target.displayName,
                        en: target.name,
                        style: AppStyle.title(15),
                        englishSize: 12,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      AppText.examSystem(target.system.label),
                      style: AppStyle.body(11, color: AppColors.textMuted, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (controller.waitingForNext) ...[
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: GameButton(
              tone: GameTone.accent,
              onTap: controller.next,
              radius: 18,
              depth: 5,
              padding: EdgeInsets.symmetric(vertical: 13.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    controller.isLast ? AppText.examFinish : AppText.examNext,
                    style: AppStyle.button(18, color: AppColors.onAccent),
                  ),
                  SizedBox(width: 6.w),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.onAccent, size: 22.r),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: SizedBox(
        width: double.infinity,
        child: GameButton(
          tone: GameTone.raised,
          onTap: onTap,
          radius: 16,
          depth: 4,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.skip_next_rounded, color: AppColors.textPrimary, size: 22.r),
              SizedBox(width: 6.w),
              Text(AppText.examSkip, style: AppStyle.button(16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppText.examEmpty, textAlign: TextAlign.center, style: AppStyle.title(17)),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: GameButton(
              tone: GameTone.raised,
              onTap: onBack,
              radius: 18,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Center(child: Text(AppText.examBack, style: AppStyle.button(17))),
            ),
          ),
        ],
      ),
    );
  }
}
