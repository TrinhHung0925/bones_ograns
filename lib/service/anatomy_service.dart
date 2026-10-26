import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../model/anatomy_part.dart';
import '../model/body_system.dart';
import '../resource/app_resource.dart';
import '../utils/part_search.dart';

/// Read-only index of every selectable part, built by tools/anatomy_pipeline.
class AnatomyService extends GetxService {
  List<AnatomyPart> _parts = const [];
  Map<String, AnatomyPart> _byId = const {};
  Map<BodySystem, int> _counts = const {};
  PartSearchIndex _index = PartSearchIndex(const []);

  Future<AnatomyService> init() async {
    final raw = await rootBundle.loadString(AnatomyAsset.partsJson);
    final namesVi = await _loadNamesVi();
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _parts = list.map((json) => AnatomyPart.fromJson(json, nameVi: namesVi[json['id']])).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _byId = {for (final p in _parts) p.id: p};
    _counts = {};
    for (final p in _parts) {
      _counts[p.system] = (_counts[p.system] ?? 0) + 1;
    }
    _index = PartSearchIndex(_parts);
    return this;
  }

  /// Vietnamese names by part id; empty when the file is missing, so the app
  /// still works with English names only.
  Future<Map<String, String>> _loadNamesVi() async {
    try {
      final raw = await rootBundle.loadString(AnatomyAsset.namesViJson);
      return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    } on FlutterError {
      return const {};
    }
  }

  List<AnatomyPart> get parts => _parts;

  AnatomyPart? byId(String? id) => id == null ? null : _byId[id];

  int countIn(BodySystem system) => _counts[system] ?? 0;

  List<AnatomyPart> inSystem(BodySystem system) => _parts.where((p) => p.system == system).toList();

  /// Parts whose Vietnamese or English name holds every word of [query],
  /// ignoring case and accents; best matches first.
  List<AnatomyPart> search(String query) => _index.search(query);
}
