import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stw_map.dart';
import 'stw_regions.dart';

StwMap? _cache;

/// The STW Map, built from the workflows, the PDF boxes and
/// `assets/knowledge_graph/stw_map.json`.
Future<StwMap> loadStwMap() async {
  final cached = _cache;
  if (cached != null) return cached;
  final regions = await loadStwRegions();
  final json = jsonDecode(
    await rootBundle.loadString('assets/knowledge_graph/stw_map.json'),
  ) as Map<String, dynamic>;
  return _cache = buildStwMap(
    regions: regions,
    data: StwMapData.fromJson(json),
  );
}

final stwMapProvider = FutureProvider<StwMap>((ref) => loadStwMap());
