import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../common/star_row.dart';
import '../../model/assembly_level.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import '../../utils/assembly_score.dart';
import 'assembly_levels_controller.dart';

class AssemblyLevelsView extends StatefulWidget {
  AssemblyLevelsView({super.key}) {
    if (!Get.isRegistered<AssemblyLevelsController>()) {
      Get.put(AssemblyLevelsController());
    }
  }

  @override
  State<AssemblyLevelsView> createState() => _AssemblyLevelsViewState();
}

class _AssemblyLevelsViewState extends State<AssemblyLevelsView> {
  var controller = Get.find<AssemblyLevelsController>();

  @override
  void dispose() {
    Get.delete<AssemblyLevelsController>();
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
          child: GetBuilder<AssemblyLevelsController>(
            builder: (controller) => Column(
              children: [
                GameHeader(
                  title: AppText.assemblyLevelsTitle,
                  subtitle: AppText.assemblyLevelsSubtitle,
                  onBack: controller.onBack,
                  actions: [
                    StatPill(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.star,
                      text: AppText.assemblyStarTotal(controller.totalStars, controller.maxStars),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                    children: [
                      for (final chapter in controller.chapters) ...[
                        _ChapterHeader(
                          chapter: chapter,
                          stars: controller.chapterStars(chapter),
                          maxStars: controller.chapterMaxStars(chapter),
                        ),
                        for (final level in chapter.levels) ...[
                          _LevelCard(
                            number: chapter.levels.indexOf(level) + 1,
                            level: level,
                            pieces: controller.pieceCounts[level.id] ?? 0,
                            stars: controller.stars(level),
                            bestSeconds: controller.bestSeconds(level),
                            bestScore: controller.bestScore(level),
                            unlocked: controller.isUnlocked(level),
                            onTap: () => controller.openLevel(level),
                          ),
                          SizedBox(height: 12.h),
                        ],
                        SizedBox(height: 8.h),
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

/// Chapter title with its icon and the stars collected in it.
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.chapter, required this.stars, required this.maxStars});

  final AssemblyChapter chapter;
  final int stars;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, top: 4.h),
      child: Row(
        children: [
          IconBubble(icon: chapter.icon, color: AppColors.accent, size: 40),
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
          StatPill(
            icon: Icons.star_rounded,
            iconColor: AppColors.star,
            text: AppText.assemblyChapterStars(stars, maxStars),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.number,
    required this.level,
    required this.pieces,
    required this.stars,
    required this.bestSeconds,
    required this.bestScore,
    required this.unlocked,
    required this.onTap,
  });

  final int number;
  final AssemblyLevel level;
  final int pieces;
  final int stars;
  final int? bestSeconds;
  final int? bestScore;
  final bool unlocked;
  final VoidCallback onTap;

  Color get _difficultyColor => switch (level.difficulty) {
    AssemblyDifficulty.easy => AppColors.correct,
    AssemblyDifficulty.medium => AppColors.accent,
    AssemblyDifficulty.hard => AppColors.wrong,
    AssemblyDifficulty.extreme => AppColors.reproductive,
  };

  @override
  Widget build(BuildContext context) {
    final card = GameButton(
      onTap: unlocked ? onTap : null,
      tooltip: unlocked ? null : AppText.assemblyLocked,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconBubble(icon: level.icon, color: unlocked ? _difficultyColor : AppColors.textMuted, size: 52),
              Positioned(
                left: -4.r,
                top: -4.r,
                child: Container(
                  width: 22.r,
                  height: 22.r,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Text('$number', style: AppStyle.button(12)),
                ),
              ),
            ],
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level.title, style: AppStyle.title(19), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Text(level.subtitle, style: AppStyle.body(12), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    _Tag(text: AppText.assemblyPieces(pieces), color: AppColors.textSecondary),
                    SizedBox(width: 6.w),
                    _Tag(text: level.difficulty.label, color: _difficultyColor),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (unlocked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StarRow(stars: stars, size: 20),
                SizedBox(height: 4.h),
                Text(
                  bestSeconds == null ? AppText.assemblyNotPlayed : formatClock(Duration(seconds: bestSeconds!)),
                  style: AppStyle.body(12, color: AppColors.textMuted, weight: FontWeight.w800),
                ),
                if (bestScore != null)
                  Text(
                    '${AppText.assemblyBestScore} $bestScore',
                    style: AppStyle.body(11, color: AppColors.accent, weight: FontWeight.w800),
                  ),
              ],
            )
          else
            Icon(Icons.lock_rounded, size: 26.r, color: AppColors.textMuted),
        ],
      ),
    );
    return Semantics(
      label: level.title,
      child: unlocked ? card : Opacity(opacity: 0.55, child: card),
    );
  }
}

/// Small outlined label on a level card ("27 mảnh", "Khó").
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
