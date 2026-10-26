import 'dart:math';

import '../model/anatomy_part.dart';
import '../model/body_system.dart';
import '../model/exam_config.dart';
import '../model/exam_question.dart';

/// A mixed-question exam (see [QuestionType]). Each question takes one
/// answer. A correct answer scores [basePoints], plus up to [maxTimeBonus]
/// for the time left when the exam is timed.
class ExamSession {
  ExamSession(this.questions, {this.timeLimit}) {
    _results = List<bool?>.filled(questions.length, null);
    _chosen = List<String?>.filled(questions.length, null);
  }

  /// Builds [length] questions about [pool] (fewer when the pool is small).
  /// Distractors come from [allParts] of the target's system. The same
  /// [seed] and data always give the same exam.
  factory ExamSession.build({
    required List<AnatomyPart> pool,
    required List<AnatomyPart> allParts,
    required int length,
    List<QuestionType> types = QuestionType.values,
    int? seed,
    Duration? timeLimit,
  }) {
    final builder = _QuestionBuilder(allParts, seed == null ? Random() : Random(seed));
    return ExamSession(builder.build(pool, length, types), timeLimit: timeLimit);
  }

  static const basePoints = 100;
  static const maxTimeBonus = 50;

  /// Points of a correct answer given with [remaining] of [limit] left.
  static int pointsFor({Duration? remaining, Duration? limit}) {
    if (remaining == null || limit == null || limit <= Duration.zero) return basePoints;
    final ratio = (remaining.inMilliseconds / limit.inMilliseconds).clamp(0.0, 1.0);
    return basePoints + (maxTimeBonus * ratio).round();
  }

  final List<ExamQuestion> questions;

  /// Per-question countdown; null in practice mode.
  final Duration? timeLimit;

  int _index = 0;
  int _score = 0;
  int _correct = 0;
  int _lastPoints = 0;
  bool _answered = false;
  late final List<bool?> _results;
  late final List<String?> _chosen;

  int get index => _index;
  int get score => _score;
  int get correct => _correct;
  int get length => questions.length;
  bool get finished => _index >= questions.length;

  /// Whether the current question is settled and waiting for [next].
  bool get answered => _answered;

  /// Points earned by the last answer (0 when wrong).
  int get lastPoints => _lastPoints;

  ExamQuestion get current => questions[_index];

  /// Part picked for the current question; null before answering or on timeout.
  String? get chosenId => finished ? null : _chosen[_index];

  /// Per question: true when right, false when wrong or missed, null while open.
  List<bool?> get results => List.unmodifiable(_results);

  /// Targets of the wrong or missed questions, in order.
  List<AnatomyPart> get missed => [
    for (var i = 0; i < questions.length; i++)
      if (_results[i] == false) questions[i].target,
  ];

  /// Answers the current question with [picked]. Parts sharing the target's
  /// name count as right (duplicate meshes). Returns whether it was right.
  bool answer(AnatomyPart picked, {Duration? remaining}) {
    assert(!finished && !_answered);
    final target = current.target;
    final right = picked.id == target.id || current.optionLabel(picked) == current.optionLabel(target);
    _chosen[_index] = picked.id;
    _results[_index] = right;
    _answered = true;
    _lastPoints = right ? pointsFor(remaining: remaining, limit: timeLimit) : 0;
    _score += _lastPoints;
    if (right) _correct++;
    return right;
  }

  /// Time ran out, or the user skipped: the question is missed.
  void miss() {
    assert(!finished && !_answered);
    _results[_index] = false;
    _answered = true;
    _lastPoints = 0;
  }

  void next() {
    _index++;
    _answered = false;
    _lastPoints = 0;
  }
}

/// Picks targets and question types and finds plausible distractors.
class _QuestionBuilder {
  _QuestionBuilder(List<AnatomyPart> allParts, this.random) {
    final sorted = List.of(allParts)..sort((a, b) => a.id.compareTo(b.id));
    for (final part in sorted) {
      if (part.hasVietnamese) (_named[part.system] ??= []).add(part);
    }
  }

  final Random random;
  final _named = <BodySystem, List<AnatomyPart>>{};
  final _tokens = <String, Set<String>>{};
  final _used = {for (final t in QuestionType.values) t: 0};

  static const _stopWords = {'of', 'the', 'and', 'to', 'in', 'for', 'with', 'left', 'right', 'part', 'set'};

