import 'package:get/get.dart';

import '../../model/exam_config.dart';
import '../../route.dart';
import '../../service/progress_service.dart';

/// Today's challenge: the same 10 mixed questions for every player, timed.
/// Only the first play of the day pays the bonus.
class DailyController extends GetxController {
  final progress = Get.find<ProgressService>();

  bool get done => progress.dailyDone;

  int? get todayScore => progress.dailyScore;

  /// Today as dd/mm/yyyy.
  String get date {
    final parts = progress.today.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : progress.today;
  }

  Future<void> start() async {
    await Get.toNamed(AppPage.exam.routeName, arguments: ExamConfig.daily(seed: progress.dailySeed));
    update();
  }

  void onBack() {
    Get.back();
  }
}
