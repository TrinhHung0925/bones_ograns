import 'package:get/get.dart';

import '../../model/lesson.dart';
import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/local_service.dart';
import '../../service/progress_service.dart';

/// "Học & Thi": the player profile (level, XP, streak, mistakes) and the
/// learning modes. Every mode is open; data refreshes when one returns.
class LearnHubController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final progress = Get.find<ProgressService>();
  final _local = Get.find<LocalService>();

  late final List<Lesson> _lessons;

  @override
  void onInit() {
    super.onInit();
    _lessons = Lesson.available(_anatomy.parts);
  }

  int get level => progress.level;

  int get xp => progress.xp.value;

  double get levelProgress => progress.levelProgress.clamp(0.0, 1.0);

  int get xpToNextLevel => progress.xpToNextLevel;

  int get streak => progress.streak.value;

  int get bestStreak => progress.bestStreak;

  int get mistakeCount => progress.mistakeCount.value;

  bool get dailyDone => progress.dailyDone;

  int? get dailyScore => progress.dailyScore;

  int get lessonCount => _lessons.length;

  /// Lessons with at least one star.
  int get lessonsDone => _lessons.where((l) => progress.lessonStars(l.id) > 0).length;

  Future<void> _open(String route) async {
    await Get.toNamed(route);
    // XP, streak, stars and mistakes may have changed.
    update();
  }

  Future<void> openDaily() => _open(AppPage.daily.routeName);

  Future<void> openLessons() => _open(AppPage.lessons.routeName);

  Future<void> openExam() => _open(AppPage.examSetup.routeName);

  Future<void> openMistakes() => _open(AppPage.mistakes.routeName);

  /// Best score of the creative bone builder (null = never tested).
  int? get builderBest => _local.boneBuilderBest;

  Future<void> openBoneBuilder() => _open(AppPage.boneBuilder.routeName);

  void onBack() {
    Get.back();
  }
}
