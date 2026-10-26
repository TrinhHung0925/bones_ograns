import 'package:flutter/material.dart';

import 'anatomy_part.dart';
import 'assembly_piece.dart';
import 'body_system.dart';

enum AssemblyDifficulty {
  easy('Dễ'),
  medium('Vừa'),
  hard('Khó'),
  extreme('Siêu khó');

  const AssemblyDifficulty(this.label);

  final String label;
}

/// Several parts that move as one rigid piece, e.g. the whole right hand.
/// Membership is a set of regular expressions over the English part names.
class AssemblyGroup {
  const AssemblyGroup({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.include,
    this.exclude = const [],
    this.systems,
  });

  /// Piece id sent to the viewer; never collides with an FMA part id.
  final String id;
  final String nameVi;
  final String nameEn;
  final List<String> include;
  final List<String> exclude;

  /// Restricts the group to these systems (default: the level's systems).
  final List<BodySystem>? systems;

  /// Right and left copies of a group template. In [id], names and patterns
  /// `{S}` becomes Right/Left, `{s}` right/left and `{vi}` phải/trái.
  static List<AssemblyGroup> bothSides({
    required String id,
    required String nameVi,
    required String nameEn,
    required List<String> include,
    List<BodySystem>? systems,
  }) {
    AssemblyGroup side(String upper, String lower, String vi) {
      String fill(String s) => s.replaceAll('{S}', upper).replaceAll('{s}', lower).replaceAll('{vi}', vi);
      return AssemblyGroup(
        id: fill(id),
        nameVi: fill(nameVi),
        nameEn: fill(nameEn),
        include: include.map(fill).toList(growable: false),
        systems: systems,
      );
    }

    return [side('Right', 'right', 'phải'), side('Left', 'left', 'trái')];
  }
}

/// A section of the level map.
class AssemblyChapter {
  const AssemblyChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.levels,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<AssemblyLevel> levels;
}

