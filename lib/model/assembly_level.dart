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

/// How finely a level is cut into pieces. Levels that offer several let the
/// player choose, e.g. a whole arm as 4 big blocks or as every single bone.
enum AssemblyDetail {
  coarse('Cụm lớn', 'Ít mảnh to: mỗi mảnh là cả một vùng'),
  medium('Tiêu chuẩn', 'Xương lớn riêng, bàn tay/bàn chân chia theo ngón'),
  fine('Chi tiết', 'Từng xương riêng lẻ');

  const AssemblyDetail(this.label, this.description);

  final String label;
  final String description;
}

/// A level played at a chosen detail; the assembly screen's route argument.
class AssemblySelection {
  const AssemblySelection(this.level, [this.detail]);

  final AssemblyLevel level;

  /// Null for levels with a single way of cutting.
  final AssemblyDetail? detail;

  /// Key of saved stars, times and scores.
  String get progressId => level.progressId(detail);
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

  /// Copy restricted to [systems], for reusing skeleton groups in mixed levels.
  AssemblyGroup only(List<BodySystem> systems) =>
      AssemblyGroup(id: id, nameVi: nameVi, nameEn: nameEn, include: include, exclude: exclude, systems: systems);

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
    this.variants = const {},
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

  /// Alternative groupings by detail; when set they replace [groups]. An
  /// empty list means every part matching [include] is its own piece.
  final Map<AssemblyDetail, List<AssemblyGroup>> variants;

  /// Details the player can choose from, coarse to fine (empty = no choice).
  List<AssemblyDetail> get details => [
    for (final d in AssemblyDetail.values)
      if (variants.containsKey(d)) d,
  ];

  /// Detail used when none is chosen; its progress keeps the plain [id] key.
  AssemblyDetail? get defaultDetail =>
      variants.isEmpty ? null : (variants.containsKey(AssemblyDetail.medium) ? AssemblyDetail.medium : details.first);

  /// Saved-progress key of this level at [detail].
  String progressId(AssemblyDetail? detail) => detail == null || detail == defaultDetail ? id : '$id@${detail.name}';

  /// Every grouping this level can be played with.
  Iterable<List<AssemblyGroup>> get allGroupings => variants.isEmpty ? [groups] : variants.values;

  /// Direction from the region towards the camera (body coordinates).
  final List<double> view;

