import 'package:get/get.dart';

import '../../dialog/part_preview_dialog.dart';
import '../../model/anatomy_part.dart';
import '../../model/exam_config.dart';
import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/progress_service.dart';

typedef MistakeEntry = ({AnatomyPart part, int count});

/// The book of missed parts, most missed first, and its review exam.
class MistakesController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _progress = Get.find<ProgressService>();

  List<MistakeEntry> entries = const [];

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  /// Ids no longer in the data (regenerated assets) are left out.
  void _load() {
    entries = [
      for (final m in _progress.mistakes)
        if (_anatomy.byId(m.key) case final part?) (part: part, count: m.value),
    ];
    update();
  }

  void preview(AnatomyPart part) => PartPreviewDialog.show(part);

  Future<void> review() async {
    if (entries.isEmpty) return;
    await Get.toNamed(AppPage.exam.routeName, arguments: ExamConfig.mistakes([for (final e in entries) e.part.id]));
    _load();
  }

  void onBack() {
    Get.back();
  }
}
