import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../dialog/assembly_result_dialog.dart';
import '../../model/assembly_level.dart';
import '../../model/assembly_piece.dart';
import '../../service/anatomy_service.dart';
import '../../service/local_service.dart';
import '../../service/tts_service.dart';
import '../../utils/assembly_score.dart';

/// 3D assembly game on one [AssemblyLevel] (route argument): the viewer
/// scatters the level's pieces (single parts or rigid groups) and the user
/// drags them back into place. "Next level" restarts this same screen on the
/// following level.
class AssemblyController extends GetxController {
  /// GetBuilder id of the once-a-second clock, so ticks rebuild only it.
  static const clockId = 'clock';

  /// GetBuilder id of the combo badge.
  static const comboId = 'combo';

  static const _introDuration = Duration(milliseconds: 3200);
  static const _comboDuration = Duration(milliseconds: 1400);

  final _anatomy = Get.find<AnatomyService>();
  final _local = Get.find<LocalService>();
  final _tts = Get.find<TtsService>();
  final viewer = ViewerBridge();
  late final StreamSubscription<ViewerEvent> _sub;
  late final StreamSubscription<AssemblyEvent> _gameSub;

  /// Level and detail being played (the route argument).
  late AssemblySelection selection;

  AssemblyLevel get level => selection.level;

  AssemblyDetail? get detail => selection.detail;

  List<AssemblyPiece> pieces = const [];
  Map<String, AssemblyPiece> _pieceById = const {};
  bool loading = true;
  bool finished = false;
  int placed = 0;
  int mistakes = 0;
  int hints = 0;

  /// Sum of combo bonuses this run, and the longest combo.
  int comboBonus = 0;
  int maxCombo = 0;

  /// Combo shown in the badge (0 = hidden); [comboTick] restarts its animation.
  int combo = 0;
  int comboTick = 0;

  /// First-time "how to play" overlay; the clock waits while it is open.
  bool showTutorial = false;

  /// Level card shown when a level starts.
  bool showIntro = false;

  /// Piece shown in the name banner: the last grabbed, hinted or tapped one.
  AssemblyPiece? focused;
  bool focusedByHint = false;

  final _clock = Stopwatch();
  bool _ready = false;
  bool _introShown = false;
  Timer? _ticker;
  Timer? _resultDelay;
  Timer? _introTimer;
  Timer? _comboTimer;
  final _hapticTimers = <Timer>[];

  Duration get elapsed => _clock.elapsed;

  /// Live score: placed pieces, combos, mistakes and hints (the time bonus is
  /// added at the end).
  int get score => assemblyScore(placed: placed, comboBonus: comboBonus, mistakes: mistakes, hints: hints);

  int get bestStars => _local.assemblyStars(selection.progressId);

  int? get bestSeconds => _local.assemblyBestSeconds(selection.progressId);

  int? get bestScore => _local.assemblyBestScore(selection.progressId);

  @override
  void onInit() {
    super.onInit();
    selection = Get.arguments as AssemblySelection? ?? AssemblySelection(AssemblyLevel.all.first);
    showTutorial = !_local.assemblyTutorialSeen;
    _sub = viewer.events.listen(_onEvent);
    _gameSub = viewer.assemblyEvents.listen(_onGameEvent);
    _start();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    _resultDelay?.cancel();
    _introTimer?.cancel();
    _comboTimer?.cancel();
    for (final timer in _hapticTimers) {
      timer.cancel();
    }
    _sub.cancel();
    _gameSub.cancel();
    viewer.dispose();
    super.onClose();
  }

  void _start() {
    pieces = level.resolve(_anatomy.parts, detail: detail);
    _pieceById = {for (final p in pieces) p.id: p};
    loading = true;
    finished = false;
    _ready = false;
    _introShown = false;
    placed = 0;
    mistakes = 0;
    hints = 0;
    comboBonus = 0;
    maxCombo = 0;
    combo = 0;
    focused = null;
    focusedByHint = false;
    _ticker?.cancel();
    _resultDelay?.cancel();
    _comboTimer?.cancel();
    _clock
      ..stop()
      ..reset();
    // The viewer runs commands in order, so the scatter waits for the models.
    for (final system in level.systems) {
      viewer.setSystemVisible(system, true);
    }
    viewer.assemblyStart(pieces, view: level.view);
    if (!showTutorial) _showIntro();
    update();
  }

  void _showIntro() {
    _introShown = true;
    showIntro = true;
    _introTimer?.cancel();
    _introTimer = Timer(_introDuration, dismissIntro);
  }

  void dismissIntro() {
    _introTimer?.cancel();
    if (!showIntro) return;
    showIntro = false;
    update();
  }

  void openTutorial() {
    if (showTutorial) return;
    showTutorial = true;
    showIntro = false;
    _clock.stop();
    update();
  }