  /// Pieces of this level at [detail] (default: [defaultDetail]): groups
  /// first, in order, then single parts in the order of [parts]. Empty groups
  /// are dropped.
  List<AssemblyPiece> resolve(Iterable<AnatomyPart> parts, {AssemblyDetail? detail}) {
    final groups = variants.isEmpty ? this.groups : variants[detail ?? defaultDetail]!;
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
        _wholeArmRight,
        _wholeLegRight,
        _skull,
        _teeth,
        _armLeft,
        _legLeft,
        _wholeArmLeft,
        _wholeLegLeft,
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
  // Shared groupings for the detail choices.
  // ---------------------------------------------------------------------

  static const _armBones = [r'^{S} (clavicle|scapula|humerus|radius|ulna)$'];
  static const _legBones = [r'^{S} (hip bone|femur|patella|tibia|fibula)$'];
  static const _carpals = [r'^{S} (scaphoid|lunate|triquetral|pisiform|trapezium|trapezoid|capitate|hamate)$'];
  static const _metacarpals = [r'^{S} \w+ metacarpal bone$'];
  static const _tarsals = [
    r'^{S} (talus|calcaneus|cuboid bone|\w+ cuneiform bone|long plantar ligament)$',
    r'^(Navicular|Sesamoid) bone of {s} foot$',
  ];
  static const _metatarsals = [r'^{S} \w+ metatarsal bone$'];

  /// (English digit, id slug, Vietnamese name).
  static const _fingers = [
    ('thumb', 'thumb', 'Ngón cái tay'),
    ('index finger', 'index', 'Ngón trỏ'),
    ('middle finger', 'middle', 'Ngón giữa'),
    ('ring finger', 'ring', 'Ngón nhẫn'),
    ('little finger', 'little', 'Ngón út tay'),
  ];
  static const _toes = [
    ('big toe', 'big_toe', 'Ngón cái chân'),
    ('second toe', 'toe2', 'Ngón chân thứ hai'),
    ('third toe', 'toe3', 'Ngón chân thứ ba'),
    ('fourth toe', 'toe4', 'Ngón chân thứ tư'),
    ('little toe', 'little_toe', 'Ngón út chân'),
  ];

  /// One side of an [AssemblyGroup.bothSides] template.
  static AssemblyGroup _sideGroup(
    String id,
    String nameVi,
    String nameEn,
    List<String> include, {
    required bool right,
  }) => AssemblyGroup.bothSides(id: id, nameVi: nameVi, nameEn: nameEn, include: include)[right ? 0 : 1];

  /// Hand as wrist, palm and five fingers (7 pieces).
  static List<AssemblyGroup> _handSplit({required bool right}) => [
    _sideGroup('g_carpals_{s}', 'Xương cổ tay {vi}', '{S} carpal bones', _carpals, right: right),
    _sideGroup('g_metacarpals_{s}', 'Xương đốt bàn tay {vi}', '{S} metacarpals', _metacarpals, right: right),
    for (final (en, slug, vi) in _fingers)
      _sideGroup('g_${slug}_{s}', '$vi {vi}', '{S} $en', ['phalanx of {s} $en\$'], right: right),
  ];

  /// Foot as ankle, sole and five toes (7 pieces).
  static List<AssemblyGroup> _footSplit({required bool right}) => [
    _sideGroup('g_tarsals_{s}', 'Xương cổ chân {vi}', '{S} tarsal bones', _tarsals, right: right),
    _sideGroup('g_metatarsals_{s}', 'Xương đốt bàn chân {vi}', '{S} metatarsals', _metatarsals, right: right),
    for (final (en, slug, vi) in _toes)
      _sideGroup('g_${slug}_{s}', '$vi {vi}', '{S} $en', ['phalanx of {s} $en\$'], right: right),
  ];

  /// Whole arm as shoulder girdle, upper arm, forearm and hand (4 pieces).
  static List<AssemblyGroup> _armBlocks({required bool right}) => [
    _sideGroup('g_girdle_{s}', 'Đai vai {vi}', '{S} shoulder girdle', [r'^{S} (clavicle|scapula)$'], right: right),
    _sideGroup('g_humerus_{s}', 'Xương cánh tay {vi}', '{S} humerus', [r'^{S} humerus$'], right: right),
    _sideGroup('g_forearm_{s}', 'Xương cẳng tay {vi}', '{S} forearm', [r'^{S} (radius|ulna)$'], right: right),
    _sideGroup('g_hand_{s}', 'Bàn tay {vi}', '{S} hand', _hand, right: right),
  ];

  /// Whole leg as hip bone, thigh, lower leg and foot (4 pieces).
  static List<AssemblyGroup> _legBlocks({required bool right}) => [
    _sideGroup('g_hip_{s}', 'Xương chậu {vi}', '{S} hip bone', [r'^{S} hip bone$'], right: right),
    _sideGroup('g_thigh_{s}', 'Đùi {vi}', '{S} thigh', [r'^{S} (femur|patella)$'], right: right),
    _sideGroup('g_shank_{s}', 'Xương cẳng chân {vi}', '{S} lower leg', [r'^{S} (tibia|fibula)$'], right: right),
    _sideGroup('g_foot_{s}', 'Bàn chân {vi}', '{S} foot', _foot, right: right),
  ];

  static AssemblyLevel _wholeArm({required bool right}) => AssemblyLevel(
    id: right ? 'whole_arm_right' : 'whole_arm_left',
    title: right ? 'Cả tay phải' : 'Cả tay trái',
    subtitle: 'Từ xương đòn tới đầu ngón tay',
    icon: Icons.sports_handball,
    difficulty: AssemblyDifficulty.medium,
    systems: const [BodySystem.skeletal],
    include: _sided([..._armBones, ..._hand], right: right),
    variants: {
      AssemblyDetail.coarse: _armBlocks(right: right),
      AssemblyDetail.medium: _handSplit(right: right),
      AssemblyDetail.fine: const [],
    },
  );

  static AssemblyLevel _wholeLeg({required bool right}) => AssemblyLevel(
    id: right ? 'whole_leg_right' : 'whole_leg_left',
    title: right ? 'Cả chân phải' : 'Cả chân trái',
    subtitle: 'Từ xương chậu tới đầu ngón chân',
    icon: Icons.directions_walk,
    difficulty: AssemblyDifficulty.medium,
    systems: const [BodySystem.skeletal],
    include: _sided([..._legBones, ..._foot], right: right),
    variants: {
      AssemblyDetail.coarse: _legBlocks(right: right),
      AssemblyDetail.medium: _footSplit(right: right),
      AssemblyDetail.fine: const [],
    },
  );

  static final _wholeArmRight = _wholeArm(right: true);
  static final _wholeArmLeft = _wholeArm(right: false);
  static final _wholeLegRight = _wholeLeg(right: true);
  static final _wholeLegLeft = _wholeLeg(right: false);

  static const _spineSegments = [
    AssemblyGroup(id: 'g_cervical', nameVi: 'Cột sống cổ', nameEn: 'Cervical spine', include: _cervical),
    AssemblyGroup(id: 'g_thoracic', nameVi: 'Cột sống ngực', nameEn: 'Thoracic spine', include: _thoracic),
    AssemblyGroup(id: 'g_lumbar', nameVi: 'Cột sống thắt lưng', nameEn: 'Lumbar spine', include: _lumbar),
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
    variants: {AssemblyDetail.medium: _handSplit(right: true), AssemblyDetail.fine: const []},
  );

  static final _handLeft = AssemblyLevel(
    id: 'hand_left',
    title: 'Bàn tay trái',
    subtitle: 'Xương cổ tay, bàn tay, đốt ngón',
    icon: Icons.front_hand,
    difficulty: AssemblyDifficulty.hard,
    systems: const [BodySystem.skeletal],
    include: _sided(_hand, right: false),
    variants: {AssemblyDetail.medium: _handSplit(right: false), AssemblyDetail.fine: const []},
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
    variants: {AssemblyDetail.medium: _footSplit(right: true), AssemblyDetail.fine: const []},
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
    variants: {AssemblyDetail.medium: _footSplit(right: false), AssemblyDetail.fine: const []},
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
    variants: const {AssemblyDetail.coarse: _spineSegments, AssemblyDetail.fine: []},
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
    include: const [r'.'],
    variants: {
      AssemblyDetail.coarse: _skeletonBlocks,
      AssemblyDetail.medium: _skeletonParts,
      AssemblyDetail.fine: _skeletonFine,
    },
  );

  /// The skeleton as 8 big blocks: head, spine, pelvis, rib cage, arms, legs.
  static final List<AssemblyGroup> _skeletonBlocks = [
    const AssemblyGroup(
      id: 'g_head',
      nameVi: 'Hộp sọ & xương hàm',
      nameEn: 'Skull & jaw',
      include: [..._skullBones, ..._mandible, ..._larynx],
    ),
    const AssemblyGroup(
      id: 'g_spine',
      nameVi: 'Cột sống',
      nameEn: 'Spine',
      include: [..._cervical, ..._thoracic, ..._lumbar],
    ),
    const AssemblyGroup(id: 'g_pelvis', nameVi: 'Khung chậu', nameEn: 'Pelvis', include: _pelvis),
    const AssemblyGroup(id: 'g_rib_cage', nameVi: 'Lồng ngực', nameEn: 'Rib cage', include: _ribCage),
    ...AssemblyGroup.bothSides(
      id: 'g_arm_{s}',
      nameVi: 'Tay {vi}',
      nameEn: '{S} arm',
      include: [..._armBones, ..._hand],
    ),
    ...AssemblyGroup.bothSides(
      id: 'g_leg_{s}',
      nameVi: 'Chân {vi}',
      nameEn: '{S} leg',
      include: [r'^{S} (femur|patella|tibia|fibula)$', ..._foot],
    ),
  ];

  /// The skeleton as 26 parts: each long bone, hands and feet whole.
  static final List<AssemblyGroup> _skeletonParts = [
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
  ];

  /// The skeleton down to the fingers and toes (~56 pieces); long bones,
  /// hip bones and the sacrum are single pieces.
  static final List<AssemblyGroup> _skeletonFine = [
    const AssemblyGroup(id: 'g_skull', nameVi: 'Hộp sọ', nameEn: 'Skull', include: _skullBones),
    const AssemblyGroup(id: 'g_mandible', nameVi: 'Xương hàm dưới', nameEn: 'Mandible', include: _mandible),
    const AssemblyGroup(
      id: 'g_larynx',
      nameVi: 'Xương móng & sụn thanh quản',
      nameEn: 'Hyoid bone & larynx',
      include: _larynx,
    ),
    ..._spineSegments,
    const AssemblyGroup(id: 'g_rib_cage', nameVi: 'Lồng ngực', nameEn: 'Rib cage', include: _ribCage),
    for (final right in [true, false]) ...[..._handSplit(right: right), ..._footSplit(right: right)],
  ];

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
    variants: {
      AssemblyDetail.coarse: [..._skeletonBlocks.map(_skeletalOnly), ..._organGroups],
      AssemblyDetail.medium: [..._skeletonParts.map(_skeletalOnly), ..._organGroups],
    },
    include: const [r'^(Stomach|Pancreas|Spleen|Esophagus|Urinary bladder)$', r'^(Left|Right) kidney$'],
  );

