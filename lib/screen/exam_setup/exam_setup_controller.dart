import 'package:get/get.dart';

import '../../model/body_system.dart';
import '../../model/exam_config.dart';
import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/progress_service.dart';

/// Picks the scope, length and mode of an exam, then opens it.
class ExamSetupController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _progress = Get.find<ProgressService>();

  /// Null is the whole body.
  BodySystem? system;
  int length = ExamConfig.lengths.first;
  ExamMode mode = ExamMode.practice;

  /// Every system with parts, so new data shows up on its own.
  late final List<BodySystem> systems = [
    for (final s in BodySystem.values)
      if (_anatomy.countIn(s) > 0) s,
  ];

  int get totalParts => _anatomy.parts.length;

  int partCount(BodySystem? s) => s == null ? totalParts : _anatomy.countIn(s);

  int best(BodySystem? s) => _progress.examBest(s?.name ?? ExamConfig.wholeBodyId);

  void selectSystem(BodySystem? value) {
    system = value;
    update();
  }

  void selectLength(int value) {
    length = value;
    update();
  }

  void selectMode(ExamMode value) {
    mode = value;
    update();
  }

  Future<void> start() async {
    await Get.toNamed(
      AppPage.exam.routeName,
      arguments: ExamConfig(system: system, length: length, mode: mode),
    );
    // Bests may have changed.
    update();
  }

  void onBack() {
    Get.back();
  }
}
