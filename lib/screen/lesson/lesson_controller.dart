import 'dart:async';

import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../dialog/lesson_result_dialog.dart';
import '../../model/anatomy_part.dart';
import '../../model/body_system.dart';
import '../../model/lesson.dart';
import '../../model/part_state.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_text.dart';
import '../../service/anatomy_service.dart';
import '../../service/progress_service.dart';
import '../../service/tts_service.dart';
import '../../utils/quiz_session.dart';

enum LessonPhase { study, check }

enum LessonFeedback { correct, wrong, revealed }

/// Lesson player (route argument: a [Lesson]). Study phase: each part in
/// turn is isolated, focused and named. Check phase: a short "tap the named
/// part" quiz over the lesson's parts, scored in stars and XP. The state is
/// mutable, so the view rebuilds through `update()`.
class LessonController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _progress = Get.find<ProgressService>();
  final _tts = Get.find<TtsService>();
  final viewer = ViewerBridge();
  late final StreamSubscription<ViewerEvent> _sub;

  late final Lesson lesson;
  late final List<AnatomyPart> parts;

  /// Systems shown in the viewer (only those with a model in the data set).
  late final List<BodySystem> systems;
  final _pendingSystems = <BodySystem>{};

  bool loading = true;
  LessonPhase phase = LessonPhase.study;

  /// Part being studied.
  int index = 0;

  QuizSession? session;
  String? feedback;
  LessonFeedback? feedbackKind;
  Timer? _advance;

  AnatomyPart get current => parts[index];

  bool get isFirst => index == 0;

  bool get isLast => index == parts.length - 1;

  @override
  void onInit() {
    super.onInit();
    lesson = Get.arguments as Lesson? ?? Lesson.available(_anatomy.parts).first;
    parts = lesson.resolve(_anatomy.parts);
    systems = [
      for (final s in lesson.shownSystems(parts))
        if (_anatomy.countIn(s) > 0) s,
    ];
    _sub = viewer.events.listen(_onEvent);
    _pendingSystems.addAll(systems);
    for (final system in systems) {
      viewer.setSystemVisible(system, true);
    }
  }

  @override
  void onClose() {
    _advance?.cancel();
    _sub.cancel();
    viewer.dispose();
    super.onClose();
  }

  void _onEvent(ViewerEvent event) {
    switch (event) {
      case SystemLoaded(:final system):
        _pendingSystems.remove(system);
        if (loading && _pendingSystems.isEmpty) {
          loading = false;
          _showStudyPart();
          update();
        }
      case ViewerError():
        // Show whatever loaded rather than spinning forever.
        if (loading) {
          loading = false;
          _showStudyPart();
          update();
        }
      case PartTapped(:final partId, :final doubleTap) when partId != null:
        if (doubleTap) {
          viewer.focus(partId);
        } else if (phase == LessonPhase.check) {
          _onAnswer(partId);
        }
      default:
    }
  }

  // ---------------------------------------------------------------------
  // Study phase.
  // ---------------------------------------------------------------------

  /// Ghosts everything but the current part, then frames and names it.
  void _showStudyPart() {
    final id = current.id;
    viewer.isolate(id);
    viewer.select(id);
    viewer.focus(id);
    viewer.flash(id, AppColors.accent, duration: const Duration(milliseconds: 1100));
  }

  void goTo(int i) {
    if (loading || phase != LessonPhase.study || i < 0 || i >= parts.length) return;
    index = i;
    _showStudyPart();
    update();
  }

  void prev() => goTo(index - 1);

  /// Next part, or the check after the last one.
  void next() {
    if (isLast) {
      startCheck();
    } else {
      goTo(index + 1);
    }
  }

  /// Re-frames the current part (after the user moved the camera away).
  void refocus() {
    if (phase == LessonPhase.study && !loading) viewer.focus(current.id);
  }

  /// Reads the English name aloud (pronunciation practice).
  void speak() {
    final session = this.session;
    final part = switch (phase) {
      LessonPhase.study => current,
      LessonPhase.check => session == null || session.finished ? null : session.current,
    };
    if (part != null) _tts.speak(part.name);
  }

  // ---------------------------------------------------------------------
  // Check phase.
  // ---------------------------------------------------------------------

  void startCheck() {
    if (loading) return;
    _advance?.cancel();
    phase = LessonPhase.check;
    session = QuizSession(parts, length: Lesson.checkLength);
    _clearFeedback();
    // Only the lesson's parts stay solid (and tappable); the rest is context.
    viewer.select(null);
    viewer.isolate(parts.first.id);
    for (final p in parts.skip(1)) {
      viewer.setPartState(p.id, PartState.visible);
    }
    viewer.resetCamera();
    update();
  }

  void _onAnswer(String partId) {
    final session = this.session;
    if (session == null || session.finished || session.answered) return;
    switch (session.answer(partId)) {
      case AnswerResult.correct:
        viewer.flash(partId, AppColors.correct, duration: const Duration(milliseconds: 1200));
        feedback = AppText.quizCorrect;
        feedbackKind = LessonFeedback.correct;
        _settled();
        _scheduleNext(const Duration(milliseconds: 1200));
      case AnswerResult.wrong:
        viewer.flash(partId, AppColors.wrong);
        feedback = AppText.quizWrong(_anatomy.byId(partId)?.displayName);
        feedbackKind = LessonFeedback.wrong;
      case AnswerResult.revealed:
        viewer.flash(partId, AppColors.wrong);
        _reveal();
    }
    update();
  }

  void _reveal() {
    final target = session!.current;
    viewer.flash(target.id, AppColors.correct, duration: const Duration(milliseconds: 2200));
    viewer.focus(target.id);
    feedback = AppText.quizRevealed;
    feedbackKind = LessonFeedback.revealed;
    _settled();
    _scheduleNext(const Duration(milliseconds: 2400));
  }

  /// A question not scored on the first try goes into the mistake book.
  void _settled() {
    final session = this.session!;
    if (session.results[session.index] == false) _progress.addMistake(session.current.id);
  }

  void skip() {
    final session = this.session;
    if (loading || session == null || session.finished || session.answered) return;
    session.skip();
    _reveal();
    update();
  }

  void _clearFeedback() {
    feedback = null;
    feedbackKind = null;
  }

  void _scheduleNext(Duration delay) {
    _advance?.cancel();
    _advance = Timer(delay, () {
      final session = this.session!;
      session.next();
      _clearFeedback();
      viewer.resetCamera();
      update();
      if (session.finished) _finish();
    });
  }

  Future<void> _finish() async {
    final session = this.session!;
    final stars = QuizSession.starsFor(session.score, session.length);
    final isNewBest = await _progress.saveLessonStars(lesson.id, stars);
    final xp = session.score * ProgressService.xpPerCorrect + stars * ProgressService.xpPerStar;
    final levelUp = await _progress.addXp(xp);
    final again = await LessonResultDialog.show(
      title: lesson.title,
      stars: stars,
      score: session.score,
      total: session.length,
      xp: xp,
      isNewBest: isNewBest,
      newLevel: levelUp ? _progress.level : null,
    );
    if (isClosed) return;
    if (again) {
      restudy();
    } else {
      onBack();
    }
  }

  /// Back to the first part of the study phase.
  void restudy() {
    _advance?.cancel();
    phase = LessonPhase.study;
    session = null;
    _clearFeedback();
    index = 0;
    viewer.showAll();
    _showStudyPart();
    update();
  }

  void onBack() {
    Get.back();
  }
}