  static AssemblyGroup _skeletalOnly(AssemblyGroup group) => group.only(const [BodySystem.skeletal]);

  /// Main organs of the full-body level, one rigid piece each.
  static const List<AssemblyGroup> _organGroups = [
    AssemblyGroup(
      id: 'g_brain',
      nameVi: 'Não',
      nameEn: 'Brain',
      include: [r'.'],
      exclude: [r'nerve|ganglion'],
      systems: [BodySystem.nervous],
    ),
    AssemblyGroup(
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
    AssemblyGroup(
      id: 'g_airway',
      nameVi: 'Khí quản & phế quản',
      nameEn: 'Trachea & bronchi',
      include: [r'^Trachea$', r'bronch'],
      exclude: [r'artery'],
      systems: [BodySystem.respiratory],
    ),
    AssemblyGroup(
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
    AssemblyGroup(
      id: 'g_small_intestine',
      nameVi: 'Ruột non',
      nameEn: 'Small intestine',
      include: [r'^Duodenum$', r'part of (ileum|jejunum)$', r'^(Mesentery of small intestine|Ileocecal junction)$'],
      systems: [BodySystem.digestive],
    ),
    AssemblyGroup(
      id: 'g_large_intestine',
      nameVi: 'Ruột già',
      nameEn: 'Large intestine',
      include: [r'colon$', r'^(Rectum|Appendix|Mesoappendix|Transverse mesocolon)$', r'^Taenia '],
      systems: [BodySystem.digestive],
    ),
  ];
}
