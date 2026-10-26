import 'body_system.dart';

class AnatomyPart {
  const AnatomyPart({required this.id, required this.name, required this.system, this.nameVi});

  factory AnatomyPart.fromJson(Map<String, dynamic> json, {String? nameVi}) => AnatomyPart(
    id: json['id'] as String,
    name: json['name'] as String,
    system: BodySystem.fromName(json['system'] as String),
    nameVi: nameVi,
  );

  /// FMA concept id, also the mesh name inside the system's GLB.
  final String id;

  /// English name (FMA); also what text-to-speech reads aloud.
  final String name;
  final BodySystem system;

  /// Vietnamese name from `assets/anatomy/names_vi.json`, when translated.
  final String? nameVi;

  /// Name shown first in the UI: Vietnamese when known, else English.
  String get displayName => nameVi ?? name;

  /// Whether [displayName] differs from the English name, so the English one
  /// is worth showing as a secondary line.
  bool get hasVietnamese => nameVi != null;

  @override
  String toString() => 'AnatomyPart($id, $name)';
}