  void closeTutorial() {
    if (!showTutorial) return;
    showTutorial = false;
    _local.setAssemblyTutorialSeen(true);
    _startClock();
    if (!_introShown && !finished) _showIntro();
    update();
  }

  /// Runs the clock once the pieces are out and no overlay blocks the game.
  void _startClock() {
    if (!_ready || finished || showTutorial || _clock.isRunning) return;
    _clock.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => update([clockId]));
  }

  void _onEvent(ViewerEvent event) {
    // Taps reach only placed pieces (loose ones are grabbed instead).
    if (event case PartTapped(:final partId) when partId != null) {
      _focus(partId, byHint: false);
    }
  }

  void _onGameEvent(AssemblyEvent event) {
    switch (event) {
      case AssemblyReady():
        loading = false;
        _ready = true;
        _startClock();
        update();
      case PieceGrabbed(:final partId):
        _focus(partId, byHint: false);
      case HintShown(:final partId):
        _focus(partId, byHint: true);
      case PieceSnapped(:final remaining):
        placed = pieces.length - remaining;
        HapticFeedback.mediumImpact();
        update();
      case PieceWrong():
        mistakes++;
        _haptics(const [HapticFeedback.heavyImpact, HapticFeedback.heavyImpact]);
        update();
      case ComboEvent(:final count):
        _onCombo(count);
      case AssemblyComplete():
        _haptics(const [HapticFeedback.heavyImpact, HapticFeedback.mediumImpact, HapticFeedback.lightImpact]);
        _finish();
    }
  }

  void _onCombo(int count) {
    if (count < 2 || finished) return;
    comboBonus += assemblyComboBonus(count);
    maxCombo = max(maxCombo, count);
    combo = count;
    comboTick++;
    _comboTimer?.cancel();
    _comboTimer = Timer(_comboDuration, () {
      combo = 0;
      update([comboId]);
    });
    update();
    update([comboId]);
  }

  /// Plays [pattern] 120 ms apart.
  void _haptics(List<Future<void> Function()> pattern) {
    for (var i = 0; i < pattern.length; i++) {
      if (i == 0) {
        pattern[i]();
      } else {
        _hapticTimers.add(Timer(Duration(milliseconds: 120 * i), pattern[i]));
      }
    }
  }

  /// [id] is a piece id (part or group) from the viewer, or a part id of a
  /// tapped mesh, which may belong to a group.
  void _focus(String id, {required bool byHint}) {
    final piece = _pieceById[id] ?? pieces.firstWhereOrNull((p) => p.parts.any((part) => part.id == id));
    if (piece == null) return;
    focused = piece;
    focusedByHint = byHint;
    update();
  }

  void hint() {
    if (loading || finished) return;
    hints++;
    viewer.assemblyHint();
    update();
  }

  void restart() {
    if (loading) return;
    _start();
  }

  /// Reads the English name aloud (pronunciation practice).
  void speakFocused() {
    final piece = focused;
    if (piece != null) _tts.speak(piece.nameEn);
  }

  Future<void> _finish() async {
    if (finished) return;
    finished = true;
    _clock.stop();
    _ticker?.cancel();
    _comboTimer?.cancel();
    combo = 0;
    placed = pieces.length;
    showIntro = false;
    update();
    final stars = assemblyStars(mistakes: mistakes, hints: hints);
    final time = _clock.elapsed;
    final timeBonus = assemblyTimeBonus(pieces: pieces.length, time: time);
    final total = assemblyScore(
      placed: placed,
      comboBonus: comboBonus,
      timeBonus: timeBonus,
      mistakes: mistakes,
      hints: hints,
    );
    final previousBest = bestScore;
    final isRecord = await _local.saveAssemblyResult(
      selection.progressId,
      stars: stars,
      seconds: time.inSeconds,
      score: total,
    );
    // Let the celebration in the viewer play before the dialog covers it.
    final shown = Completer<void>();
    _resultDelay = Timer(const Duration(milliseconds: 1600), shown.complete);
    await shown.future;
    if (isClosed) return;
    final next = level.next;
    final action = await AssemblyResultDialog.show(
      stars: stars,
      time: time,
      mistakes: mistakes,
      hints: hints,
      isRecord: isRecord,
      hasNext: next != null,
      score: total,
      timeBonus: timeBonus,
      maxCombo: maxCombo,
      isBestScore: previousBest == null || total > previousBest,
    );
    if (isClosed) return;
    switch (action) {
      case AssemblyResultAction.next when next != null:
        selection = AssemblySelection(next, next.defaultDetail);
        _start();
      case AssemblyResultAction.replay:
        _start();
      default:
        onBack();
    }
  }

  void onBack() {
    Get.back();
  }
}
