import 'package:bones_ograns/model/assembly_level.dart';
import 'package:bones_ograns/model/body_system.dart';
import 'package:bones_ograns/service/anatomy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AnatomyService anatomy;

  setUpAll(() async {
    anatomy = await AnatomyService().init();
  });

  AssemblyLevel level(String id) => AssemblyLevel.all.firstWhere((l) => l.id == id);

  /// Every way each level can be played: (level, detail or null).
  Iterable<(AssemblyLevel, AssemblyDetail?)> plays() sync* {
    for (final level in AssemblyLevel.all) {
      if (level.details.isEmpty) {
        yield (level, null);
      } else {
        for (final detail in level.details) {
          yield (level, detail);
        }
      }
    }
  }

  test('every level at every detail resolves to a playable set of pieces', () {
    for (final (level, detail) in plays()) {
      final key = '${level.id}@${detail?.name}';
      final pieces = level.resolve(anatomy.parts, detail: detail);
      expect(pieces.length, greaterThanOrEqualTo(3), reason: key);
      // Big levels stay manageable on a phone.
      expect(pieces.length, lessThanOrEqualTo(detail == AssemblyDetail.fine ? 64 : 40), reason: key);
      expect(pieces.map((p) => p.id).toSet().length, pieces.length, reason: key);
      final partIds = [for (final piece in pieces) ...piece.parts.map((p) => p.id)];
      expect(partIds.toSet().length, partIds.length, reason: '$key: a part is in two pieces');
      for (final piece in pieces) {
        expect(piece.parts, isNotEmpty, reason: '$key: ${piece.id}');
        expect(piece.nameVi, isNotEmpty, reason: '$key: ${piece.id}');
        for (final part in piece.parts) {
          expect(level.systems, contains(part.system), reason: '$key: ${part.name}');
        }
      }
    }
  });

  test('every group of every level and detail matches some parts', () {
    for (final (level, detail) in plays()) {
      final ids = level.resolve(anatomy.parts, detail: detail).map((p) => p.id).toSet();
      final groups = detail == null ? level.groups : level.variants[detail]!;
      for (final group in groups) {
        expect(ids, contains(group.id), reason: '${level.id}@${detail?.name}: empty group ${group.id}');
      }
    }
  });

  test('group ids never collide with part ids', () {
    for (final level in AssemblyLevel.all) {
      for (final groups in level.allGroupings) {
        for (final group in groups) {
          expect(anatomy.byId(group.id), isNull, reason: group.id);
        }
      }
    }
  });

  test('right-side levels contain no left-side parts and vice versa', () {
    for (final (id, other) in [
      ('arm_right', 'left'),
      ('leg_right', 'left'),
      ('hand_right', 'left'),
      ('foot_right', 'left'),
      ('arm_left', 'right'),
      ('leg_left', 'right'),
      ('hand_left', 'right'),
      ('foot_left', 'right'),
    ]) {
      for (final piece in level(id).resolve(anatomy.parts)) {
        expect(piece.nameEn.toLowerCase(), isNot(contains(other)), reason: '$id: ${piece.nameEn}');
      }
    }
  });

  test('the full skeleton level covers every skeletal part at every detail', () {
    final skeleton = level('full_skeleton');
    expect(skeleton.details, AssemblyDetail.values);
    const expectedCounts = {
      AssemblyDetail.coarse: (8, 8),
      AssemblyDetail.medium: (25, 35),
      AssemblyDetail.fine: (45, 64),
    };
    for (final detail in skeleton.details) {
      final pieces = skeleton.resolve(anatomy.parts, detail: detail);
      final covered = {for (final piece in pieces) ...piece.parts.map((p) => p.id)};
      final missing = [
        for (final part in anatomy.inSystem(BodySystem.skeletal))
          if (!covered.contains(part.id)) part.name,
      ];
      expect(missing, isEmpty, reason: detail.name);
      final (min, max) = expectedCounts[detail]!;
      expect(pieces.length, inInclusiveRange(min, max), reason: detail.name);
    }
    // The big-block cut has whole arms and legs, hands and feet included.
    final coarse = skeleton.resolve(anatomy.parts, detail: AssemblyDetail.coarse);
    final rightArm = coarse.firstWhere((p) => p.id == 'g_arm_right');
    expect(rightArm.parts.map((p) => p.name), containsAll(['Right humerus', 'Right scaphoid', 'Right clavicle']));
  });

  test('whole-limb levels offer three details, coarse being the four big blocks', () {
    for (final id in ['whole_arm_right', 'whole_arm_left', 'whole_leg_right', 'whole_leg_left']) {
      final limb = level(id);
      expect(limb.details, AssemblyDetail.values, reason: id);
      expect(limb.resolve(anatomy.parts, detail: AssemblyDetail.coarse), hasLength(4), reason: id);
      final medium = limb.resolve(anatomy.parts, detail: AssemblyDetail.medium).length;
      final fine = limb.resolve(anatomy.parts, detail: AssemblyDetail.fine).length;
      expect(medium, inInclusiveRange(10, 14), reason: id);
      expect(fine, greaterThan(medium), reason: id);
      // Every detail covers the same bones.
      Set<String> partsAt(AssemblyDetail d) => {
        for (final piece in limb.resolve(anatomy.parts, detail: d)) ...piece.parts.map((p) => p.id),
      };
      expect(partsAt(AssemblyDetail.coarse), partsAt(AssemblyDetail.fine), reason: id);
      expect(partsAt(AssemblyDetail.medium), partsAt(AssemblyDetail.fine), reason: id);
    }
  });

  test('progress keys: the default detail keeps the plain level id', () {
    final arm = level('whole_arm_right');
    expect(arm.defaultDetail, AssemblyDetail.medium);
    expect(arm.progressId(null), 'whole_arm_right');
    expect(arm.progressId(AssemblyDetail.medium), 'whole_arm_right');
    expect(arm.progressId(AssemblyDetail.coarse), 'whole_arm_right@coarse');
    expect(level('skull').progressId(null), 'skull');
    expect(AssemblySelection(arm, AssemblyDetail.fine).progressId, 'whole_arm_right@fine');
  });

  test('the full body level mixes the skeleton with the main organs', () {
    for (final detail in level('full_body').details) {
      final pieces = level('full_body').resolve(anatomy.parts, detail: detail);
      final skeletal = {
        for (final piece in pieces)
          for (final part in piece.parts)
            if (part.system == BodySystem.skeletal) part.id,
      };
      expect(skeletal.length, anatomy.countIn(BodySystem.skeletal), reason: detail.name);
    }
    final pieces = level('full_body').resolve(anatomy.parts, detail: AssemblyDetail.coarse);
    final ids = pieces.map((p) => p.id).toSet();
    expect(ids, containsAll(['g_head', 'g_spine', 'g_rib_cage', 'g_heart', 'g_liver', 'g_brain', 'g_airway']));
    final systems = {for (final p in pieces) p.system};
    expect(systems, containsAll([BodySystem.skeletal, BodySystem.cardiovascular, BodySystem.urinary]));
    final skeletal = {
      for (final piece in pieces)
        for (final part in piece.parts)
          if (part.system == BodySystem.skeletal) part.id,
    };
    expect(skeletal.length, anatomy.countIn(BodySystem.skeletal));
  });

  test('levels have unique ids and chain through next', () {
    final ids = AssemblyLevel.all.map((l) => l.id).toSet();
    expect(ids.length, AssemblyLevel.all.length);
    for (var i = 0; i < AssemblyLevel.all.length - 1; i++) {
      expect(AssemblyLevel.all[i].next, same(AssemblyLevel.all[i + 1]));
    }
    expect(AssemblyLevel.all.last.next, isNull);
  });

  test('saved progress keys of the original levels are kept', () {
    for (final id in ['arm_right', 'leg_right', 'organs', 'skull', 'hand_right', 'foot_right', 'thorax', 'spine']) {
      expect(AssemblyLevel.all.any((l) => l.id == id), isTrue, reason: id);
    }
  });

  test('pieces serialise as part ids or {id, parts} groups', () {
    final single = level('arm_right').resolve(anatomy.parts).first;
    expect(single.toJson(), isA<String>());
    final group = level('full_skeleton').resolve(anatomy.parts).first;
    final json = group.toJson() as Map<String, Object?>;
    expect(json['id'], group.id);
    expect(json['parts'], hasLength(group.parts.length));
  });

  test('print piece counts', () {
    for (final chapter in AssemblyLevel.chapters) {
      for (final level in chapter.levels) {
        // ignore: avoid_print
        print('${chapter.id}/${level.id}: ${level.resolve(anatomy.parts).length}');
      }
    }
  });
}
