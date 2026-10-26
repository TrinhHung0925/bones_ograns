import 'dart:math';

import '../model/anatomy_part.dart';

enum AnswerResult { correct, wrong, revealed }

/// "Tap the named part" quiz. A question scores only when answered on the
/// first try; after [maxAttempts] wrong taps the answer is revealed.
class QuizSession {
  QuizSession(List<AnatomyPart> pool,
      {int length = defaultLength, Random? random, this.maxAttempts = 3})
      : questions = (List.of(pool)..shuffle(random)).take(length).toList(growable: false);

  static const defaultLength = 10;

  final List<AnatomyPart> questions;
  final int maxAttempts;

  int _index = 0;
  int _score = 0;
  int _attempts = 0;
  bool _answered = false;

  int get index => _index;
  int get score => _score;
  int get attempts => _attempts;
  int get length => questions.length;
  bool get finished => _index >= questions.length;

  /// Whether the current question is settled and waiting for [next].
  bool get answered => _answered;

  AnatomyPart get current => questions[_index];

  AnswerResult answer(String partId) {
    assert(!finished && !_answered);
    if (partId == current.id) {
      if (_attempts == 0) _score++;
      _answered = true;
      return AnswerResult.correct;
    }
    _attempts++;
    if (_attempts >= maxAttempts) {
      _answered = true;
      return AnswerResult.revealed;
    }
    return AnswerResult.wrong;
  }

  /// Gives up on the current question.
  void skip() => _answered = true;

  void next() {
    _index++;
    _attempts = 0;
    _answered = false;
  }
}