/// One stage of the 3D assembly game: a body region whose pieces are picked
/// from parts.json by English name, either one part per piece or as groups.
class AssemblyLevel {
  const AssemblyLevel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.difficulty,
    required this.systems,
    this.include = const [],
    this.groups = const [],
    this.view = const [0, 0, 1],
  });

  /// Stable key for saved progress; never rename.
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final AssemblyDifficulty difficulty;

  /// Systems that must be loaded in the viewer for this level.
  final List<BodySystem> systems;

  /// Regular expressions; every matching part not taken by a group is its
  /// own piece.
  final List<String> include;

  /// Grouped pieces, matched in order; a part joins the first group it fits.
  final List<AssemblyGroup> groups;

  /// Direction from the region towards the camera (body coordinates).
  final List<double> view;

  /// Pieces of this level: groups first (in [groups] order), then single
  /// parts in the order of [parts]. Empty groups are dropped.
  List<AssemblyPiece> resolve(Iterable<AnatomyPart> parts) {
    final candidates = parts.where((p) => systems.contains(p.system)).toList();
    final taken = <String>{};
    final pieces = <AssemblyPiece>[];
    for (final group in groups) {
      final include = group.include.map(RegExp.new).toList();
      final exclude = group.exclude.map(RegExp.new).toList();
      final members = [
        for (final p in candidates)
          if (!taken.contains(p.id) &&
              (group.systems?.contains(p.system) ?? true) &&
              include.any((r) => r.hasMatch(p.name)) &&
              !exclude.any((r) => r.hasMatch(p.name)))
            p,
      ];
      if (members.isEmpty) continue;
      taken.addAll(members.map((p) => p.id));
      pieces.add(AssemblyPiece(id: group.id, parts: members, nameVi: group.nameVi, nameEn: group.nameEn));
    }
    final singles = include.map(RegExp.new).toList();
    for (final p in candidates) {
      if (!taken.contains(p.id) && singles.any((r) => r.hasMatch(p.name))) {
        pieces.add(AssemblyPiece.single(p));
      }
    }
    return pieces;
  }

  /// Chapter this level belongs to.
  AssemblyChapter get chapter => chapters.firstWhere((c) => c.levels.contains(this));

  /// Every level in play order, chapter after chapter.
  static final List<AssemblyLevel> all = [for (final c in chapters) ...c.levels];

  /// The level after this one, or null for the last.
  AssemblyLevel? get next {
    final index = all.indexOf(this);
    return index >= 0 && index + 1 < all.length ? all[index + 1] : null;
  }

  static final List<AssemblyChapter> chapters = [
    AssemblyChapter(
      id: 'bones',
      title: 'Chương 1 · Xương',
      subtitle: 'Ghép từng vùng của bộ xương',
      icon: Icons.accessibility_new,
      levels: [
        _armRight,
        _legRight,
        _skull,
        _teeth,
        _armLeft,
        _legLeft,
        _handRight,
        _footRight,
        _thorax,
        _spine,
        _handLeft,
        _footLeft,
      ],
    ),
    AssemblyChapter(
      id: 'organs',
      title: 'Chương 2 · Nội tạng',
      subtitle: 'Tim, gan, thận, não…',
      icon: Icons.favorite,
      levels: [_urinary, _organs, _heart, _brain, _digestive],
    ),
    AssemblyChapter(
      id: 'body',
      title: 'Chương 3 · Toàn thân',
      subtitle: 'Ghép cả cơ thể người',
      icon: Icons.emoji_events,
      levels: [_fullSkeleton, _fullBody],
    ),
  ];

  // ---------------------------------------------------------------------
  // Shared patterns.
  // ---------------------------------------------------------------------

  static const _skullBones = [
    r'^(Frontal bone|Occipital bone|Sphenoid bone|Ethmoid|Vomer|Septal nasal cartilage)$',
    r'^(Left|Right) (parietal|temporal|zygomatic|nasal|lacrimal|palatine) bone$',
    r'^(Left|Right) (maxilla|inferior nasal concha|lateral nasal cartilage|major alar cartilage)$',
    r'^(Left|Right) upper .*tooth$',
    r'^Trochlea of (left|right) superior oblique$',
  ];
  static const _mandible = [r'^Mandible$', r'^(Left|Right) lower .*tooth$'];
  static const _larynx = [
    r'^(Hyoid bone|Cricoid cartilage|Thyroid cartilage)$',
    r'^(Left|Right) (arytenoid|corniculate|cuneiform) cartilage$',
    r'^(Hyo-epiglottic ligament|Thyro-epiglottic ligament|Median thyrohyoid ligament)$',
    r'^(Left|Right) (lateral thyrohyoid|stylohyoid) ligament$',
  ];
  static const _cervical = [r'^(Atlas|Axis)$', r'cervical vertebra$', r'^Intervertebral disk of axis$'];
  // The unqualified "Intervertebral disk" sits between T12 and L1.
  static const _thoracic = [r'thoracic vertebra$', r'^Intervertebral disk$'];
  static const _lumbar = [r'lumbar vertebra$'];
  static const _pelvis = [r'^(Sacrum|Left hip bone|Right hip bone)$'];
  static const _ribCage = [
    r'^(Left|Right) \w+ (rib|costal cartilage)$',
    r'^(Manubrium|Body of sternum|Xiphoid process)$',
  ];
  static const _hand = [
    r'^{S} (scaphoid|lunate|triquetral|pisiform|trapezium|trapezoid|capitate|hamate)$',
    r'^{S} \w+ metacarpal bone$',
    r'phalanx of {s} (thumb|\w+ finger)$',
  ];
  static const _foot = [
    r'^{S} (talus|calcaneus|cuboid bone|\w+ cuneiform bone|long plantar ligament)$',
    r'^(Navicular|Sesamoid) bone of {s} foot$',
    r'^{S} \w+ metatarsal bone$',
    r'phalanx of {s} (big|second|third|fourth|little) toe$',
  ];

  static String _side(String pattern, {required bool right}) =>
      pattern.replaceAll('{S}', right ? 'Right' : 'Left').replaceAll('{s}', right ? 'right' : 'left');

  static List<String> _sided(List<String> patterns, {required bool right}) => [
    for (final p in patterns) _side(p, right: right),
  ];

  // ---------------------------------------------------------------------
  // Chapter 1: bones, one part per piece.
  // ---------------------------------------------------------------------

  static final _armRight = AssemblyLevel(
    id: 'arm_right',
    title: 'Chi trên phải',
    subtitle: 'Xương đòn, vai, cánh tay, cẳng tay',
    icon: Icons.sports_handball,
    difficulty: AssemblyDifficulty.easy,
    systems: const [BodySystem.skeletal],
    include: const [r'^Right (clavicle|scapula|humerus|radius|ulna)$'],
  );

  static final _armLeft = AssemblyLevel(
    id: 'arm_left',
    title: 'Chi trên trái',
    subtitle: 'Xương đòn, vai, cánh tay, cẳng tay',
    icon: Icons.sports_handball,
    difficulty: AssemblyDifficulty.easy,
    systems: const [BodySystem.skeletal],
    include: const [r'^Left (clavicle|scapula|humerus|radius|ulna)$'],
  );

  static final _legRight = AssemblyLevel(
    id: 'leg_right',
    title: 'Chi dưới phải',
    subtitle: 'Xương chậu, đùi, bánh chè, cẳng chân',
    icon: Icons.directions_walk,
    difficulty: AssemblyDifficulty.easy,
    systems: const [BodySystem.skeletal],
    include: const [r'^Right (hip bone|femur|patella|tibia|fibula)$'],
  );

  static final _legLeft = AssemblyLevel(
    id: 'leg_left',
    title: 'Chi dưới trái',
    subtitle: 'Xương chậu, đùi, bánh chè, cẳng chân',
    icon: Icons.directions_walk,
    difficulty: AssemblyDifficulty.easy,
    systems: const [BodySystem.skeletal],
    include: const [r'^Left (hip bone|femur|patella|tibia|fibula)$'],
  );

  static final _skull = AssemblyLevel(
    id: 'skull',
    title: 'Hộp sọ',
    subtitle: 'Xương sọ và xương mặt',
    icon: Icons.face,
    difficulty: AssemblyDifficulty.medium,
    systems: const [BodySystem.skeletal],
    include: const [
      r'^(Frontal bone|Occipital bone|Sphenoid bone|Ethmoid|Mandible|Vomer|Hyoid bone)$',
      r'^(Left|Right) (parietal|temporal|zygomatic|nasal|lacrimal|palatine) bone$',
      r'^(Left|Right) (maxilla|inferior nasal concha)$',
    ],
    view: const [0.35, 0.15, 1],
  );

  static final _teeth = AssemblyLevel(
    id: 'teeth',
    title: 'Răng',
    subtitle: 'Răng cửa, răng nanh, răng hàm',
    icon: Icons.sentiment_very_satisfied,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: const [r'tooth$'],
  );

  static final _handRight = AssemblyLevel(
    id: 'hand_right',
    title: 'Bàn tay phải',
    subtitle: 'Xương cổ tay, bàn tay, đốt ngón',
    icon: Icons.back_hand,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: _sided(_hand, right: true),
  );

  static final _handLeft = AssemblyLevel(
    id: 'hand_left',
    title: 'Bàn tay trái',
    subtitle: 'Xương cổ tay, bàn tay, đốt ngón',
    icon: Icons.front_hand,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: _sided(_hand, right: false),
  );

  static final _footRight = AssemblyLevel(
    id: 'foot_right',
    title: 'Bàn chân phải',
    subtitle: 'Xương cổ chân, bàn chân, đốt ngón',
    icon: Icons.do_not_step,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: const [
      r'^Right (talus|calcaneus|cuboid bone|\w+ cuneiform bone)$',
      r'^Navicular bone of right foot$',
      r'^Right \w+ metatarsal bone$',
      r'phalanx of right (big|second|third|fourth|little) toe$',
    ],
    // From above and in front, so the toes fan out instead of overlapping.
    view: const [-0.2, 1, 0.5],
  );

  static final _footLeft = AssemblyLevel(
    id: 'foot_left',
    title: 'Bàn chân trái',
    subtitle: 'Xương cổ chân, bàn chân, đốt ngón',
    icon: Icons.do_not_step,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: const [
      r'^Left (talus|calcaneus|cuboid bone|\w+ cuneiform bone)$',
      r'^Navicular bone of left foot$',
      r'^Left \w+ metatarsal bone$',
      r'phalanx of left (big|second|third|fourth|little) toe$',
    ],
    view: const [0.2, 1, 0.5],
  );

  static final _thorax = AssemblyLevel(
    id: 'thorax',
    title: 'Lồng ngực',
    subtitle: '24 xương sườn và xương ức',
    icon: Icons.shield,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: const [r'^(Left|Right) \w+ rib$', r'^(Manubrium|Body of sternum|Xiphoid process)$'],
  );

  static final _spine = AssemblyLevel(
    id: 'spine',
    title: 'Cột sống',
    subtitle: 'Đốt sống cổ, ngực, thắt lưng, xương cùng',
    icon: Icons.linear_scale,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: const [r'^(Atlas|Axis|Sacrum)$', r'^\w+ (cervical|thoracic|lumbar) vertebra$'],
    // Three-quarter side view shows the spine's curves.
    view: const [1, 0.05, 0.6],
  );

  // ---------------------------------------------------------------------
  // Chapter 2: organs.
  // ---------------------------------------------------------------------

  static final _urinary = AssemblyLevel(
    id: 'urinary',
    title: 'Thận & tiết niệu',
    subtitle: 'Thận, niệu quản, bàng quang, tuyến thượng thận',
    icon: Icons.water_drop,
    difficulty: AssemblyDifficulty.easy,
    systems: const [BodySystem.urinary, BodySystem.endocrine],
    include: const [r'^(Left|Right) (kidney|ureter|adrenal gland)$', r'^(Urinary bladder|Urethra)$'],
  );

  static final _organs = AssemblyLevel(
    id: 'organs',
    title: 'Nội tạng',
    subtitle: 'Tim, gan, dạ dày, ruột, thận…',
    icon: Icons.favorite,
    difficulty: AssemblyDifficulty.medium,
    systems: const [
      BodySystem.digestive,
      BodySystem.urinary,
      BodySystem.cardiovascular,
      BodySystem.respiratory,
      BodySystem.other,
    ],
    include: const [
      r'^(Stomach|Gallbladder|Pancreas|Duodenum|Rectum|Spleen|Esophagus|Trachea)$',
      r'^(Urinary bladder|Caudate lobe of liver)$',
      r'^Hepatovenous segment',
      r'^(Left|Right) kidney$',
      r'^(Ascending|Transverse|Descending) colon$',
      r'^Wall of (left atrium|right atrium|ventricle)$',
    ],
  );

  static final _heart = AssemblyLevel(
    id: 'heart',
    title: 'Tim',
    subtitle: 'Thành tim, động mạch chủ, tĩnh mạch chủ',
    icon: Icons.monitor_heart,
    difficulty: AssemblyDifficulty.medium,
    systems: const [BodySystem.cardiovascular],
    include: const [
      r'^Wall of (left atrium|right atrium|ventricle)$',
      r'^(Ascending aorta|Arch of aorta|Pulmonary trunk|Superior vena cava|Inferior vena cava)$',
      r'^(Coronary sinus|Great cardiac vein)$',
      r'^Trunk of (left|right) coronary artery$',
      r'^(Left|Right) pulmonary artery$',
      r'^(Left|Right) (superior|inferior) pulmonary vein$',
    ],
    view: const [0.2, 0.1, 1],
  );

  static final _brain = AssemblyLevel(
    id: 'brain',
    title: 'Não bộ',
    subtitle: 'Các thùy não, tiểu não, thân não',
    icon: Icons.psychology,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.nervous],
    groups: [
      ...AssemblyGroup.bothSides(
        id: 'g_frontal_{s}',
        nameVi: 'Thùy trán {vi}',
        nameEn: '{S} frontal lobe',
        include: [r'^{S} (superior|middle|inferior) frontal gyrus$', r'^{S} precentral gyrus$'],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_parietal_{s}',
        nameVi: 'Thùy đỉnh {vi}',
        nameEn: '{S} parietal lobe',
        include: [r'^{S} (postcentral gyrus|superior parietal lobule|supramarginal gyrus|angular gyrus)$'],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_temporal_{s}',
        nameVi: 'Thùy thái dương {vi}',
        nameEn: '{S} temporal lobe',
        include: [
          r'^{S} (middle|inferior) temporal gyrus$',
          r'^(Anterior|Posterior) part of {s} superior temporal gyrus$',
          r'^{S} (fusiform|parahippocampal) gyrus$',
        ],
      ),
    ],
    include: const [
      r'^(Left|Right) occipital lobe$',
      r'^White matter of (left|right) cerebral hemisphere$',
      r'^(Cerebellum|Pons|Medulla oblongata|Midbrain|Corpus callosum|Orbital gyrus)$',
    ],
    view: const [0.6, 0.4, 1],
  );

  static final _digestive = AssemblyLevel(
    id: 'digestive',
    title: 'Gan & tiêu hóa',
    subtitle: 'Phân thùy gan, dạ dày, ruột non, đại tràng',
    icon: Icons.restaurant,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.digestive],
    include: const [
      r'^Hepatovenous segment',
      r'^(Caudate lobe of liver|Gallbladder|Stomach|Esophagus|Duodenum|Pancreas|Rectum|Appendix)$',
      r'^(Distal|Middle|Proximal) part of (ileum|jejunum)$',
      r'^(Ascending|Transverse|Descending) colon$',
    ],
  );

  // ---------------------------------------------------------------------
  // Chapter 3: the whole body, as grouped pieces.
  // ---------------------------------------------------------------------

  static final _fullSkeleton = AssemblyLevel(
    id: 'full_skeleton',
    title: 'Bộ xương hoàn chỉnh',
    subtitle: 'Toàn bộ 206 xương, ghép theo từng khối',
    icon: Icons.accessibility_new,
    difficulty: AssemblyDifficulty.extreme,
    systems: const [BodySystem.skeletal],
    groups: [
      const AssemblyGroup(id: 'g_skull', nameVi: 'Hộp sọ', nameEn: 'Skull', include: _skullBones),
      const AssemblyGroup(id: 'g_mandible', nameVi: 'Xương hàm dưới', nameEn: 'Mandible', include: _mandible),
      const AssemblyGroup(
        id: 'g_larynx',
        nameVi: 'Xương móng & sụn thanh quản',
        nameEn: 'Hyoid bone & larynx',
        include: _larynx,
      ),
      const AssemblyGroup(id: 'g_cervical', nameVi: 'Cột sống cổ', nameEn: 'Cervical spine', include: _cervical),
      const AssemblyGroup(id: 'g_thoracic', nameVi: 'Cột sống ngực', nameEn: 'Thoracic spine', include: _thoracic),
      const AssemblyGroup(id: 'g_lumbar', nameVi: 'Cột sống thắt lưng', nameEn: 'Lumbar spine', include: _lumbar),
      const AssemblyGroup(id: 'g_pelvis', nameVi: 'Khung chậu', nameEn: 'Pelvis', include: _pelvis),
      const AssemblyGroup(id: 'g_rib_cage', nameVi: 'Lồng ngực', nameEn: 'Rib cage', include: _ribCage),
      ...AssemblyGroup.bothSides(
        id: 'g_clavicle_{s}',
        nameVi: 'Xương đòn {vi}',
        nameEn: '{S} clavicle',
        include: [r'^{S} clavicle$'],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_scapula_{s}',
        nameVi: 'Xương vai {vi}',
        nameEn: '{S} scapula',
        include: [r'^{S} scapula$'],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_humerus_{s}',
        nameVi: 'Xương cánh tay {vi}',
        nameEn: '{S} humerus',
        include: [r'^{S} humerus$'],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_forearm_{s}',
        nameVi: 'Xương cẳng tay {vi}',
        nameEn: '{S} forearm',
        include: [r'^{S} (radius|ulna)$'],
      ),
      ...AssemblyGroup.bothSides(id: 'g_hand_{s}', nameVi: 'Bàn tay {vi}', nameEn: '{S} hand', include: _hand),
      ...AssemblyGroup.bothSides(
        id: 'g_femur_{s}',
        nameVi: 'Xương đùi {vi}',
        nameEn: '{S} femur',
        include: [r'^{S} femur$'],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_patella_{s}',
        nameVi: 'Xương bánh chè {vi}',
        nameEn: '{S} patella',
        include: [r'^{S} patella$'],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_leg_{s}',
        nameVi: 'Xương cẳng chân {vi}',
        nameEn: '{S} leg',
        include: [r'^{S} (tibia|fibula)$'],
      ),
      ...AssemblyGroup.bothSides(id: 'g_foot_{s}', nameVi: 'Bàn chân {vi}', nameEn: '{S} foot', include: _foot),
    ],
  );

  static final _fullBody = AssemblyLevel(
    id: 'full_body',
    title: 'Toàn thân',
    subtitle: 'Bộ xương và các cơ quan chính',
    icon: Icons.emoji_people,
    difficulty: AssemblyDifficulty.extreme,
    systems: const [
      BodySystem.skeletal,
      BodySystem.cardiovascular,
      BodySystem.respiratory,
      BodySystem.digestive,
      BodySystem.urinary,
      BodySystem.nervous,
      BodySystem.other,
    ],
    groups: [
      const AssemblyGroup(
        id: 'g_head',
        nameVi: 'Hộp sọ & xương hàm',
        nameEn: 'Skull & jaw',
        include: [..._skullBones, ..._mandible, ..._larynx],
        systems: [BodySystem.skeletal],
      ),
      const AssemblyGroup(
        id: 'g_spine',
        nameVi: 'Cột sống',
        nameEn: 'Spine',
        include: [..._cervical, ..._thoracic, ..._lumbar],
        systems: [BodySystem.skeletal],
      ),
      const AssemblyGroup(
        id: 'g_pelvis',
        nameVi: 'Khung chậu',
        nameEn: 'Pelvis',
        include: _pelvis,
        systems: [BodySystem.skeletal],
      ),
      const AssemblyGroup(
        id: 'g_rib_cage',
        nameVi: 'Lồng ngực',
        nameEn: 'Rib cage',
        include: _ribCage,
        systems: [BodySystem.skeletal],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_arm_{s}',
        nameVi: 'Tay {vi}',
        nameEn: '{S} arm',
        include: [r'^{S} (clavicle|scapula|humerus|radius|ulna)$', ..._hand],
        systems: [BodySystem.skeletal],
      ),
      ...AssemblyGroup.bothSides(
        id: 'g_leg_{s}',
        nameVi: 'Chân {vi}',
        nameEn: '{S} leg',
        include: [r'^{S} (femur|patella|tibia|fibula)$', ..._foot],
        systems: [BodySystem.skeletal],
      ),
      const AssemblyGroup(
        id: 'g_brain',
        nameVi: 'Não',
        nameEn: 'Brain',
        include: [r'.'],
        exclude: [r'nerve|ganglion'],
        systems: [BodySystem.nervous],
      ),
      const AssemblyGroup(
        id: 'g_heart',
        nameVi: 'Tim',
        nameEn: 'Heart',
        include: [
          r'^(Wall|Cavity) of ',
          r'(leaflet|cusp) of ',
          r'papillary muscle',
          r'^(Ascending aorta|Arch of aorta|Pulmonary trunk|Superior vena cava)$',
        ],
        systems: [BodySystem.cardiovascular],
      ),
      const AssemblyGroup(
        id: 'g_airway',
        nameVi: 'Khí quản & phế quản',
        nameEn: 'Trachea & bronchi',
        include: [r'^Trachea$', r'bronch'],
        exclude: [r'artery'],
        systems: [BodySystem.respiratory],
      ),
      const AssemblyGroup(
        id: 'g_liver',
        nameVi: 'Gan & túi mật',
        nameEn: 'Liver & gallbladder',
        include: [
          r'^Hepatovenous segment',
          r'^(Caudate lobe of liver|Gallbladder|Common hepatic duct|Cystic duct)$',
          r'hepatic biliary tree$',
          r'^Left duct of caudate lobe of liver$',
        ],
        systems: [BodySystem.digestive],
      ),
      const AssemblyGroup(
        id: 'g_small_intestine',
        nameVi: 'Ruột non',
        nameEn: 'Small intestine',
        include: [r'^Duodenum$', r'part of (ileum|jejunum)$', r'^(Mesentery of small intestine|Ileocecal junction)$'],
        systems: [BodySystem.digestive],
      ),
      const AssemblyGroup(
        id: 'g_large_intestine',
        nameVi: 'Ruột già',
        nameEn: 'Large intestine',
        include: [r'colon$', r'^(Rectum|Appendix|Mesoappendix|Transverse mesocolon)$', r'^Taenia '],
        systems: [BodySystem.digestive],
      ),
    ],
    include: const [r'^(Stomach|Pancreas|Spleen|Esophagus|Urinary bladder)$', r'^(Left|Right) kidney$'],
  );
}
