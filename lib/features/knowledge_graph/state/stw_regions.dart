import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stw_region.dart';

export '../domain/stw_region.dart';

Map<String, StwRegionInfo>? _cache;

/// The STW PDF boxes by id; empty when the asset cannot be read.
Future<Map<String, StwRegionInfo>> loadStwRegions() async {
  final cached = _cache;
  if (cached != null) return cached;
  try {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/regions/regions.json'),
    ) as List;
    return _cache = {
      for (final r in raw.cast<Map<String, dynamic>>())
        r['id'] as String: StwRegionInfo(
          id: r['id'] as String,
          document: r['document'] as String? ?? '',
          page: r['page'] as int? ?? 1,
          text: readableStwText(r['text'] as String? ?? ''),
        ),
    };
  } catch (_) {
    return const {};
  }
}

final stwRegionsProvider =
    FutureProvider<Map<String, StwRegionInfo>>((ref) => loadStwRegions());
