import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/model_loading.dart';
import '../../common/view_controls.dart';
import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/game_widgets.dart';
import '../../common/part_name.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import '../../utils/quiz_session.dart';
import 'quiz_controller.dart';

class QuizView extends StatefulWidget {
  QuizView({super.key}) {
    if (!Get.isRegistered<QuizController>()) {
      Get.put(QuizController());
    }
  }

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  var controller = Get.find<QuizController>();

  @override
  void dispose() {
    Get.delete<QuizController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            GetBuilder<QuizController>(
              builder: (controller) {
                final session = controller.session;
                final question = (session.index + 1).clamp(1, session.length);
                return GameHeader(
                  title: AppText.quizTitle(controller.system.label),
                  subtitle: AppText.quizProgress(question, session.length),
                  onBack: controller.onBack,
                  actions: [StatPill(text: '${session.score}', icon: Icons.star_rounded, iconColor: AppColors.star)],
                );
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: GetBuilder<QuizController>(
                builder: (controller) => Column(
                  children: [
                    _ProgressSegments(session: controller.session),
                    SizedBox(height: 14.h),
                    if (!controller.session.finished) _QuestionCard(controller: controller),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Expanded(
              child: StageFrame(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
                    Positioned(
                      right: 12.w,
                      bottom: 12.h,
                      child: ViewControls(bridge: controller.viewer),
                    ),
                    Positioned.fill(
                      child: GetBuilder<QuizController>(
                        builder: (controller) => controller.loading
                            ? Center(child: ModelLoading(detail: controller.system.label))
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
              child: GetBuilder<QuizController>(
                builder: (controller) {
                  final session = controller.session;
                  final enabled = !controller.loading && !session.finished && !session.answered;
                  return _SkipButton(onTap: enabled ? controller.skip : null);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One segment per question: green scored, red missed, violet current.
class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.session});

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
              height: 10.h,
              decoration: BoxDecoration(
                color: switch (results[i]) {
                  true => AppColors.correct,
                  false => AppColors.wrong,
                  null when i == session.index => AppColors.primary,
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    return GameButton(
      tone: GameTone.primary,
      fadeWhenDisabled: false,
      radius: 24,
      depth: 6,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 14.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The prompt appears only once the model can be tapped.
              controller.loading
                  ? const StatPill(text: AppText.loading, dotColor: AppColors.textMuted)
                  : const StatPill(text: AppText.quizTapOn, dotColor: AppColors.accent),
              const Spacer(),
              _Hearts(left: session.maxAttempts - session.attempts, total: session.maxAttempts),
            ],
          ),
          SizedBox(height: 10.h),
          if (controller.loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(AppText.loadingModel, style: AppStyle.title(20)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: PartName(
                    vi: session.current.displayName,
                    en: session.current.name,
                    style: AppStyle.display(28),
                    englishSize: 14,
                    englishColor: AppColors.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
                SizedBox(width: 8.w),
                GameIconButton(
                  icon: Icons.volume_up_rounded,
                  tooltip: AppText.pronounce,
                  onTap: controller.speakTarget,
                  tone: GameTone.accent,
                  size: 44,
                ),
              ],
            ),
          SizedBox(height: 10.h),
          _Feedback(kind: controller.feedbackKind, text: controller.feedback),
        ],
      ),
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
              size: 22.r,
              color: i < left ? AppColors.wrong : AppColors.textPrimary.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.kind, required this.text});

  final QuizFeedback? kind;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      QuizFeedback.correct => (Icons.check_circle_rounded, AppColors.correct),
      QuizFeedback.wrong => (Icons.cancel_rounded, AppColors.wrong),
      QuizFeedback.revealed => (Icons.lightbulb_rounded, AppColors.accent),
      null => (Icons.swap_horiz_rounded, AppColors.textSecondary),
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceDepth.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18.r, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text ?? AppText.quizAttemptsHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.body(
                14,
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

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GameButton(
        onTap: onTap,
        radius: 18,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.skip_next_rounded, color: AppColors.textPrimary, size: 24.r),
            SizedBox(width: 6.w),
            Text(AppText.quizSkip, style: AppStyle.button(17)),
          ],
        ),
      ),
    );
  }
}
