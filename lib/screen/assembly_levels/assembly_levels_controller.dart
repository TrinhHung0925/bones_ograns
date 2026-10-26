import 'package:get/get.dart';

import '../../model/assembly_level.dart';
import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/local_service.dart';
import '../../utils/assembly_score.dart';

/// Level map of the 3D assembly game: chapters of levels with saved stars,
/// best times and scores.
class AssemblyLevelsController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _local = Get.find<LocalService>();

  final chapters = AssemblyLevel.chapters;
  final levels = AssemblyLevel.all;
  late final Map<String, int> pieceCounts;

  @override
  void onInit() {
    super.onInit();
    pieceCounts = {for (final level in levels) level.id: level.resolve(_anatomy.parts).length};
  }

  int stars(AssemblyLevel level) => _local.assemblyStars(level.id);

  int? bestSeconds(AssemblyLevel level) => _local.assemblyBestSeconds(level.id);

  int? bestScore(AssemblyLevel level) => _local.assemblyBestScore(level.id);

  int get totalStars => levels.fold(0, (sum, level) => sum + stars(level));

  int get maxStars => levels.length * 3;

  int chapterStars(AssemblyChapter chapter) => chapter.levels.fold(0, (sum, level) => sum + stars(level));

  int chapterMaxStars(AssemblyChapter chapter) => chapter.levels.length * 3;

  /// The first two levels of every chapter are open; the others need a star
  /// on the level before them.
  bool isUnlocked(AssemblyLevel level) {
    final chapter = level.chapter;
    return isAssemblyLevelUnlocked(chapter.levels.indexOf(level), chapter.levels.map(stars).toList());
  }

  Future<void> openLevel(AssemblyLevel level) async {
    if (!isUnlocked(level)) return;
    await Get.toNamed(AppPage.assembly.routeName, arguments: level);
    // Stars and times may have changed, and with them the unlocked levels.
    update();
  }

  void onBack() {
    Get.back();
  }
}
