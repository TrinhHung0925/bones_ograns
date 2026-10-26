import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../common/part_name.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'mistakes_controller.dart';

class MistakesView extends StatefulWidget {
  MistakesView({super.key}) {
    if (!Get.isRegistered<MistakesController>()) {
      Get.put(MistakesController());
    }
  }

  @override
  State<MistakesView> createState() => _MistakesViewState();
}

class _MistakesViewState extends State<MistakesView> {
  var controller = Get.find<MistakesController>();

  @override
  void dispose() {
    Get.delete<MistakesController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.2,
            colors: [AppColors.backgroundGlow, AppColors.background],
          ),
        ),
        child: GetBuilder<MistakesController>(
          builder: (controller) => Column(
            children: [
              SafeArea(
                bottom: false,
                child: GameHeader(
                  title: AppText.examMistakesTitle,
                  subtitle: controller.entries.isEmpty ? null : AppText.examMistakesSubtitle(controller.entries.length),
                  onBack: controller.onBack,
                ),
              ),
              Expanded(
                child: controller.entries.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                        itemCount: controller.entries.length + 1,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (context, i) {
                          if (i == 0) return const SectionLabel(AppText.examMistakesHint);
                          final entry = controller.entries[i - 1];
                          return _MistakeCard(entry: entry, onTap: () => controller.preview(entry.part));
                        },
                      ),
              ),
              if (controller.entries.isNotEmpty)
                BottomPanel(
                  child: SizedBox(
                    width: double.infinity,
                    child: GameButton(
                      tone: GameTone.accent,
                      onTap: controller.review,
                      radius: 20,
                      depth: 6,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.replay_rounded, color: AppColors.onAccent, size: 24.r),
                          SizedBox(width: 8.w),
                          Text(AppText.examMistakesReview, style: AppStyle.button(19, color: AppColors.onAccent)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.entry, required this.onTap});

  final MistakeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final part = entry.part;
    return GameButton(
      onTap: onTap,
      radius: 18,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Row(
        children: [
          IconBubble(icon: part.system.icon, color: part.system.color, size: 42),
          SizedBox(width: 12.w),
          Expanded(
            child: PartName(vi: part.displayName, en: part.name, style: AppStyle.title(16), englishSize: 12),
          ),
          SizedBox(width: 8.w),
          StatPill(text: AppText.examMissCount(entry.count), icon: Icons.close_rounded, iconColor: AppColors.wrong),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBubble(icon: Icons.sentiment_very_satisfied_rounded, color: AppColors.correct, size: 88),
            SizedBox(height: 16.h),
            Text(AppText.examMistakesEmpty, textAlign: TextAlign.center, style: AppStyle.display(24)),
            SizedBox(height: 8.h),
            Text(AppText.examMistakesEmptyBody, textAlign: TextAlign.center, style: AppStyle.body(15)),
          ],
        ),
      ),
    );
  }
}
