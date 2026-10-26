import 'dart:async';

import 'package:get/get.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../dialog/quiz_result_dialog.dart';
import '../../model/body_system.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_text.dart';
import '../../service/anatomy_service.dart';
import '../../service/local_service.dart';
import '../../service/tts_service.dart';
import '../../utils/quiz_session.dart';

/// "Tap the named part" quiz on one body system (route argument).
/// The session is mutable, so the view rebuilds through `update()`.
class QuizController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();
  final _local = Get.find<LocalService>();
  final _tts = Get.find<TtsService>();
  final viewer = ViewerBridge();
  late final StreamSubscription<ViewerEvent> _sub;
  late final BodySystem system;
  late QuizSession session;

  bool loading = true;
  String? feedback;
  Timer? _advance;

  @override
  void onInit() {
    super.onInit();
    system = Get.arguments as BodySystem? ?? BodySystem.skeletal;
    _newSession();
    _sub = viewer.events.listen(_onEvent);
    viewer.setSystemVisible(system, true);
  }

  @override
  void onClose() {
    _advance?.cancel();
    _sub.cancel();
    viewer.dispose();
    super.onClose();
  }

  void _newSession() {
    session = QuizSession(_anatomy.inSystem(system));
    feedback = null;
  }

  void _onEvent(ViewerEvent event) {
    switch (event) {
      case SystemLoaded():
        loading = false;
        update();
      case PartTapped(:final partId) when partId != null:
        _onAnswer(partId);
      default:
    }
  }

  void _onAnswer(String partId) {
    if (session.finished || session.answered) return;
    switch (session.answer(partId)) {
      case AnswerResult.correct:
        viewer.flash(partId, AppColors.correct, duration: const Duration(milliseconds: 1200));
        feedback = AppText.quizCorrect;
        _scheduleNext(const Duration(milliseconds: 1200));
      case AnswerResult.wrong:
        viewer.flash(partId, AppColors.wrong);
        feedback = AppText.quizWrong(_anatomy.byId(partId)?.name);
      case AnswerResult.revealed:
        viewer.flash(partId, AppColors.wrong);
        _reveal();
    }
    update();
  }

  void _reveal() {
    final target = session.current;
    viewer.flash(target.id, AppColors.correct, duration: const Duration(milliseconds: 2200));
    viewer.focus(target.id);
    feedback = AppText.quizRevealed;
    _scheduleNext(const Duration(milliseconds: 2400));
  }

  void skip() {
    if (session.finished || session.answered) return;
    session.skip();
    _reveal();
    update();
  }

  void speakTarget() {
    if (!session.finished) _tts.speak(session.current.name);
  }

  void _scheduleNext(Duration delay) {
    _advance?.cancel();
    _advance = Timer(delay, () {
      session.next();
      feedback = null;
      viewer.resetCamera();
      update();
      if (session.finished) _finish();
    });
  }

  Future<void> _finish() async {
    final isNewBest = await _local.saveQuizScore(system, session.score);
    final again = await QuizResultDialog.show(
      score: session.score,
      total: session.length,
      best: _local.quizBest(system),
      isNewBest: isNewBest,
    );
    if (isClosed) return;
    if (again) {
      _newSession();
      update();
    } else {
      onBack();
    }
  }

  void onBack() {
    Get.back();
  }
}
