import 'anatomy_part.dart';
import 'exam_config.dart';

/// One exam question. [options] holds the 4 shuffled choices (the target
/// among them) for every type but [QuestionType.tapPart].
class ExamQuestion {
  const ExamQuestion({required this.type, required this.target, this.options = const []});

  final QuestionType type;
  final AnatomyPart target;
  final List<AnatomyPart> options;

  bool get hasOptions => type != QuestionType.tapPart;

  /// Whether answering needs the 3D model on screen (loaded).
  bool get needsViewer => type == QuestionType.tapPart || type == QuestionType.namePart;

  /// Text of an option: English for [QuestionType.viToEn], else Vietnamese.
  String optionLabel(AnatomyPart part) => type == QuestionType.viToEn ? part.name : part.displayName;

  /// Term shown in the question; empty for [QuestionType.namePart], whose
  /// prompt is the highlighted part.
  String get prompt => switch (type) {
    QuestionType.tapPart || QuestionType.viToEn => target.displayName,
    QuestionType.enToVi => target.name,
    QuestionType.namePart => '',
  };
}
