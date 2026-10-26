import 'dart:math';

import '../model/anatomy_part.dart';

enum AnswerResult { correct, wrong, revealed }

/// "Tap the named part" quiz. A question scores only when answered on the
/// first try; after [maxAttempts] wrong taps the answer is revealed.
class QuizSession {
  QuizSession(List<AnatomyPart> pool, {int length = defaultLength, Random? random, this.maxAttempts = 3})
    : questions = (List.of(pool)..shuffle(random)).take(length).toList(growable: false) {
    _results = List<bool?>.filled(questions.length, null);
  }

  static const defaultLength = 10;

  /// Result stars (0–3) for [score] out of [total]: 90% → 3, 60% → 2, 30% → 1.
  static int starsFor(int score, int total) {
    if (total <= 0) return 0;
    // Integer maths keeps the thresholds exact.
    final tenths = score * 10;
    if (tenths >= total * 9) return 3;
    if (tenths >= total * 6) return 2;
    if (tenths >= total * 3) return 1;
    return 0;
  }

  final List<AnatomyPart> questions;
  final int maxAttempts;

  int _index = 0;
  int _score = 0;
  int _attempts = 0;
  bool _answered = false;
  late final List<bool?> _results;

  int get index => _index;
  int get score => _score;
  int get attempts => _attempts;
  int get length => questions.length;
  bool get finished => _index >= questions.length;

  /// Whether the current question is settled and waiting for [next].
  bool get answered => _answered;

  AnatomyPart get current => questions[_index];

  /// Per question: true when scored, false when missed, null while unsettled.
  List<bool?> get results => List.unmodifiable(_results);

  AnswerResult answer(String partId) {
    assert(!finished && !_answered);
    if (partId == current.id) {
      if (_attempts == 0) _score++;
      _results[_index] = _attempts == 0;
      _answered = true;
      return AnswerResult.correct;
    }
    _attempts++;
    if (_attempts >= maxAttempts) {
      _results[_index] = false;
      _answered = true;
      return AnswerResult.revealed;
    }
    return AnswerResult.wrong;
  }

  /// Gives up on the current question.
  void skip() {
    _results[_index] = false;
    _answered = true;
  }

  void next() {
    _index++;
    _attempts = 0;
    _answered = false;
  }
}
