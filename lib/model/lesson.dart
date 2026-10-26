import 'package:flutter/material.dart';

import 'anatomy_part.dart';
import 'body_system.dart';

/// A section of the lesson list: one body region of the curriculum.
class LessonChapter {
  const LessonChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.lessons,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Lesson> lessons;
}

/// One study lesson: a handful of structures of a region, picked from
/// parts.json by English name like an `AssemblyGroup`, studied one by one in
/// the 3D viewer and then checked with a short "tap the named part" quiz.
///
/// Patterns are case-insensitive regular expressions over the English name.
/// Their order is the study order: parts matching an earlier pattern come
/// first. Parts matching any [exclude] pattern are dropped.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.systems,
    required this.include,
    this.exclude = const [],
    this.maxParts = 12,
  });

  /// Stable key for saved stars; never rename.
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Systems always shown in the viewer; the systems of the resolved parts
  /// are added to them (see [shownSystems]).
  final List<BodySystem> systems;
  final List<String> include;
  final List<String> exclude;

  /// Study size; beyond it, parts with a Vietnamese name are kept first.
  final int maxParts;

  /// Lessons resolving to fewer parts are hidden.
  static const minParts = 3;

  /// Questions in the check after studying.
  static const checkLength = 5;

  static final _cache = <String, List<AnatomyPart>>{};
  static List<AnatomyPart>? _cacheSource;

  /// Parts of this lesson in study order, at most [maxParts]. Cached per
  /// [parts] list, so screens can call it freely.
  List<AnatomyPart> resolve(List<AnatomyPart> parts) {
    if (!identical(parts, _cacheSource)) {
      _cache.clear();
      _cacheSource = parts;
    }
    return _cache[id] ??= List.unmodifiable(_resolve(parts));
  }

  List<AnatomyPart> _resolve(List<AnatomyPart> parts) {
    final include = [for (final p in this.include) RegExp(p, caseSensitive: false)];
    final exclude = [for (final p in this.exclude) RegExp(p, caseSensitive: false)];
    final ranked = <(int, int, AnatomyPart)>[];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (exclude.any((r) => r.hasMatch(part.name))) continue;
      final rank = include.indexWhere((r) => r.hasMatch(part.name));
      if (rank >= 0) ranked.add((rank, i, part));
    }
    // Pattern order first, then the (alphabetical) input order.
    ranked.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    final ordered = [for (final r in ranked) r.$3];
    if (ordered.length <= maxParts) return ordered;
    final keep = <AnatomyPart>{...ordered.where((p) => p.hasVietnamese).take(maxParts)};
    for (final p in ordered) {
      if (keep.length >= maxParts) break;
      keep.add(p);
    }
    return [
      for (final p in ordered)
        if (keep.contains(p)) p,
    ];
  }

  /// Systems the viewer must show for [parts] (the resolved ones).
  List<BodySystem> shownSystems(List<AnatomyPart> parts) {
    final set = {...systems, for (final p in parts) p.system};
    return [
      for (final s in BodySystem.values)
        if (set.contains(s)) s,
    ];
  }

  /// Whether this lesson has enough parts in [parts] to be studied.
  bool isAvailableIn(List<AnatomyPart> parts) => resolve(parts).length >= minParts;

  /// Every lesson with enough parts in [parts], in curriculum order.
  static List<Lesson> available(List<AnatomyPart> parts) => [
    for (final l in all)
      if (l.isAvailableIn(parts)) l,
  ];

  LessonChapter get chapter => chapters.firstWhere((c) => c.lessons.contains(this));

  static final List<Lesson> all = [for (final c in chapters) ...c.lessons];

  // ---------------------------------------------------------------------
  // Shared patterns.
  // ---------------------------------------------------------------------

  static const _noLeft = [r'\bleft\b'];
  static const _noRight = [r'\bright\b'];

  /// Any right-side ligament, labrum, capsule, disc, bursa or meniscus whose
  /// name mentions one of [words]; catches names we can't predict exactly.
  static String _rightJointPart(String words) =>
      r'^(?=.*\bright\b)(?=.*\b(' + words + r')).*\b(ligaments?|labrum|capsule|disc|disk|bursa|menisc\w*)\b';

  static final List<LessonChapter> chapters = [
    LessonChapter(
      id: 'upper_limb',
      title: 'Chi trên',
      subtitle: 'Xương, cơ và khớp vai – cánh tay – bàn tay',
      icon: Icons.back_hand_rounded,
      lessons: [
        Lesson(
          id: 'upper_bones',
          title: 'Xương chi trên',
          subtitle: 'Đai vai, cánh tay, cẳng tay, cổ tay',
          icon: Icons.accessibility_new_rounded,
          systems: const [BodySystem.skeletal],
          maxParts: 14,
          include: const [
            r'^right clavicle$',
            r'^right scapula$',
            r'^right humerus$',
            r'^right radius$',
            r'^right ulna$',
            r'^right (scaphoid|lunate|pisiform|trapezium|capitate|hamate)( bone)?$',
            r'^right first metacarpal( bone)?$',
            r'^right fifth metacarpal( bone)?$',
            r'^proximal phalanx of right thumb$',
          ],
        ),
        Lesson(
          id: 'upper_muscles',
          title: 'Cơ chi trên',
          subtitle: 'Cơ vai, cánh tay và cẳng tay',
          icon: Icons.fitness_center_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          maxParts: 15,
          include: const [
            r'^(acromial part of )?right deltoid$',
            r'^right (supraspinatus|infraspinatus)( muscle)?$',
            r'^right teres major$',
            r'^right subscapularis$',
            r'^(long head of )?right biceps brachii$',
            r'^(long head of )?right triceps brachii$',
            r'^right (brachialis|coracobrachialis|brachioradialis)$',
            r'^(humeral head of )?right pronator teres$',
            r'^right (flexor carpi radialis|palmaris longus|extensor digitorum)$',
            r'^(humeral head of )?right flexor carpi ulnaris$',
          ],
        ),
        Lesson(
          id: 'upper_joints',
          title: 'Khớp chi trên',
          subtitle: 'Khớp vai, khuỷu, cổ tay và dây chằng',
          icon: Icons.join_inner_rounded,
          systems: const [BodySystem.skeletal, BodySystem.joint],
          include: [
            r'^right glenoid labrum$',
            r'^right (coracoclavicular|acromioclavicular|coraco-?acromial|coracohumeral|glenohumeral) ligament',
            r'^right (sternoclavicular|costoclavicular|interclavicular) ligament',
            r'^right (ulnar|radial) collateral ligament',
            r'^right annular ligament',
            r'^right (palmar|dorsal) radiocarpal ligament',
            _rightJointPart(
              r'shoulder|glenoid|glenohumeral|acromio\w*|subacromial|subdeltoid|coraco\w*|clavic\w*|elbow|radio-?ulnar|radiocarpal|wrist|carp\w*|humer\w*',
            ),
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'lower_limb',
      title: 'Chi dưới',
      subtitle: 'Xương, cơ và khớp hông – đùi – cẳng chân – bàn chân',
      icon: Icons.directions_walk_rounded,
      lessons: [
        Lesson(
          id: 'lower_bones',
          title: 'Xương chi dưới',
          subtitle: 'Xương chậu, đùi, cẳng chân, cổ chân',
          icon: Icons.accessibility_new_rounded,
          systems: const [BodySystem.skeletal],
          maxParts: 13,
          include: const [
            r'^right hip bone$',
            r'^right femur$',
            r'^right patella$',
            r'^right tibia$',
            r'^right fibula$',
            r'^right talus$',
            r'^right calcaneus$',
            r'^(navicular bone of right foot|right navicular( bone)?)$',
            r'^right cuboid( bone)?$',
            r'^right medial cuneiform( bone)?$',
            r'^right first metatarsal( bone)?$',
            r'^right fifth metatarsal( bone)?$',
            r'^proximal phalanx of right big toe$',
          ],
        ),
        Lesson(
          id: 'lower_muscles',
          title: 'Cơ chi dưới',
          subtitle: 'Cơ mông, đùi và cẳng chân',
          icon: Icons.fitness_center_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          maxParts: 15,
          include: const [
            r'^right gluteus (maximus|medius)$',
            r'^right (rectus femoris|vastus lateralis|vastus medialis|sartorius|gracilis|adductor longus)$',
            r'^(long head of )?right biceps femoris$',
            r'^right (semitendinosus|semimembranosus)$',
            r'^(medial head of )?right gastrocnemius$',
            r'^right (soleus|tibialis anterior|fibularis longus)$',
          ],
        ),
        Lesson(
          id: 'lower_joints',
          title: 'Khớp chi dưới',
          subtitle: 'Khớp háng, gối, cổ chân, sụn chêm',
          icon: Icons.join_inner_rounded,
          systems: const [BodySystem.skeletal, BodySystem.joint],
          include: [
            r'^right (medial|lateral) meniscus$',
            r'^(right )?(anterior|posterior) cruciate ligament( of right knee)?$',
            r'^right (medial|lateral|tibial|fibular) collateral ligament',
            r'^right patellar ligament$',
            r'^right (iliofemoral|ischiofemoral|pubofemoral) ligament$',
            r'^right acetabular labrum$',
            r'^right (deltoid|anterior talofibular|calcaneofibular) ligament',
            r'^right long plantar ligament$',
            _rightJointPart(
              r'hip|acetabul\w*|femor\w*|knee|patell\w*|menisc\w*|cruciate|tibi\w*|fibul\w*|ankle|tal\w*|calcane\w*|tars\w*',
            ),
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'head_neck',
      title: 'Đầu – Mặt – Cổ',
      subtitle: 'Sọ, cơ mặt, răng, cổ và thanh quản',
      icon: Icons.face_rounded,
      lessons: [
        Lesson(
          id: 'skull',
          title: 'Xương sọ',
          subtitle: 'Sọ não và sọ mặt',
          icon: Icons.face_retouching_natural_rounded,
          systems: const [BodySystem.skeletal],
          maxParts: 14,
          include: const [
            r'^frontal bone$',
            r'^right parietal bone$',
            r'^right temporal bone$',
            r'^occipital bone$',
            r'^sphenoid( bone)?$',
            r'^ethmoid( bone)?$',
            r'^right zygomatic bone$',
            r'^right maxilla$',
            r'^mandible$',
            r'^right nasal bone$',
            r'^right lacrimal bone$',
            r'^right palatine bone$',
            r'^vomer$',
            r'^hyoid bone$',
          ],
        ),
        Lesson(
          id: 'face_muscles',
          title: 'Cơ mặt & cơ nhai',
          subtitle: 'Cơ bám da mặt và cơ nhai',
          icon: Icons.sentiment_satisfied_alt_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          include: const [
            r'^right (masseter|temporalis|temporal muscle)( muscle)?$',
            r'^right (medial|lateral) pterygoid( muscle)?$',
            r'^(right )?orbicularis (oculi|oris)( muscle)?$',
            r'^right buccinator( muscle)?$',
            r'^right zygomaticus (major|minor)( muscle)?$',
            r'^(frontal belly of )?(right )?(occipitofrontalis|frontalis)( muscle)?$',
            r'^right levator labii superioris( muscle)?$',
            r'^right (depressor anguli oris|depressor labii inferioris|risorius|levator anguli oris)( muscle)?$',
            r'^(right )?(mentalis|procerus|nasalis)( muscle)?$',
            r'^right platysma$',
          ],
        ),
        Lesson(
          id: 'teeth',
          title: 'Răng',
          subtitle: 'Răng cửa, răng nanh, răng cối',
          icon: Icons.mood_rounded,
          systems: const [BodySystem.skeletal],
          maxParts: 14,
          include: const [
            r'^right upper central .*incisor',
            r'^right upper lateral .*incisor',
            r'^right upper .*canine',
            r'^right upper first .*premolar',
            r'^right upper second .*premolar',
            r'^right upper first .*\bmolar',
            r'^right upper second .*\bmolar',
            r'^right lower .*tooth$',
          ],
        ),
        Lesson(
          id: 'neck_muscles',
          title: 'Cơ cổ',
          subtitle: 'Cơ ức đòn chũm, cơ bậc thang, cơ trên và dưới móng',
          icon: Icons.fitness_center_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          maxParts: 14,
          include: const [
            r'^right sternocleidomastoid$',
            r'^right scalenus (anterior|medius|posterior)$',
            r'^right (digastric|mylohyoid|stylohyoid)$',
            r'^right (omohyoid|sternohyoid|sternothyroid|thyrohyoid)$',
            r'^right platysma$',
            r'^right levator scapulae$',
            r'^right splenius capitis$',
          ],
        ),
        Lesson(
          id: 'larynx',
          title: 'Thanh quản',
          subtitle: 'Sụn thanh quản, dây thanh, khí quản',
          icon: Icons.record_voice_over_rounded,
          systems: const [BodySystem.skeletal, BodySystem.respiratory],
          include: const [
            r'^thyroid cartilage$',
            r'^cricoid cartilage$',
            r'^epiglottis$',
            r'^right arytenoid cartilage$',
            r'^right corniculate cartilage$',
            r'^right cuneiform cartilage$',
            r'^hyoid bone$',
            r'^right vocal (ligament|fold|cord)$',
            r'^right conus elasticus$',
            r'^median cricothyroid ligament$',
            r'^right thyrohyoid membrane$',
            r'^trachea$',
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'spine',
      title: 'Cột sống',
      subtitle: 'Đốt sống, đĩa đệm và cơ lưng',
      icon: Icons.height_rounded,
      lessons: [
        Lesson(
          id: 'vertebrae',
          title: 'Đốt sống',
          subtitle: 'Cổ, ngực, thắt lưng, cùng – cụt',
          icon: Icons.height_rounded,
          systems: const [BodySystem.skeletal],
          include: const [
            r'^atlas$',
            r'^axis$',
            r'^fourth cervical vertebra$',
            r'^seventh cervical vertebra$',
            r'^(first|sixth|twelfth) thoracic vertebra$',
            r'^first lumbar vertebra$',
            r'^third lumbar vertebra$',
            r'^fifth lumbar vertebra$',
            r'^sacrum$',
            r'^coccyx$',
          ],
        ),
        Lesson(
          id: 'spine_discs',
          title: 'Đĩa đệm & dây chằng',
          subtitle: 'Đĩa gian đốt sống và dây chằng cột sống',
          icon: Icons.join_inner_rounded,
          systems: const [BodySystem.skeletal, BodySystem.joint],
          exclude: _noLeft,
          include: const [
            r'^(anterior|posterior) longitudinal ligament$',
            r'^(ligamentum flavum|ligamenta flava)',
            r'^(supraspinous|nuchal|interspinous) ligament',
            r'^ligamentum nuchae$',
            r'^(right )?(iliolumbar|sacrospinous|sacrotuberous) ligament',
            r'^intervertebral (disk|disc) of fifth cervical vertebra$',
            r'^intervertebral (disk|disc) of seventh thoracic vertebra$',
            r'^intervertebral (disk|disc) of third lumbar vertebra$',
            r'^intervertebral (disk|disc) of fifth lumbar vertebra$',
          ],
        ),
        Lesson(
          id: 'back_muscles',
          title: 'Cơ lưng',
          subtitle: 'Cơ thang, lưng rộng, cơ dựng sống',
          icon: Icons.fitness_center_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          maxParts: 13,
          include: const [
            r'^((descending|transverse|ascending) part of )?right trapezius$',
            r'^right latissimus dorsi$',
            r'^right rhomboid (major|minor)$',
            r'^right levator scapulae$',
            r'^right (iliocostalis lumborum|longissimus thoracis|spinalis thoracis)$',
            r'^right (splenius capitis|semispinalis capitis)$',
            r'^right quadratus lumborum$',
            r'^right serratus posterior (superior|inferior)$',
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'thorax',
      title: 'Ngực',
      subtitle: 'Tim, phổi, lồng ngực và mạch máu lớn',
      icon: Icons.favorite_rounded,
      lessons: [
        Lesson(
          id: 'heart',
          title: 'Tim',
          subtitle: 'Buồng tim, van tim, mạch lớn',
          icon: Icons.favorite_rounded,
          systems: const [BodySystem.cardiovascular],
          maxParts: 14,
          include: const [
            r'^heart$',
            r'^(wall of )?right atrium$',
            r'^(wall of )?right ventricle$',
            r'^(wall of )?left atrium$',
            r'^(wall of )?left ventricle$',
            r'^wall of ventricle$',
            r'^(interventricular|interatrial) septum$',
            r'^ascending aorta$',
            r'^pulmonary trunk$',
            r'^(superior|inferior) vena cava$',
            r'^(right|left) coronary artery$',
            r'^(anterior|posterior) leaflet of mitral valve$',
            r'^(anterior|septal) leaflet of tricuspid valve$',
            r'^anterior cusp of aortic valve$',
            r'^(posterior|right anterior) cusp of pulmonary valve$',
            r'^anterior papillary muscle of right ventricle$',
          ],
        ),
        Lesson(
          id: 'lungs',
          title: 'Phổi & phế quản',
          subtitle: 'Thùy phổi, khí quản, cây phế quản',
          icon: Icons.air_rounded,
          systems: const [BodySystem.respiratory],
          maxParts: 14,
          include: const [
            r'^(right|left) lung$',
            r'^(superior|middle|inferior) lobe of (right|left) lung$',
            r'^trachea$',
            r'^(right|left) main bronchus',
            r'^(right|left) (visceral |parietal )?pleura$',
            r'^right (apical|anterior|posterior|superior) segmental bronchial tree$',
            r'^right (medial|lateral) basal segmental bronchial tree$',
            r'^(superior|inferior) lingular bronchial tree$',
            r'^left apical segmental bronchial tree$',
          ],
        ),
        Lesson(
          id: 'rib_cage',
          title: 'Lồng ngực',
          subtitle: 'Xương ức, xương sườn, sụn sườn',
          icon: Icons.view_week_rounded,
          systems: const [BodySystem.skeletal],
          include: const [
            r'^manubrium( of sternum)?$',
            r'^body of sternum$',
            r'^xiphoid process$',
            r'^right first rib$',
            r'^right second rib$',
            r'^right fifth rib$',
            r'^right seventh rib$',
            r'^right tenth rib$',
            r'^right eleventh rib$',
            r'^right twelfth rib$',
            r'^right first costal cartilage$',
            r'^right seventh costal cartilage$',
          ],
        ),
        Lesson(
          id: 'chest_muscles',
          title: 'Cơ thành ngực',
          subtitle: 'Cơ ngực, cơ gian sườn, cơ hoành',
          icon: Icons.fitness_center_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          include: const [
            r'^(sternocostal part of )?right pectoralis major$',
            r'^clavicular part of right pectoralis major$',
            r'^right pectoralis minor$',
            r'^right serratus anterior$',
            r'^right subclavius$',
            r'^(right )?external intercostal( muscle)?s?$',
            r'^(right )?internal intercostal( muscle)?s?$',
            r'^(right )?innermost intercostal( muscle)?s?$',
            r'^right transversus thoracis$',
            r'^diaphragm$',
          ],
        ),
        Lesson(
          id: 'great_vessels',
          title: 'Mạch máu lớn',
          subtitle: 'Động mạch chủ và các nhánh chính',
          icon: Icons.bloodtype_rounded,
          systems: const [BodySystem.cardiovascular],
          maxParts: 14,
          include: const [
            r'^ascending aorta$',
            r'^(arch of aorta|aortic arch)$',
            r'^descending thoracic aorta$',
            r'^abdominal aorta$',
            r'^brachiocephalic trunk$',
            r'^right common carotid artery$',
            r'^right subclavian artery$',
            r'^right brachial artery$',
            r'^right radial artery$',
            r'^right common iliac artery$',
            r'^right femoral artery$',
            r'^right popliteal artery$',
            r'^(superior|inferior) vena cava$',
            r'^right internal jugular vein$',
            r'^right great saphenous vein$',
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'abdomen',
      title: 'Bụng',
      subtitle: 'Ống tiêu hóa, gan mật tụy, thành bụng',
      icon: Icons.restaurant_rounded,
      lessons: [
        Lesson(
          id: 'gi_tract',
          title: 'Ống tiêu hóa',
          subtitle: 'Từ thực quản đến trực tràng',
          icon: Icons.restaurant_rounded,
          systems: const [BodySystem.digestive],
          maxParts: 13,
          include: const [
            r'^tongue$',
            r'^(o)?esophagus$',
            r'^stomach$',
            r'^duodenum$',
            r'^(proximal part of )?jejunum$',
            r'^(distal part of )?ileum$',
            r'^(cecum|caecum)$',
            r'^(vermiform )?appendix$',
            r'^ascending colon$',
            r'^transverse colon$',
            r'^descending colon$',
            r'^sigmoid colon$',
            r'^rectum$',
            r'^anal canal$',
          ],
        ),
        Lesson(
          id: 'liver_pancreas',
          title: 'Gan – Mật – Tụy',
          subtitle: 'Gan, túi mật, đường mật, tụy',
          icon: Icons.science_rounded,
          systems: const [BodySystem.digestive],
          include: const [
            r'^liver$',
            r'^(right|left|caudate|quadrate) lobe of liver$',
            r'^gallbladder$',
            r'^cystic duct$',
            r'^common hepatic duct$',
            r'^(common )?bile duct$',
            r'^pancreas$',
            r'^(head|body|tail) of pancreas$',
            r'^pancreatic duct$',
            r'^hepatovenous segment (ii|iv|vi|viii)$',
          ],
        ),
        Lesson(
          id: 'abdominal_wall',
          title: 'Cơ thành bụng',
          subtitle: 'Cơ thẳng bụng, cơ chéo, cơ thắt lưng',
          icon: Icons.fitness_center_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          include: const [
            r'^right rectus abdominis$',
            r'^right external oblique$',
            r'^right internal oblique$',
            r'^right transversus abdominis$',
            r'^linea alba$',
            r'^right pyramidalis$',
            r'^right quadratus lumborum$',
            r'^right psoas major$',
            r'^right iliacus$',
            r'^diaphragm$',
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'pelvis',
      title: 'Chậu hông',
      subtitle: 'Tiết niệu, sinh dục và đáy chậu',
      icon: Icons.water_drop_rounded,
      lessons: [
        Lesson(
          id: 'urinary',
          title: 'Hệ tiết niệu',
          subtitle: 'Thận, niệu quản, bàng quang',
          icon: Icons.water_drop_rounded,
          systems: const [BodySystem.urinary],
          include: const [
            r'^(right|left) kidney$',
            r'^(right|left) renal pelvis$',
            r'^(right|left) ureter$',
            r'^urinary bladder$',
            r'^(male |female )?urethra$',
          ],
        ),
        Lesson(
          id: 'reproductive',
          title: 'Cơ quan sinh dục',
          subtitle: 'Sinh dục nam và nữ',
          icon: Icons.wc_rounded,
          systems: const [BodySystem.reproductive],
          maxParts: 14,
          include: const [
            r'^right testis$',
            r'^right epididymis$',
            r'^right (deferent duct|ductus deferens|vas deferens)$',
            r'^right seminal vesicle$',
            r'^prostate( gland)?$',
            r'^(corpus cavernosum of penis|right corpus cavernosum)',
            r'^corpus spongiosum of penis$',
            r'^glans penis$',
            r'^uterus$',
            r'^right ovary$',
            r'^right (uterine tube|fallopian tube)$',
            r'^vagina$',
            r'^(clitoris|glans of clitoris)$',
          ],
        ),
        Lesson(
          id: 'pelvic_floor',
          title: 'Khung chậu & đáy chậu',
          subtitle: 'Xương chậu, cơ nâng hậu môn',
          icon: Icons.airline_seat_recline_normal_rounded,
          systems: const [BodySystem.skeletal, BodySystem.muscular],
          include: const [
            r'^right hip bone$',
            r'^sacrum$',
            r'^coccyx$',
            r'^pubic symphysis$',
            r'^right levator ani$',
            r'^right (iliococcygeus|pubococcygeus|puborectalis)$',
            r'^right coccygeus$',
            r'^right piriformis$',
            r'^right obturator internus$',
            r'^external anal sphincter$',
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'nervous',
      title: 'Thần kinh',
      subtitle: 'Não, tủy sống và dây thần kinh sọ',
      icon: Icons.psychology_rounded,
      lessons: [
        Lesson(
          id: 'brain',
          title: 'Não bộ',
          subtitle: 'Đại não, tiểu não, thân não',
          icon: Icons.psychology_rounded,
          systems: const [BodySystem.nervous],
          exclude: _noRight,
          maxParts: 14,
          include: const [
            r'^(left )?(frontal|parietal|temporal|occipital) lobe$',
            r'^(left )?cerebral hemisphere$',
            r'^cerebellum$',
            r'^midbrain$',
            r'^pons$',
            r'^medulla oblongata$',
            r'^corpus callosum$',
            r'^(left )?(precentral|postcentral) gyrus$',
            r'^(left )?(superior|middle|inferior) frontal gyrus$',
            r'^(anterior part of )?(left )?superior temporal gyrus$',
            r'^(left )?insula$',
            r'^(left )?cingulate gyrus$',
          ],
        ),
        Lesson(
          id: 'brain_deep',
          title: 'Cấu trúc sâu của não',
          subtitle: 'Đồi thị, nhân nền, hệ viền, não thất',
          icon: Icons.blur_on_rounded,
          systems: const [BodySystem.nervous],
          exclude: _noRight,
          maxParts: 14,
          include: const [
            r'^(left )?thalamus$',
            r'^hypothalamus$',
            r'^(left )?caudate nucleus$',
            r'^(left )?putamen$',
            r'^(left )?globus pallidus$',
            r'^(left )?hippocampus$',
            r'^(left )?amygdala$',
            r'^(left )?fornix of forebrain$',
            r'^(left )?internal capsule$',
            r'^(left )?lateral ventricle$',
            r'^third ventricle$',
            r'^fourth ventricle$',
            r'^mammillary body$',
            r'^pineal (body|gland)$',
          ],
        ),
        Lesson(
          id: 'spinal_nerves',
          title: 'Tủy sống & dây thần kinh',
          subtitle: 'Tủy sống, đám rối, thần kinh chi',
          icon: Icons.cable_rounded,
          systems: const [BodySystem.nervous],
          exclude: _noLeft,
          include: const [
            r'^spinal cord$',
            r'^cauda equina$',
            r'^(right )?brachial plexus$',
            r'^right (musculocutaneous|axillary|radial|median|ulnar) nerve$',
            r'^(right )?phrenic nerve$',
            r'^right (femoral|obturator|sciatic) nerve$',
            r'^right (tibial|common fibular|common peroneal) nerve$',
            r'^central canal of spinal cord$',
          ],
        ),
        Lesson(
          id: 'cranial_nerves',
          title: 'Dây thần kinh sọ',
          subtitle: '12 đôi dây thần kinh sọ',
          icon: Icons.account_tree_rounded,
          systems: const [BodySystem.nervous],
          exclude: _noLeft,
          maxParts: 14,
          include: const [
            r'^(right )?(olfactory|optic|oculomotor|trochlear|trigeminal|abducent|abducens|facial|vestibulocochlear|glossopharyngeal|vagus|accessory|hypoglossal) nerve$',
            r'^optic chiasm$',
            r'^right optic tract$',
            r'^(superior|inferior) branch of right oculomotor nerve$',
            r'^right (ophthalmic|maxillary|mandibular) nerve$',
            r'^right trigeminal ganglion$',
            r'^right (frontal|nasociliary|lacrimal) nerve$',
            r'^right ciliary ganglion$',
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'senses',
      title: 'Giác quan',
      subtitle: 'Mắt và tai',
      icon: Icons.visibility_rounded,
      lessons: [
        Lesson(
          id: 'eye',
          title: 'Mắt',
          subtitle: 'Nhãn cầu và lệ đạo',
          icon: Icons.visibility_rounded,
          systems: const [BodySystem.sensory],
          exclude: _noLeft,
          maxParts: 13,
          include: const [
            r'^right (eyeball|eye)$',
            r'^right (cornea|sclera|iris|lens|choroid)$',
            r'^(optic part of right retina|right retina)$',
            r'^right vitreous body$',
            r'^anterior chamber of right eyeball$',
            r'^(right corona ciliaris|right ciliary body)$',
            r'^right lacrimal gland$',
            r'^right lacrimal sac$',
            r'^right nasolacrimal duct$',
            r'^tarsal plate of right upper eyelid$',
          ],
        ),
        Lesson(
          id: 'eye_muscles',
          title: 'Cơ vận nhãn',
          subtitle: 'Các cơ thẳng và cơ chéo của mắt',
          icon: Icons.remove_red_eye_outlined,
          systems: const [BodySystem.sensory, BodySystem.muscular],
          include: const [
            r'^right (superior|inferior|medial|lateral) rectus$',
            r'^right (superior|inferior) oblique$',
            r'^right levator palpebrae superioris$',
            r'^right common tendinous ring$',
          ],
        ),
        Lesson(
          id: 'ear',
          title: 'Tai',
          subtitle: 'Tai ngoài, tai giữa, tai trong',
          icon: Icons.hearing_rounded,
          systems: const [BodySystem.sensory],
          exclude: _noLeft,
          include: const [
            r'^(right )?(external ear|auricle)$',
            r'^right external acoustic meatus$',
            r'^right tympanic membrane$',
            r'^right (malleus|incus|stapes)$',
            r'^right cochlea$',
            r'^right (anterior|posterior|lateral) semicircular (canal|duct)$',
            r'^right vestibule',
            r'^right (auditory|pharyngotympanic) tube$',
            r'^right vestibulocochlear nerve$',
          ],
        ),
      ],
    ),
    LessonChapter(
      id: 'endocrine_lymph',
      title: 'Nội tiết & bạch huyết',
      subtitle: 'Tuyến nội tiết, lách, tuyến ức, hạch',
      icon: Icons.science_rounded,
      lessons: [
        Lesson(
          id: 'endocrine',
          title: 'Tuyến nội tiết',
          subtitle: 'Tuyến yên, giáp, ức, thượng thận',
          icon: Icons.science_rounded,
          systems: const [BodySystem.endocrine],
          include: const [
            r'^(pituitary gland|hypophysis)$',
            r'^thyroid gland$',
            r'^(right|left) lobe of thyroid gland$',
            r'^isthmus of thyroid gland$',
            r'^(right|left) (superior |inferior )?parathyroid gland$',
            r'^thymus$',
            r'^(right|left) lobe of thymus$',
            r'^(right|left) (adrenal|suprarenal) gland$',
          ],
        ),
        Lesson(
          id: 'lymphatic',
          title: 'Hệ bạch huyết',
          subtitle: 'Lách, tuyến ức, ống ngực, hạch',
          icon: Icons.bubble_chart_rounded,
          systems: const [BodySystem.lymphatic],
          include: const [
            r'^spleen$',
            r'^thymus$',
            r'^(right|left) lobe of thymus$',
            r'^thoracic duct$',
            r'^cisterna chyli$',
            r'^right lymphatic duct$',
            r'^(right )?(palatine|lingual|pharyngeal|tubal) tonsil$',
            r'^(right )?(axillary|inguinal|deep cervical|submandibular|popliteal|cubital|parasternal|tracheobronchial|mesenteric)\b.*lymph nodes?$',
            r'^(?!left\b).*lymph nodes?$',
          ],
        ),
      ],
    ),
  ];
}
