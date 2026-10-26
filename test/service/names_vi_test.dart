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

  String? vi(String english) => anatomy.parts.firstWhere((p) => p.name == english).nameVi;

  test('known parts have standard Vietnamese names', () {
    const expected = {
      'Right femur': 'Xương đùi phải',
      'Left humerus': 'Xương cánh tay trái',
      'Distal phalanx of left index finger': 'Đốt xa ngón trỏ trái',
      'Proximal phalanx of right thumb': 'Đốt gần ngón cái phải',
      'Right fifth metacarpal bone': 'Xương đốt bàn tay thứ năm phải',
      'Third thoracic vertebra': 'Đốt sống ngực 3',
      'Left fifth rib': 'Xương sườn 5 trái',
      'Hepatovenous segment VII': 'Phân thùy gan VII',
      'Wall of left atrium': 'Thành tâm nhĩ trái',
      'Stomach': 'Dạ dày',
      'Left kidney': 'Thận trái',
      'Ascending aorta': 'Động mạch chủ lên',
      'Long head of left biceps brachii': 'Đầu dài cơ nhị đầu cánh tay trái',
      'Right upper first secondary molar tooth': 'Răng hàm lớn thứ nhất hàm trên phải',
      'Navicular bone of right foot': 'Xương ghe phải',
      'Right scaphoid': 'Xương thuyền phải',
    };
    expected.forEach((en, name) => expect(vi(en), name, reason: en));
  });

  test('every skeletal part has a Vietnamese name', () {
    final missing = [
      for (final p in anatomy.inSystem(BodySystem.skeletal))
        if (p.nameVi == null) p.name,
    ];
    expect(missing, isEmpty);
  });

  test('every single-part piece of the organ levels has a Vietnamese name', () {
    // Grouped pieces carry their own Vietnamese name.
    for (final id in ['organs', 'heart', 'digestive', 'urinary', 'brain', 'full_body']) {
      final level = AssemblyLevel.all.firstWhere((l) => l.id == id);
      for (final piece in level.resolve(anatomy.parts)) {
        if (piece.isGroup) continue;
        for (final part in piece.parts) {
          expect(part.nameVi, isNotNull, reason: '$id: ${part.name}');
        }
      }
    }
  });

  test('displayName falls back to English', () {
    for (final p in anatomy.parts) {
      expect(p.displayName, p.nameVi ?? p.name);
    }
  });

  test('search finds Vietnamese names without accents', () {
    expect(anatomy.search('xuong dui phai').first.name, 'Right femur');
    expect(anatomy.search('right femur').first.name, 'Right femur');
  });
}
