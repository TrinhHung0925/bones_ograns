import 'anatomy_part.dart';
import 'body_system.dart';

/// One draggable piece of the assembly game: a single part, or a named group
/// of parts that move together as one rigid piece.
class AssemblyPiece {
  const AssemblyPiece({required this.id, required this.parts, required this.nameVi, required this.nameEn});

  /// A piece made of exactly one part; its id is the part id.
  factory AssemblyPiece.single(AnatomyPart part) =>
      AssemblyPiece(id: part.id, parts: [part], nameVi: part.displayName, nameEn: part.name);

  /// Part id for a single piece, group id otherwise. Viewer events carry it.
  final String id;
  final List<AnatomyPart> parts;
  final String nameVi;
  final String nameEn;

  bool get isGroup => parts.length > 1 || (parts.isNotEmpty && parts.first.id != id);

  BodySystem get system => parts.isEmpty ? BodySystem.other : parts.first.system;

  /// What the viewer expects in `assemblyStart`: the part id for a single
  /// piece, `{id, parts}` for a group.
  Object toJson() => isGroup
      ? {
          'id': id,
          'parts': [for (final p in parts) p.id],
        }
      : id;

  @override
  String toString() => 'AssemblyPiece($id, ${parts.length} parts)';
}
