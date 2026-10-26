import 'anatomy_part.dart';
import 'assembly_level.dart';
import 'assembly_piece.dart';
import 'body_system.dart';

/// Pieces and scoring rules of the creative bone builder ("Xếp xương sáng
/// tạo"): big skeletal blocks the player stacks freely, then a physics test
/// scores the structure (the anatomical skeleton = 100).
abstract class BoneBuilder {
  /// Fewest pieces a structure needs before it can be tested.
  static const minPlaced = 3;

  /// Rotation steps of the toolbar, in degrees.
  static const coarseStep = 90;
  static const fineStep = 15;

  /// Stars for [score]: ≥60 → 1, ≥100 (anatomical) → 2, ≥140 → 3.
  static int stars(int score) => score >= 140
      ? 3
      : score >= 100
      ? 2
      : score >= 60
      ? 1
      : 0;

  /// The full-skeleton level's medium groups, adapted to ~23 big pieces:
  /// no hyoid/larynx (tiny, floating) and each patella joins its femur.
  static List<AssemblyGroup> get groups {
    final skeleton = AssemblyLevel.all.firstWhere((l) => l.id == 'full_skeleton');
    final medium = skeleton.variants[AssemblyDetail.medium] ?? skeleton.groups;
    return [
      for (final g in medium)
        if (g.id != 'g_larynx' && !g.id.startsWith('g_patella_'))
          g.id.startsWith('g_femur_')
              ? AssemblyGroup(
                  id: g.id,
                  nameVi: g.nameVi,
                  nameEn: g.nameEn,
                  include: [...g.include, '^${g.id.endsWith('_right') ? 'Right' : 'Left'} patella\$'],
                )
              : g,
    ];
  }

  /// Pieces resolved over [parts] (skeletal only); empty groups are dropped.
  static List<AssemblyPiece> resolve(Iterable<AnatomyPart> parts) => AssemblyLevel(
    id: 'bone_builder',
    title: '',
    subtitle: '',
    icon: AssemblyLevel.all.first.icon,
    difficulty: AssemblyDifficulty.medium,
    systems: const [BodySystem.skeletal],
    groups: groups,
  ).resolve(parts);

  /// What `builderStart` expects for [piece].
  static Map<String, Object> toJson(AssemblyPiece piece) => {
    'id': piece.id,
    'name': piece.nameVi,
    'partIds': [for (final p in piece.parts) p.id],
  };
}
