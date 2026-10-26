import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/game_widgets.dart';
import '../model/body_system.dart';
import '../resource/app_colors.dart';
import '../resource/app_style.dart';
import '../resource/app_text.dart';
import '../service/anatomy_service.dart';
import '../service/local_service.dart';
import '../utils/quiz_session.dart';

/// Picks the body system to quiz on; resolves to null when dismissed.
class QuizSystemDialog extends StatelessWidget {
  const QuizSystemDialog({super.key, required this.anatomy});

  final AnatomyService anatomy;

  static Future<BodySystem?> show(AnatomyService anatomy) {
    return showModalBottomSheet<BodySystem>(
      context: Get.context!,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => QuizSystemDialog(anatomy: anatomy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = Get.find<LocalService>();
    final systems = [
      for (final system in BodySystem.values)
        if (anatomy.countIn(system) >= QuizSession.defaultLength) system,
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.75.sh),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(AppText.pickQuizSystem),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: systems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12.h,
                    crossAxisSpacing: 10.w,
                    mainAxisExtent: 128.h,
                  ),
                  itemBuilder: (context, i) {
                    final system = systems[i];
                    return _SystemTile(
                      system: system,
                      best: local.quizBest(system),
                      onTap: () => Navigator.of(context).pop(system),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemTile extends StatelessWidget {
  const _SystemTile({required this.system, required this.best, required this.onTap});

  final BodySystem system;
  final int best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: GameButton(
        onTap: onTap,
        radius: 20,
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 12.h),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBubble(icon: system.icon, color: system.color, size: 46),
              SizedBox(height: 8.h),
              Text(system.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppStyle.title(15)),
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 14.r, color: best > 0 ? AppColors.star : AppColors.textMuted),
                  SizedBox(width: 2.w),
                  Flexible(
                    child: Text(
                      AppText.quizBestOf(best, QuizSession.defaultLength),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.body(11, color: AppColors.textMuted, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
