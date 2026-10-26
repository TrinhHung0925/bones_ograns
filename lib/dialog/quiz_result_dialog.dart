import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../resource/app_text.dart';

/// End-of-quiz summary; resolves to true when the user wants to play again.
class QuizResultDialog extends StatelessWidget {
  const QuizResultDialog({
    super.key,
    required this.score,
    required this.total,
    required this.best,
    required this.isNewBest,
  });

  final int score;
  final int total;
  final int best;
  final bool isNewBest;

  static Future<bool> show({
    required int score,
    required int total,
    required int best,
    required bool isNewBest,
  }) async {
    final again = await Get.dialog<bool>(
      QuizResultDialog(score: score, total: total, best: best, isNewBest: isNewBest),
      barrierDismissible: false,
    );
    return again ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppText.quizResult, style: TextStyle(fontSize: 20.sp)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppText.quizResultBody(score, total), style: TextStyle(fontSize: 15.sp)),
          SizedBox(height: 8.h),
          Text(
            isNewBest ? AppText.quizNewBest : AppText.quizBest(best),
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text(AppText.quizExit, style: TextStyle(fontSize: 14.sp)),
        ),
        FilledButton(
          onPressed: () => Get.back(result: true),
          child: Text(AppText.quizAgain, style: TextStyle(fontSize: 14.sp)),
        ),
      ],
    );
  }
}
