class ParsedRow {
  String name;
  double qty;
  String unit;           // pcs | kg | g | lb | oz | L | ml | pack
  double? unitPrice;
  double? lineTotal;
  bool needsReview;
  String raw;

  ParsedRow({
    required this.name,
    this.qty = 1,
    this.unit = 'pcs',
    this.unitPrice,
    this.lineTotal,
    this.needsReview = false,
    this.raw = '',
  });

  /// Normalize qty and unit into safe, canonical values.
  /// Call this after parsing or before persisting.
  void normalize() {
    if (qty.isNaN || qty <= 0) qty = 1;
    unit = _normalizeUnit(unit);
  }

  /// Convenience: create a modified copy while keeping other fields unchanged.
  ParsedRow copyWith({
    String? name,
    double? qty,
    String? unit,
    double? unitPrice,
    double? lineTotal,
    bool? needsReview,
    String? raw,
  }) {
    return ParsedRow(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      needsReview: needsReview ?? this.needsReview,
      raw: raw ?? this.raw,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'unit': unit,
    'unitPrice': unitPrice,
    'lineTotal': lineTotal,
    'needsReview': needsReview,
    'raw': raw,
  };

  static ParsedRow fromJson(Map<String, dynamic> m) => ParsedRow(
    name: (m['name'] ?? '').toString(),
    qty: (m['qty'] as num?)?.toDouble() ?? 1,
    unit: (m['unit'] ?? 'pcs').toString(),
    unitPrice: (m['unitPrice'] as num?)?.toDouble(),
    lineTotal: (m['lineTotal'] as num?)?.toDouble(),
    needsReview: m['needsReview'] == true,
    raw: (m['raw'] ?? '').toString(),
  );

  // --- internal ---

  static String _normalizeUnit(String u) {
    final s = u.trim().toLowerCase();
    switch (s) {
      case 'l':
      case 'ltr':
      case 'litre':
      case 'liter':
        return 'L';
      case 'g':
      case 'gram':
      case 'grams':
        return 'g';
      case 'kg':
      case 'kilogram':
      case 'kilograms':
        return 'kg';
      case 'ml':
      case 'millilitre':
      case 'milliliter':
        return 'ml';
      case 'lb':
      case 'lbs':
        return 'lb';
      case 'oz':
        return 'oz';
      case 'pack':
      case 'pk':
        return 'pack';
      case 'pc':
      case 'pcs':
      default:
        return 'pcs';
    }
  }
}
