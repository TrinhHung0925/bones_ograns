import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../common/system_avatar.dart';
import '../model/body_system.dart';
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
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.7.sh),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
              child: Text(
                AppText.pickQuizSystem,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
              ),
            ),
            for (final system in BodySystem.values)
              if (anatomy.countIn(system) >= QuizSession.defaultLength)
                ListTile(
                  leading: SystemAvatar(system: system),
                  title: Text(system.label, style: TextStyle(fontSize: 16.sp)),
                  subtitle: Text(
                    '${anatomy.countIn(system)} ${AppText.parts}'
                    ' · ${AppText.quizBest(local.quizBest(system))}',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  onTap: () => Navigator.of(context).pop(system),
                ),
          ],
        ),
      ),
    );
  }
}
