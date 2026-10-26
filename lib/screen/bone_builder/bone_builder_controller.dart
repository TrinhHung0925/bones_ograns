import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../dialog/bone_builder_result_dialog.dart';
import '../../model/assembly_piece.dart';
import '../../model/bone_builder.dart';
import '../../service/anatomy_service.dart';
import '../../service/local_service.dart';
import '../../service/progress_service.dart';

/// "Xếp xương sáng tạo": the player stacks big skeletal pieces into the
/// sturdiest structure they can, then a physics test in the viewer (settle,
/// earthquake, heavy ball) scores it; the anatomical skeleton scores 100.
class BoneBuilderController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _local = Get.find<LocalService>();
  final _progress = Get.find<ProgressService>();
  final viewer = ViewerBridge();
  late final StreamSubscription<ViewerEvent> _sub;
  late final StreamSubscription<BuilderEvent> _builderSub;

  List<AssemblyPiece> pieces = const [];
  Map<String, AssemblyPiece> _pieceById = const {};

  bool loading = true;

  /// Piece the rotate toolbar acts on, or null.
  AssemblyPiece? selected;
  int placed = 0;
  bool canUndo = false;

  /// True from "Kiểm tra độ cứng" until the result dialog closes.
  bool testing = false;
  BuilderPhase? phase;

  /// Rotate by 15° instead of 90°.
  bool fineStep = false;

  int? get best => _local.boneBuilderBest;

  bool get canTest => !loading && !testing && placed >= BoneBuilder.minPlaced;

  int get rotateStep => fineStep ? BoneBuilder.fineStep : BoneBuilder.coarseStep;

  @override
  void onInit() {
    super.onInit();
    _sub = viewer.events.listen(_onEvent);
    _builderSub = viewer.builderEvents.listen(_onBuilderEvent);
    pieces = BoneBuilder.resolve(_anatomy.parts);
    _pieceById = {for (final p in pieces) p.id: p};
    viewer.builderStart([for (final p in pieces) BoneBuilder.toJson(p)]);
  }

  @override
  void onClose() {
    _sub.cancel();
    _builderSub.cancel();
    viewer.builderStop();
    viewer.dispose();
    super.onClose();
  }

  void _onEvent(ViewerEvent event) {
    // A failed test must not leave the controls hidden forever.
    if (event is ViewerError && testing) {
      testing = false;
      phase = null;
      update();
    }
  }

  void _onBuilderEvent(BuilderEvent event) {
    switch (event) {
      case BuilderReady():
        loading = false;
        update();
      case BuilderSelected(:final id):
        selected = id == null ? null : _pieceById[id];
        update();
      case BuilderChanged(placed: final count, canUndo: final undo):
        placed = count;
        canUndo = undo;
        update();
      case BuilderTesting(phase: final p):
        testing = true;
        phase = p;
        if (p != BuilderPhase.settle) HapticFeedback.heavyImpact();
        update();
      case BuilderResult():
        _showResult(event);
    }
  }

  void rotate(String axis) {
    if (selected == null || testing) return;
    viewer.builderRotate(axis, rotateStep);
  }

  void toggleFineStep() {
    fineStep = !fineStep;
    update();
  }

  void undo() {
    if (!canUndo || testing) return;
    viewer.builderUndo();
  }

  void reset() {
    if (loading || testing) return;
    viewer.builderReset();
  }

  void anatomical() {
    if (loading || testing) return;
    viewer.builderAnatomical();
  }

  void runTest() {
    if (!canTest) return;
    testing = true;
    phase = BuilderPhase.settle;
    selected = null;
    HapticFeedback.mediumImpact();
    viewer.builderTest();
    update();
  }

  Future<void> _showResult(BuilderResult result) async {
    final previousBest = best;
    final stars = BoneBuilder.stars(result.score);
    final xp = stars * ProgressService.xpPerStar;
    phase = null;
    update();
    final isBest = await _local.saveBoneBuilderScore(result.score);
    if (xp > 0) await _progress.addXp(xp);
    if (isClosed) return;
    final action = await BoneBuilderResultDialog.show(
      result: result,
      stars: stars,
      xp: xp,
      isNewBest: isBest,
      previousBest: previousBest,
    );
    if (isClosed) return;
    testing = false;
    selected = null;
    switch (action) {
      case BoneBuilderResultAction.edit:
        viewer.builderEdit();
      case BoneBuilderResultAction.playAgain:
        viewer.builderReset();
    }
    update();
  }

  void onBack() {
    Get.back();
  }
}
