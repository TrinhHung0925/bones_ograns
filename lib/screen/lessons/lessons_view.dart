import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../common/star_row.dart';
import '../../model/lesson.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'lessons_controller.dart';

class LessonsView extends StatefulWidget {
  LessonsView({super.key}) {
    if (!Get.isRegistered<LessonsController>()) {
      Get.put(LessonsController());
    }
  }

  @override
  State<LessonsView> createState() => _LessonsViewState();
}

class _LessonsViewState extends State<LessonsView> {
  var controller = Get.find<LessonsController>();

  @override
  void dispose() {
    Get.delete<LessonsController>();
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
        child: SafeArea(
          child: GetBuilder<LessonsController>(
            builder: (controller) => Column(
              children: [
                GameHeader(
                  title: AppText.lessonsTitle,
                  subtitle: AppText.lessonsSubtitle,
                  onBack: controller.onBack,
                  actions: [
                    StatPill(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.star,
                      text: AppText.lessonStars(controller.totalStars, controller.maxStars),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                    children: [
                      for (final (chapter, lessons) in controller.chapters) ...[
                        _ChapterHeader(
                          chapter: chapter,
                          stars: controller.chapterStars(lessons),
                          maxStars: lessons.length * 3,
                        ),
                        for (final lesson in lessons) ...[
                          _LessonCard(
                            lesson: lesson,
                            parts: controller.partCount(lesson),
                            stars: controller.stars(lesson),
                            onTap: () => controller.openLesson(lesson),
                          ),
                          SizedBox(height: 10.h),
                        ],
                        SizedBox(height: 10.h),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Region title with its icon and the stars collected in it.
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.chapter, required this.stars, required this.maxStars});

  final LessonChapter chapter;
  final int stars;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 4.h),
      child: Row(
        children: [
          IconBubble(icon: chapter.icon, color: AppColors.accent, size: 38),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chapter.title, style: AppStyle.title(20), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(chapter.subtitle, style: AppStyle.body(12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          StatPill(icon: Icons.star_rounded, iconColor: AppColors.star, text: AppText.lessonStars(stars, maxStars)),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.parts, required this.stars, required this.onTap});

  final Lesson lesson;
  final int parts;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = lesson.systems.last.color;
    final card = GameButton(
      onTap: onTap,
      radius: 18,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      child: Row(
        children: [
          IconBubble(icon: lesson.icon, color: color, size: 44),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title, style: AppStyle.title(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Text(lesson.subtitle, style: AppStyle.body(12), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 6.h),
                _Tag(text: AppText.lessonParts(parts), color: color),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StarRow(stars: stars, size: 18),
              SizedBox(height: 4.h),
              stars == 0
                  ? Text(
                      AppText.lessonNotStudied,
                      style: AppStyle.body(11, color: AppColors.textMuted, weight: FontWeight.w800),
                    )
                  : Icon(Icons.check_circle_rounded, size: 16.r, color: AppColors.correct),
            ],
          ),
        ],
      ),
    );
    return Semantics(label: lesson.title, child: card);
  }
}

/// Small tinted label on a lesson card ("12 cấu trúc").
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: AppStyle.body(11, color: color, weight: FontWeight.w800),
      ),
    );
  }
}
