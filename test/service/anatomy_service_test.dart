import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bones_ograns/model/body_system.dart';
import 'package:bones_ograns/service/anatomy_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Node names in a GLB's JSON chunk, i.e. the part ids the viewer can pick.
Set<String> _glbNodeNames(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final jsonLength = data.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
  return {for (final node in json['nodes'] as List) (node as Map)['name'] as String};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every part in parts.json exists in its system model and vice versa', () async {
    final repository = await AnatomyService().init();
    expect(repository.parts, isNotEmpty);
    for (final system in BodySystem.values) {
      final file = File('assets/anatomy/models/${system.name}.glb');
      final expected = repository.inSystem(system).map((p) => p.id).toSet();
      if (expected.isEmpty) {
        expect(file.existsSync(), isFalse, reason: '${system.name} has a model but no parts');
        continue;
      }
      expect(_glbNodeNames(file), expected, reason: system.name);
    }
  });

  test('search matches every word, case-insensitively', () async {
    final repository = await AnatomyService().init();
    final results = repository.search('RIGHT femur');
    expect(results, isNotEmpty);
    for (final part in results) {
      expect(part.name.toLowerCase(), allOf(contains('right'), contains('femur')));
    }
    expect(repository.search('   '), isEmpty);
  });
}
