import 'dart:math';

import 'package:bones_ograns/model/anatomy_part.dart';
import 'package:bones_ograns/model/body_system.dart';
import 'package:bones_ograns/utils/quiz_session.dart';
import 'package:flutter_test/flutter_test.dart';

List<AnatomyPart> _pool(int n) => [
  for (var i = 0; i < n; i++) AnatomyPart(id: 'P$i', name: 'Part $i', system: BodySystem.skeletal),
];

void main() {
  test('picks distinct questions up to the requested length', () {
    final session = QuizSession(_pool(30), length: 10, random: Random(1));
    expect(session.length, 10);
    expect(session.questions.map((p) => p.id).toSet(), hasLength(10));
  });

  test('uses the whole pool when it is shorter than the length', () {
    expect(QuizSession(_pool(4), length: 10).length, 4);
  });

  test('scores a first-try correct answer', () {
    final session = QuizSession(_pool(5), random: Random(2));
    expect(session.answer(session.current.id), AnswerResult.correct);
    expect(session.score, 1);
    expect(session.answered, isTrue);
  });

  test('a correct answer after a wrong one does not score', () {
    final session = QuizSession(_pool(5), random: Random(3));
    final wrong = session.questions.firstWhere((p) => p != session.current);
    expect(session.answer(wrong.id), AnswerResult.wrong);
    expect(session.answer(session.current.id), AnswerResult.correct);
    expect(session.score, 0);
  });

  test('reveals after maxAttempts wrong answers', () {
    final session = QuizSession(_pool(5), maxAttempts: 2, random: Random(4));
    final wrong = session.questions.firstWhere((p) => p != session.current);
    expect(session.answer(wrong.id), AnswerResult.wrong);
    expect(session.answer(wrong.id), AnswerResult.revealed);
    expect(session.answered, isTrue);
  });

  test('next resets attempts and finishes after the last question', () {
    final session = QuizSession(_pool(2), random: Random(5));
    session.answer('nope');
    session.skip();
    session.next();
    expect(session.attempts, 0);
    expect(session.answered, isFalse);
    session.skip();
    session.next();
    expect(session.finished, isTrue);
  });

  test('results track scored, missed and unsettled questions', () {
    final session = QuizSession(_pool(5), length: 4, random: Random(6));
    expect(session.results, [null, null, null, null]);

    session.answer(session.current.id);
    session.next();
    final wrong = session.questions.firstWhere((p) => p != session.current);
    session.answer(wrong.id);
    expect(session.results[1], isNull, reason: 'still being answered');
    session.answer(session.current.id);
    session.next();
    session.skip();
    session.next();

    expect(session.results, [true, false, false, null]);
  });

  test('results mark a revealed question as missed', () {
    final session = QuizSession(_pool(5), maxAttempts: 1, random: Random(7));
    final wrong = session.questions.firstWhere((p) => p != session.current);
    expect(session.answer(wrong.id), AnswerResult.revealed);
    expect(session.results.first, isFalse);
  });

  test('starsFor maps the score to 0-3 stars', () {
    expect(QuizSession.starsFor(10, 10), 3);
    expect(QuizSession.starsFor(9, 10), 3);
    expect(QuizSession.starsFor(8, 10), 2);
    expect(QuizSession.starsFor(6, 10), 2);
    expect(QuizSession.starsFor(5, 10), 1);
    expect(QuizSession.starsFor(3, 10), 1);
    expect(QuizSession.starsFor(2, 10), 0);
    expect(QuizSession.starsFor(0, 10), 0);
    expect(QuizSession.starsFor(0, 0), 0);
  });
}
