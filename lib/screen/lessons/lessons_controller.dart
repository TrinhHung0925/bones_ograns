import 'package:get/get.dart';

import '../../model/lesson.dart';
import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/progress_service.dart';

/// Lessons by body region: chapters of lessons with their saved stars.
/// Every lesson is open; stars are goals, not gates.
class LessonsController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _progress = Get.find<ProgressService>();

  /// Chapters with the lessons that have enough parts in the data set.
  late final List<(LessonChapter, List<Lesson>)> chapters;

  @override
  void onInit() {
    super.onInit();
    chapters = [
      for (final chapter in Lesson.chapters)
        if (chapter.lessons.where((l) => l.isAvailableIn(_anatomy.parts)).toList() case final lessons
            when lessons.isNotEmpty)
          (chapter, lessons),
    ];
  }

  int partCount(Lesson lesson) => lesson.resolve(_anatomy.parts).length;

  int stars(Lesson lesson) => _progress.lessonStars(lesson.id);

  int chapterStars(List<Lesson> lessons) => lessons.fold(0, (sum, l) => sum + stars(l));

  int get totalStars => chapters.fold(0, (sum, c) => sum + chapterStars(c.$2));

  int get maxStars => chapters.fold(0, (sum, c) => sum + c.$2.length * 3);

  Future<void> openLesson(Lesson lesson) async {
    await Get.toNamed(AppPage.lesson.routeName, arguments: lesson);
    // Stars may have changed.
    update();
  }

  void onBack() {
    Get.back();
  }
}
