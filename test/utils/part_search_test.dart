import 'package:bones_ograns/model/anatomy_part.dart';
import 'package:bones_ograns/model/body_system.dart';
import 'package:bones_ograns/utils/part_search.dart';
import 'package:flutter_test/flutter_test.dart';

AnatomyPart _part(String id, String name, [String? vi]) =>
    AnatomyPart(id: id, name: name, nameVi: vi, system: BodySystem.skeletal);

void main() {
  final parts = [
    _part('1', 'Right femur', 'Xương đùi phải'),
    _part('2', 'Left femur', 'Xương đùi trái'),
    _part('3', 'Right tibia', 'Xương chày phải'),
    _part('4', 'Femoral artery', 'Động mạch đùi'),
    _part('5', 'Heart'),
    _part('6', 'Right fibula', 'Xương mác phải'),
  ];
  final index = PartSearchIndex(parts);
  List<String> ids(String q) => index.search(q).map((p) => p.id).toList();

  test('foldVietnamese drops case and diacritics', () {
    expect(foldVietnamese('Xương Đùi PHẢI'), 'xuong dui phai');
    expect(foldVietnamese('Động mạch chủ'), 'dong mach chu');
    expect(foldVietnamese('Răng hàm lớn thứ nhất'), 'rang ham lon thu nhat');
  });

  test('matches Vietnamese without accents', () {
    expect(ids('xuong dui'), ['1', '2']);
    expect(ids('Xương đùi phải'), ['1']);
  });

  test('matches English names too', () {
    expect(ids('right femur'), ['1']);
    expect(ids('HEART'), ['5']);
  });

  test('every word must match', () {
    expect(ids('xuong dui chay'), isEmpty);
    expect(ids('phai xuong'), unorderedEquals(['1', '3', '6']));
  });

  test('exact and prefix matches rank first', () {
    // "dui" is in "Động mạch đùi" and both femurs; the femurs start with
    // neither, so the shorter names win only on the tie-break.
    expect(ids('dong mach').first, '4');
    final femur = ids('femur');
    expect(femur.take(2), unorderedEquals(['1', '2']));
    expect(ids('xuong dui phai').first, '1');
    expect(ids('xuong'), hasLength(4));
    expect(index.search('Xương mác phải').first.id, '6');
  });

  test('blank query finds nothing', () {
    expect(ids('   '), isEmpty);
  });
}
