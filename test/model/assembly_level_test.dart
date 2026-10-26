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

  test('every level resolves to a playable set of pieces', () {
    for (final level in AssemblyLevel.all) {
      final pieces = level.resolve(anatomy.parts);
      expect(pieces.length, greaterThanOrEqualTo(3), reason: level.id);
      // Big levels stay manageable on a phone.
      expect(pieces.length, lessThanOrEqualTo(36), reason: level.id);
      expect(pieces.map((p) => p.id).toSet().length, pieces.length, reason: level.id);
      final partIds = [for (final piece in pieces) ...piece.parts.map((p) => p.id)];
      expect(partIds.toSet().length, partIds.length, reason: '${level.id}: a part is in two pieces');
      for (final piece in pieces) {
        expect(piece.parts, isNotEmpty, reason: '${level.id}: ${piece.id}');
        expect(piece.nameVi, isNotEmpty, reason: '${level.id}: ${piece.id}');
        for (final part in piece.parts) {
          expect(level.systems, contains(part.system), reason: '${level.id}: ${part.name}');
        }
      }
    }
  });

  test('every group of every level matches some parts', () {
    for (final level in AssemblyLevel.all) {
      final ids = level.resolve(anatomy.parts).map((p) => p.id).toSet();
      for (final group in level.groups) {
        expect(ids, contains(group.id), reason: '${level.id}: empty group ${group.id}');
      }
    }
  });

  test('group ids never collide with part ids', () {
    for (final level in AssemblyLevel.all) {
      for (final group in level.groups) {
        expect(anatomy.byId(group.id), isNull, reason: group.id);
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

  test('the full skeleton level covers every skeletal part', () {
    // Intentionally excluded skeletal parts (none at the moment).
    const excluded = <String>{};
    final pieces = level('full_skeleton').resolve(anatomy.parts);
    final covered = {for (final piece in pieces) ...piece.parts.map((p) => p.name)};
    final missing = [
      for (final part in anatomy.inSystem(BodySystem.skeletal))
        if (!covered.contains(part.name) && !excluded.contains(part.name)) part.name,
    ];
    expect(missing, isEmpty);
    expect(pieces.length, inInclusiveRange(25, 35));
    expect(pieces.every((p) => p.isGroup), isTrue);
  });

  test('the full body level mixes the skeleton with the main organs', () {
    final pieces = level('full_body').resolve(anatomy.parts);
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
