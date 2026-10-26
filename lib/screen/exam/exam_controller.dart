import 'dart:async';

import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../dialog/exam_result_dialog.dart';
import '../../model/anatomy_part.dart';
import '../../model/body_system.dart';
import '../../model/exam_config.dart';
import '../../model/exam_question.dart';
import '../../model/exam_result.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_text.dart';
import '../../service/anatomy_service.dart';
import '../../service/progress_service.dart';
import '../../service/tts_service.dart';
import '../../utils/exam_session.dart';

enum ExamFeedback { correct, wrong, timeout, skipped }

/// Mixed exam over an [ExamConfig] (route argument): custom exams, the daily
/// challenge and the mistake review. The session is mutable, so the view
/// rebuilds through `update()`; the clock rebuilds only [clockId].
class ExamController extends GetxController {
  static const clockId = 'clock';

  final _anatomy = Get.find<AnatomyService>();
  final _progress = Get.find<ProgressService>();
  final _tts = Get.find<TtsService>();
  final viewer = ViewerBridge();
  late final StreamSubscription<ViewerEvent> _sub;
  late ExamConfig config;
  late ExamSession session;

  /// Systems whose model is loaded, so 3D questions can be answered.
  final _loaded = <BodySystem>{};
  BodySystem? _shown;
  ExamFeedback? feedback;

  final _clock = Stopwatch();
  Duration _pastTime = Duration.zero;
  Timer? _ticker;
  Timer? _advance;
  bool _finishing = false;

  @override
  void onInit() {
    super.onInit();
    config = Get.arguments as ExamConfig? ?? const ExamConfig();
    if (config.kind == ExamKind.daily && config.seed == null) {
      config = config.copyWith(seed: _progress.dailySeed);
    }
    _sub = viewer.events.listen(_onEvent);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    _newSession();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    _advance?.cancel();
    _sub.cancel();
    viewer.dispose();
    super.onClose();
  }

  String get title => switch (config.kind) {
    ExamKind.daily => AppText.examDailyTitle,
    ExamKind.mistakes => AppText.examMistakesReviewTitle,
    ExamKind.custom => AppText.examTitle(config.system?.label ?? AppText.examWholeBody),
  };

  bool get empty => session.length == 0;

  ExamQuestion get current => session.current;

  /// The current 3D question waits for its system's model.
  bool get loading => !empty && !session.finished && current.needsViewer && !_loaded.contains(current.target.system);

  /// Name of the system being loaded, for the loading overlay.
  String? get loadingDetail => loading ? current.target.system.label : null;

  bool get _acceptsInput => !empty && !session.finished && !session.answered && !loading && !_finishing;

  bool get canSkip => _acceptsInput;

  /// Practice mode waits for "next" after each answer.
  bool get waitingForNext => !config.timed && !session.finished && session.answered;

  bool get isLast => session.index >= session.length - 1;

  Duration get timeLimit => config.timeLimit ?? Duration.zero;

