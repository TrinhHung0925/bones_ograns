import 'body_system.dart';

class AnatomyPart {
  const AnatomyPart({required this.id, required this.name, required this.system});

  factory AnatomyPart.fromJson(Map<String, dynamic> json) => AnatomyPart(
        id: json['id'] as String,
        name: json['name'] as String,
        system: BodySystem.fromName(json['system'] as String),
      );

  /// FMA concept id, also the mesh name inside the system's GLB.
  final String id;
  final String name;
  final BodySystem system;
}
