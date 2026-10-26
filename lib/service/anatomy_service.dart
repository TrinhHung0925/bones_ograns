import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../model/anatomy_part.dart';
import '../model/body_system.dart';
import '../resource/app_resource.dart';

/// Read-only index of every selectable part, built by tools/anatomy_pipeline.
class AnatomyService extends GetxService {
  List<AnatomyPart> _parts = const [];
  Map<String, AnatomyPart> _byId = const {};
  Map<BodySystem, int> _counts = const {};

  Future<AnatomyService> init() async {
    final raw = await rootBundle.loadString(AnatomyAsset.partsJson);
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _parts = list.map(AnatomyPart.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _byId = {for (final p in _parts) p.id: p};
    _counts = {};
    for (final p in _parts) {
      _counts[p.system] = (_counts[p.system] ?? 0) + 1;
    }
    return this;
  }

  List<AnatomyPart> get parts => _parts;

  AnatomyPart? byId(String? id) => id == null ? null : _byId[id];

  int countIn(BodySystem system) => _counts[system] ?? 0;

  List<AnatomyPart> inSystem(BodySystem system) =>
      _parts.where((p) => p.system == system).toList();

  List<AnatomyPart> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final words = q.split(RegExp(r'\s+'));
    return _parts.where((p) {
      final name = p.name.toLowerCase();
      return words.every(name.contains);
    }).toList();
  }
}
