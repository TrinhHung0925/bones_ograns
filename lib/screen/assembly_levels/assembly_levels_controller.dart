import 'package:get/get.dart';

import '../../dialog/assembly_detail_dialog.dart';
import '../../model/assembly_level.dart';
import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/local_service.dart';

/// Level map of the 3D assembly game: chapters of levels with saved stars,
/// best times and scores.
class AssemblyLevelsController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _local = Get.find<LocalService>();

  final chapters = AssemblyLevel.chapters;
  final levels = AssemblyLevel.all;

  /// Piece count of every level at every detail it offers (null = only one).
  late final Map<String, Map<AssemblyDetail?, int>> _pieceCounts;

  @override
  void onInit() {
    super.onInit();
    _pieceCounts = {
      for (final level in levels)
        level.id: {
          for (final detail in level.details.isEmpty ? const <AssemblyDetail?>[null] : level.details)
            detail: level.resolve(_anatomy.parts, detail: detail).length,
        },
    };
  }

  int piecesAt(AssemblyLevel level, AssemblyDetail? detail) => _pieceCounts[level.id]![detail] ?? 0;

  /// Fewest and most pieces over the level's details.
  (int, int) pieceRange(AssemblyLevel level) {
    final counts = _pieceCounts[level.id]!.values;
    return (counts.reduce((a, b) => a < b ? a : b), counts.reduce((a, b) => a > b ? a : b));
  }

  int starsAt(AssemblyLevel level, AssemblyDetail? detail) => _local.assemblyStars(level.progressId(detail));

  /// Best stars of the level over all its details.
  int stars(AssemblyLevel level) => level.details.isEmpty
      ? starsAt(level, null)
      : level.details.map((d) => starsAt(level, d)).reduce((a, b) => a > b ? a : b);

  int? bestSeconds(AssemblyLevel level) => _local.assemblyBestSeconds(level.id);

  int? bestScore(AssemblyLevel level) => _local.assemblyBestScore(level.id);

  int get totalStars => levels.fold(0, (sum, level) => sum + stars(level));

  int get maxStars => levels.length * 3;

  int chapterStars(AssemblyChapter chapter) => chapter.levels.fold(0, (sum, level) => sum + stars(level));

  int chapterMaxStars(AssemblyChapter chapter) => chapter.levels.length * 3;

  /// Every level is playable; stars and records are goals, not gates. Levels
  /// with several details ask which one first.
  Future<void> openLevel(AssemblyLevel level) async {
    AssemblyDetail? detail;
    if (level.details.length > 1) {
      detail = await AssemblyDetailDialog.show(this, level);
      if (detail == null) return;
    }
    await Get.toNamed(AppPage.assembly.routeName, arguments: AssemblySelection(level, detail));
    // Stars, times and scores may have changed.
    update();
  }

  void onBack() {
    Get.back();
  }
}
