import 'package:bones_ograns/utils/assembly_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assemblyStars', () {
    test('a clean run earns three stars', () {
      expect(assemblyStars(mistakes: 0, hints: 0), 3);
      expect(assemblyStars(mistakes: 2, hints: 0), 3);
    });

    test('three or more mistakes cost one star', () {
      expect(assemblyStars(mistakes: 3, hints: 0), 2);
      expect(assemblyStars(mistakes: 40, hints: 0), 2);
    });

    test('any hint costs one star', () {
      expect(assemblyStars(mistakes: 0, hints: 1), 2);
      expect(assemblyStars(mistakes: 0, hints: 9), 2);
    });

    test('never drops below one star', () {
      expect(assemblyStars(mistakes: 3, hints: 1), 1);
      expect(assemblyStars(mistakes: 99, hints: 99), 1);
    });
  });

  group('assemblyScore', () {
    test('gives base points per placed piece', () {
      expect(assemblyScore(placed: 0), 0);
      expect(assemblyScore(placed: 5), 5 * assemblyPointsPerPiece);
    });

    test('adds combo and time bonuses', () {
      expect(assemblyScore(placed: 5, comboBonus: 60, timeBonus: 25), 500 + 60 + 25);
    });

    test('subtracts mistakes and hints but never goes negative', () {
      expect(assemblyScore(placed: 5, mistakes: 2, hints: 1), 500 - 2 * assemblyMistakePenalty - assemblyHintPenalty);
      expect(assemblyScore(placed: 1, mistakes: 50, hints: 50), 0);
    });

    test('combo bonus starts at two in a row and grows', () {
      expect(assemblyComboBonus(0), 0);
      expect(assemblyComboBonus(1), 0);
      expect(assemblyComboBonus(2), 20);
      expect(assemblyComboBonus(3), 40);
      expect(assemblyComboBonus(5), greaterThan(assemblyComboBonus(4)));
    });

    test('time bonus rewards finishing under par', () {
      // Par for 5 pieces is 40 s.
      expect(assemblyTimeBonus(pieces: 5, time: const Duration(seconds: 30)), 50);
      expect(assemblyTimeBonus(pieces: 5, time: const Duration(seconds: 40)), 0);
      expect(assemblyTimeBonus(pieces: 5, time: const Duration(minutes: 5)), 0);
    });
  });

  test('formatClock pads minutes and seconds', () {
    expect(formatClock(Duration.zero), '00:00');
    expect(formatClock(const Duration(seconds: 7)), '00:07');
    expect(formatClock(const Duration(minutes: 3, seconds: 45, milliseconds: 900)), '03:45');
    expect(formatClock(const Duration(minutes: 72, seconds: 1)), '72:01');
    expect(formatClock(const Duration(seconds: -5)), '00:00');
  });

  test('levels unlock one after another', () {
    expect(isAssemblyLevelUnlocked(0, const [0, 0, 0]), isTrue);
    expect(isAssemblyLevelUnlocked(1, const [0, 0, 0]), isTrue);
    expect(isAssemblyLevelUnlocked(2, const [0, 0, 0]), isFalse);
    expect(isAssemblyLevelUnlocked(2, const [0, 1, 0]), isTrue);
    expect(isAssemblyLevelUnlocked(3, const [3, 3, 0, 0]), isFalse);
  });
}
