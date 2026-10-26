import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../common/loading_chip.dart';
import '../../resource/app_text.dart';
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
      appBar: AppBar(
        leading: BackButton(onPressed: controller.onBack),
        title: Text(
          AppText.quizTitle(controller.system.label),
          style: TextStyle(fontSize: 20.sp),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: AnatomyViewer(bridge: controller.viewer)),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(12.r),
              child: GetBuilder<QuizController>(
                builder: (controller) {
                  if (controller.loading) {
                    return const Align(alignment: Alignment.topCenter, child: LoadingChip());
                  }
                  if (controller.session.finished) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.topCenter,
                    child: _QuestionCard(controller: controller),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = controller.session;
    final small = TextStyle(fontSize: 13.sp);
    final label = TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600);
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(AppText.quizProgress(session.index + 1, session.length), style: label),
                const Spacer(),
                Text(AppText.quizScore(session.score), style: label),
                SizedBox(width: 8.w),
              ],
            ),
            SizedBox(height: 6.h),
            Text(AppText.quizTapOn, style: small),
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.current.name,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20.sp),
                  ),
                ),
                IconButton(
                  tooltip: AppText.pronounce,
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: controller.speakTarget,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.feedback ??
                        AppText.quizAttemptsLeft(session.maxAttempts - session.attempts),
                    style: small,
                  ),
                ),
                TextButton(
                  onPressed: session.answered ? null : controller.skip,
                  child: Text(AppText.quizSkip, style: TextStyle(fontSize: 14.sp)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
