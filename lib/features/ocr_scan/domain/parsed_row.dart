class ParsedRow {
  String name;
  double qty;
  String unit;           // pcs | kg | g | lb | oz | l | ml | pack
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

  /// Normalize fields for UI/storage
  void normalize() {
    name = _smartTitleCase(name.trim());
    unit = _canonicalUnit(unit);
  }

  /// Map common synonyms to a single dropdown-safe unit value
  String _canonicalUnit(String? u) {
    if (u == null || u.trim().isEmpty) return 'pcs';
    final s = u.trim().toLowerCase();

    // pieces
    if (s == 'ea' || s == 'each' || s == 'ct' || s == 'count' || s == 'unit' || s == 'units') {
      return 'pcs';
    }
    // weight/vol synonyms
    if (s == 'kgs' || s == 'kg.' || s == 'kilogram' || s == 'kilograms') return 'kg';
    if (s == 'gram' || s == 'grams') return 'g';
    if (s == 'lbs' || s == 'lb.' || s == 'pound' || s == 'pounds') return 'lb';
    if (s == 'oz.' || s == 'ounce' || s == 'ounces') return 'oz';
    if (s == 'ltr' || s == 'litre' || s == 'liter' || s == 'litres' || s == 'liters' || s == 'l.') return 'l';
    if (s == 'mls' || s == 'ml.' || s == 'millilitre' || s == 'milliliter') return 'ml';

    // packaging
    if (s == 'pk' || s == 'pkg' || s == 'packet' || s == 'pkt') return 'pack';
    if (s == 'dz' || s == 'doz') return 'dozen';
    if (s == 'bags') return 'bag';

    return s; // already canonical or acceptable
  }

  /// "ZUCHINNI GREEN" -> "Zuchinni Green", "PEAS-SNOW" -> "Peas-Snow",
  /// "tomatoes/grape" -> "Tomatoes/Grape", "o'brien" -> "O'Brien"
  String _smartTitleCase(String input) {
    if (input.isEmpty) return input;

    String cap(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

    String capCompound(String token) {
      // handle apostrophes
      final apost = token.split(RegExp(r"[’']")).map(cap).join("'");
      // handle hyphens
      final hy = apost.split('-').map(cap).join('-');
      // handle slashes
      final sl = hy.split('/').map(cap).join('/');
      return sl;
    }

    return input
        .split(RegExp(r'\s+'))
        .map(capCompound)
        .join(' ')
        .trim();
  }
}