  List<ExamQuestion> build(List<AnatomyPart> pool, int length, List<QuestionType> types) {
    // Sorted first so that the shuffle, and so the exam, depends only on the seed.
    final targets = List.of(pool)..sort((a, b) => a.id.compareTo(b.id));
    targets.shuffle(random);
    final questions = <ExamQuestion>[];
    final askedNames = <String>{};
    for (final target in targets) {
      if (questions.length >= length) break;
      // The same name twice would be the same question.
      if (!askedNames.add(_norm(target.displayName))) continue;
      final question = _question(target, types);
      if (question != null) questions.add(question);
    }
    return questions;
  }

  ExamQuestion? _question(AnatomyPart target, List<QuestionType> types) {
    final candidates = types.where((t) => _possible(t, target)).toList();
    while (candidates.isNotEmpty) {
      // The least used type keeps the exam mixed; ties are random.
      final fewest = candidates.map((t) => _used[t]!).reduce(min);
      final best = candidates.where((t) => _used[t] == fewest).toList();
      final type = best[random.nextInt(best.length)];
      if (type == QuestionType.tapPart) {
        _used[type] = _used[type]! + 1;
        return ExamQuestion(type: type, target: target);
      }
      final distractors = _distractors(type, target);
      if (distractors != null) {
        _used[type] = _used[type]! + 1;
        final options = [target, ...distractors]..shuffle(random);
        return ExamQuestion(type: type, target: target, options: options);
      }
      candidates.remove(type);
    }
    return null;
  }

  bool _possible(QuestionType type, AnatomyPart target) => switch (type) {
    // Skin is see-through and the viewer never picks it.
    QuestionType.tapPart => target.system != BodySystem.integumentary,
    // 4 options need the target plus 3 other named parts of its system.
    _ => target.hasVietnamese && (_named[target.system]?.length ?? 0) >= 4,
  };

  /// Three parts of the target's system with distinct labels, most similar
  /// names first (same words, same side), with some randomness for variety.
  /// Null when the system cannot give three.
  List<AnatomyPart>? _distractors(QuestionType type, AnatomyPart target) {
    String option(AnatomyPart p) => _norm(type == QuestionType.viToEn ? p.name : p.displayName);
    String prompt(AnatomyPart p) => _norm(type == QuestionType.viToEn ? p.displayName : p.name);

    final targetPrompt = prompt(target);
    final targetTokens = _tokensOf(target);
    final targetSide = _side(target.name);
    final targetHead = _head(target.name);
    final scored = <(AnatomyPart, double)>[];
    for (final part in _named[target.system] ?? const <AnatomyPart>[]) {
      if (part.id == target.id) continue;
      // A distractor with the target's prompt term would also be right.
      if (prompt(part) == targetPrompt) continue;
      final tokens = _tokensOf(part);
      var similarity = 1.5 * tokens.intersection(targetTokens).length;
      if (targetHead != null && _head(part.name) == targetHead) similarity += 1.5;
      if (targetSide != null && _side(part.name) == targetSide) similarity += 1;
      scored.add((part, similarity + random.nextDouble() * 1.2));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    final labels = {option(target)};
    final picked = <AnatomyPart>[];
    for (final (part, _) in scored) {
      if (!labels.add(option(part))) continue;
      picked.add(part);
      if (picked.length == 3) return picked;
    }
    return null;
  }

  Set<String> _tokensOf(AnatomyPart part) => _tokens[part.id] ??= {
    for (final word in _words(part.name))
      if (!_stopWords.contains(word)) word,
  };

  static Iterable<String> _words(String name) =>
      name.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 1);

  /// 'left', 'right' or null.
  static String? _side(String name) {
    final words = _words(name).toSet();
    if (words.contains('left')) return 'left';
    if (words.contains('right')) return 'right';
    return null;
  }

  /// Kind word of a name, e.g. "artery" in "Left inferior thyroid artery":
  /// the last word before any "of …".
  static String? _head(String name) {
    final words = _words(name).toList();
    final of = words.indexOf('of');
    final head = (of > 0 ? words.sublist(0, of) : words).where((w) => w != 'left' && w != 'right');
    return head.isEmpty ? null : head.last;
  }

  static String _norm(String label) => label.trim().toLowerCase();
}