  Duration get remaining {
    final left = timeLimit - _clock.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Share of the question's time left (1 → 0); 1 when untimed.
  double get timeFraction =>
      config.timed && timeLimit > Duration.zero ? remaining.inMilliseconds / timeLimit.inMilliseconds : 1;

  Duration get totalTime => _pastTime + _clock.elapsed;

  List<AnatomyPart> _pool() {
    if (config.partIds.isNotEmpty) {
      return [for (final id in config.partIds) ?_anatomy.byId(id)];
    }
    final system = config.system;
    return system == null ? _anatomy.parts : _anatomy.inSystem(system);
  }

  void _newSession() {
    session = ExamSession.build(
      pool: _pool(),
      allParts: _anatomy.parts,
      length: config.length,
      types: config.types,
      seed: config.seed,
      timeLimit: config.timeLimit,
    );
    _pastTime = Duration.zero;
    _finishing = false;
    _startQuestion();
  }

  void _startQuestion() {
    _advance?.cancel();
    feedback = null;
    _clock
      ..stop()
      ..reset();
    if (empty || session.finished) {
      update();
      if (!empty) _finish();
      return;
    }
    final question = current;
    final id = question.target.id;
    viewer.select(null);
    viewer.showAll();
    _showSystem(question.target.system);
    if (question.type == QuestionType.namePart) {
      viewer.isolate(id);
      viewer.select(id);
      viewer.focus(id);
    } else {
      viewer.resetCamera();
    }
    if (!loading) _clock.start();
    update();
  }

  /// Shows only [system], the one the question is about.
  void _showSystem(BodySystem system) {
    if (_shown == system) return;
    if (_shown != null) viewer.setSystemVisible(_shown!, false);
    viewer.setSystemVisible(system, true);
    _shown = system;
  }

  void _onEvent(ViewerEvent event) {
    switch (event) {
      case SystemLoaded(:final system):
        final wasLoading = loading;
        _loaded.add(system);
        if (wasLoading && !loading && !session.answered) _clock.start();
        update();
      case PartTapped(:final partId) when partId != null:
        _onTap(partId);
      default:
    }
  }

  void _tick() {
    if (!_clock.isRunning) return;
    if (config.timed && remaining == Duration.zero && _acceptsInput) {
      _settleMiss(ExamFeedback.timeout);
      return;
    }
    update([clockId]);
  }

  void _onTap(String partId) {
    if (!_acceptsInput || current.type != QuestionType.tapPart) return;
    final part = _anatomy.byId(partId);
    if (part != null) _answer(part);
  }

  void pickOption(AnatomyPart part) {
    if (!_acceptsInput || !current.hasOptions) return;
    _answer(part);
  }

  void _answer(AnatomyPart part) {
    _clock.stop();
    final question = current;
    final right = session.answer(part, remaining: config.timed ? remaining : null);
    if (question.type == QuestionType.tapPart && !right) viewer.flash(part.id, AppColors.wrong);
    feedback = right ? ExamFeedback.correct : ExamFeedback.wrong;
    _settled(right);
  }

  /// Gives up on the current question.
  void skip() {
    if (_acceptsInput) _settleMiss(ExamFeedback.skipped);
  }

  void _settleMiss(ExamFeedback kind) {
    _clock.stop();
    session.miss();
    feedback = kind;
    _settled(false);
  }

  /// Books the result and shows the answer on the model.
  void _settled(bool right) {
    final question = current;
    final target = question.target;
    if (right) {
      if (config.kind == ExamKind.mistakes) _progress.resolveMistake(target.id);
    } else {
      _progress.addMistake(target.id);
    }
    viewer.flash(target.id, AppColors.correct, duration: Duration(milliseconds: right ? 1200 : 2400));
    if (!right || question.type != QuestionType.tapPart) {
      if (question.type != QuestionType.namePart) viewer.select(target.id);
      viewer.focus(target.id);
    }
    if (config.timed) {
      _advance = Timer(Duration(milliseconds: right ? 1300 : 2400), next);
    }
    update();
  }

  /// Moves on to the next question (practice mode, or after the delay).
  void next() {
    if (session.finished || !session.answered || _finishing) return;
    _advance?.cancel();
    _pastTime += _clock.elapsed;
    session.next();
    _startQuestion();
  }

  /// Reads the English name aloud (pronunciation practice).
  void speakTarget() {
    if (!empty && !session.finished) _tts.speak(current.target.name);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    viewer.select(null);
    viewer.showAll();
    viewer.resetCamera();
    final correctXp = session.correct * ProgressService.xpPerCorrect;
    var xp = correctXp;
    var isNewBest = false;
    int? best;
    bool? dailyFirst;
    switch (config.kind) {
      case ExamKind.custom:
        isNewBest = await _progress.saveExamScore(config.scopeId, session.score);
        best = _progress.examBest(config.scopeId);
      case ExamKind.daily:
        dailyFirst = await _progress.saveDaily(session.score);
        xp = dailyFirst ? correctXp + ProgressService.xpDailyBonus : 0;
      case ExamKind.mistakes:
        break;
    }
    final levelUp = xp > 0 ? await _progress.addXp(xp) : false;
    if (xp == 0) await _progress.recordActivity();
    if (isClosed) return;
    final again = await ExamResultDialog.show(
      ExamResult(
        kind: config.kind,
        score: session.score,
        correct: session.correct,
        total: session.length,
        time: totalTime,
        xp: xp,
        missed: session.missed,
        best: best,
        isNewBest: isNewBest,
        levelUp: levelUp,
        streak: config.kind == ExamKind.daily ? _progress.streak.value : null,
        dailyFirst: dailyFirst,
      ),
    );
    if (isClosed) return;
    if (!again) return onBack();
    switch (config.kind) {
      case ExamKind.custom:
      case ExamKind.daily:
        break;
      case ExamKind.mistakes:
        final ids = [for (final m in _progress.mistakes) m.key];
        if (ids.isEmpty) return onBack();
        config = ExamConfig.mistakes(ids);
    }
    _newSession();
  }

  void onBack() {
    Get.back();
  }
}
