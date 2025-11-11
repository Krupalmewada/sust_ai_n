// lib/waste_dashboard/data/impact_factors/impact_factors.dart
//
// Loads and indexes per-kg impact factors from the CSV asset:
//   lib/waste_dashboard/data/impact_factors/impact_factors.csv
//
// Exposes:
//  - ImpactFactorsStore.load()  -> loads + indexes all rows
//  - store.getExact('veg.tomato')
//  - store.findBest('Tomatoes') -> tries exact, then leaf token fallback
//
// CSV headers expected:
//   food_or_category,co2e_per_kg,water_L_per_kg,energy_kWh_per_kg,price_per_kg,source_meta,version
//
// Notes:
// - Empty numeric cells become null.
// - Keys are normalized to lowercase underscored (spaces -> "_").
// - “Leaf” means the last segment after a dot: e.g., leaf('veg.tomato') == 'tomato'.
// - If multiple rows share the same leaf, the first one wins (simple heuristic).

import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

// Simple data model for a single factor row.
class ImpactFactor {
  final String foodOrCategory;   // e.g., "veg.tomato"
  final double? co2ePerKg;       // kg CO2e per kg
  final double? waterLPerKg;     // liters per kg
  final double? energyKwhPerKg;  // kWh per kg (optional; can stay null)
  final double? pricePerKg;      // currency per kg (CAD for now)
  final String? sourceMeta;      // e.g., "OWID 2023"
  final String? version;         // e.g., "v1.0"

  const ImpactFactor({
    required this.foodOrCategory,
    this.co2ePerKg,
    this.waterLPerKg,
    this.energyKwhPerKg,
    this.pricePerKg,
    this.sourceMeta,
    this.version,
  });
}

const String kImpactCsvAssetPath =
    'lib/waste_dashboard/data/impact_factors/impact_factors.csv';

class ImpactFactorsStore {
  ImpactFactorsStore._({
    required this.byKey,
    required this.byLeaf,
    required this.rows,
  });

  /// Full normalized key -> ImpactFactor (e.g., "veg.tomato")
  final Map<String, ImpactFactor> byKey;

  /// Leaf token -> ImpactFactor (e.g., "tomato"). First occurrence wins.
  final Map<String, ImpactFactor> byLeaf;

  /// All loaded rows in file order (for debugging or lists)
  final List<ImpactFactor> rows;

  // ---------- Public lookup APIs ----------

  /// Exact lookup by full key (e.g., "veg.tomato"). Returns null if missing.
  ImpactFactor? getExact(String key) {
    return byKey[_normKey(key)];
  }

  /// Best-effort lookup:
  /// 1) exact key match
  /// 2) if the name has a dot, try its leaf token
  /// 3) otherwise try the name as a leaf token
  ImpactFactor? findBest(String nameOrKey) {
    final exact = getExact(nameOrKey);
    if (exact != null) return exact;

    final leaf = _leafOf(nameOrKey);
    return byLeaf[_normKey(leaf)];
  }

  // ---------- Loading ----------

  /// Loads and parses the CSV asset, building a searchable index.
  static Future<ImpactFactorsStore> load({
    String assetPath = kImpactCsvAssetPath,
  }) async {
    final csvText = await rootBundle.loadString(assetPath);

    final lines = _splitNonEmptyLines(csvText);
    if (lines.isEmpty) {
      return ImpactFactorsStore._(byKey: {}, byLeaf: {}, rows: []);
    }

    // First line is header; we assume it matches what we documented.
    final header = _splitCsvLine(lines.first);
    final fieldIndex = _FieldIndex.fromHeader(header);

    final byKey = <String, ImpactFactor>{};
    final byLeaf = <String, ImpactFactor>{};
    final rows = <ImpactFactor>[];

    for (var i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      if (cols.isEmpty) continue;

      final item = _rowToImpactFactor(cols, fieldIndex);
      if (item == null) continue;

      rows.add(item);

      final key = _normKey(item.foodOrCategory);
      byKey.putIfAbsent(key, () => item);

      final leaf = _leafOf(item.foodOrCategory);
      final leafKey = _normKey(leaf);
      // If duplicate leafs exist, keep the first one as a simple heuristic.
      byLeaf.putIfAbsent(leafKey, () => item);
    }

    return ImpactFactorsStore._(byKey: byKey, byLeaf: byLeaf, rows: rows);
  }
}

// ===== CSV parsing helpers =====

class _FieldIndex {
  final int foodOrCategory;
  final int co2ePerKg;
  final int waterLPerKg;
  final int energyKwhPerKg;
  final int pricePerKg;
  final int sourceMeta;
  final int version;

  _FieldIndex({
    required this.foodOrCategory,
    required this.co2ePerKg,
    required this.waterLPerKg,
    required this.energyKwhPerKg,
    required this.pricePerKg,
    required this.sourceMeta,
    required this.version,
  });

  static _FieldIndex fromHeader(List<String> header) {
    String norm(String s) => s.trim().toLowerCase();

    int idx(String name) {
      final i = header.indexWhere((h) => norm(h) == norm(name));
      return i >= 0 ? i : -1;
    }

    return _FieldIndex(
      foodOrCategory: idx('food_or_category'),
      co2ePerKg: idx('co2e_per_kg'),
      waterLPerKg: idx('water_l_per_kg'),
      energyKwhPerKg: idx('energy_kwh_per_kg'),
      pricePerKg: idx('price_per_kg'),
      sourceMeta: idx('source_meta'),
      version: idx('version'),
    );
  }
}

ImpactFactor? _rowToImpactFactor(List<String> cols, _FieldIndex fi) {
  try {
    final name = _getString(cols, fi.foodOrCategory);
    if (name == null || name.isEmpty) return null;

    double? d(int i) => _parseDoubleSafe(_getString(cols, i));
    String? s(int i) => _getString(cols, i);

    return ImpactFactor(
      foodOrCategory: _normKey(name),
      co2ePerKg: d(fi.co2ePerKg),
      waterLPerKg: d(fi.waterLPerKg),
      energyKwhPerKg: d(fi.energyKwhPerKg),
      pricePerKg: d(fi.pricePerKg),
      sourceMeta: s(fi.sourceMeta),
      version: s(fi.version),
    );
  } catch (_) {
    return null;
  }
}

double? _parseDoubleSafe(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String? _getString(List<String> cols, int index) {
  if (index < 0 || index >= cols.length) return null;
  return cols[index].trim();
}

List<String> _splitNonEmptyLines(String text) {
  return text
      .split(RegExp(r'\r?\n'))
      .map((s) => s.trimRight())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Minimal CSV splitter for simple, unquoted CSV (what we use).
/// If you later add quoted fields with commas, replace with a CSV package.
List<String> _splitCsvLine(String line) {
  // Our seed file has no quoted commas, so a simple split works.
  return line.split(',');
}

// ===== Normalization helpers =====

String _normKey(String s) {
  return s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_'); // spaces -> underscore
}

String _leafOf(String nameOrKey) {
  final norm = _normKey(nameOrKey);
  final parts = norm.split('.');
  return parts.isEmpty ? norm : parts.last;
}
