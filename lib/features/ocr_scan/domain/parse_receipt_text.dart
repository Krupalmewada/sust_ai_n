import 'parsed_row.dart';

List<ParsedRow> parseReceiptText(String rawText) {
  // ---------- 1) Split into lines ----------
  final allLines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // ---------- 2) Heuristics to detect items region ----------
  final priceToken   = RegExp(r'\$\s*\d+(?:\s*\.\s*\d{2})?\s*(?:c|hc)?\s*$', caseSensitive: false);
  final weightedToken= RegExp(r'\b(?:kg|g|lb|lbs|oz|l|ml)\b.*@\s*\$\s*\d', caseSensitive: false);
  final multiToken   = RegExp(r'\d+\s*@\s*1\s*/\s*\$\s*\d|\d+\s*x\s*\$\s*\d', caseSensitive: false);

  bool looksLikeItem(int i) {
    final l = allLines[i];
    final next = (i + 1 < allLines.length) ? allLines[i + 1] : '';
    return priceToken.hasMatch(l) ||
        weightedToken.hasMatch(l) ||
        multiToken.hasMatch(l) ||
        priceToken.hasMatch(next) || weightedToken.hasMatch(next) || multiToken.hasMatch(next);
  }

  int start = 0;
  for (int i = 0; i < allLines.length; i++) {
    if (looksLikeItem(i)) { start = i; break; }
  }

  final footerGuard = RegExp(
    r'^(subtotal|total|total tax|tax|tender|change|cash|debit|credit|visa|mastercard|number of items)\b',
    caseSensitive: false,
  );
  int end = allLines.length;
  for (int j = start + 1; j < allLines.length; j++) {
    if (footerGuard.hasMatch(allLines[j])) { end = j; break; }
  }

  final region = allLines.sublist(start, end);

  // ---------- 3) Noise filters ----------
  final noise = <RegExp>[
    RegExp(r'^you saved', caseSensitive: false),
    RegExp(r'^instant savings', caseSensitive: false),
    RegExp(r'^(points|pts?)\b', caseSensitive: false),
    RegExp(r'^number of items', caseSensitive: false),
    RegExp(r'^\$?\s*\d+(?:\s*\.\s*\d{2})?\s*(?:c|hc)?\s*$', caseSensitive: false), // price-only
  ];

  final filtered = <String>[];
  for (final l in region) {
    if (noise.any((rx) => rx.hasMatch(l))) continue;
    filtered.add(l);
  }

  // ---------- 4) Merge detail lines with names ----------
  bool isDetail(String s) =>
      s.contains(RegExp(r'\bkg\b|\blb\b|\boz\b|\bl\b|\bml\b', caseSensitive: false)) ||
          s.contains('@') ||
          RegExp(r'^\d+\s*@').hasMatch(s) ||
          RegExp(r'\d+\s*x\s*\$').hasMatch(s) ||
          RegExp(r'\$\s*\d+(?:\s*\.\s*\d{2})?(?:\s*(?:c|hc))?\s*$').hasMatch(s); // <— tolerant price

  final merged = <String>[];
  for (int i = 0; i < filtered.length; i++) {
    final cur = filtered[i];
    if (i > 0 && isDetail(cur)) {
      merged[merged.length - 1] = '${merged.last}\n$cur';
    } else {
      merged.add(cur);
    }
  }

  // ---------- 5) Patterns ----------
  final weightedRx = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|g|lb|lbs|oz|l|ml)\s*@\s*\$(\d+(?:\.\d{2}))\s*/\s*(kg|g|lb|lbs|oz|l|ml)',
      caseSensitive: false);

  final multiRx = RegExp(
      r'(\d+)\s*@\s*1\s*/\s*\$(\d+(?:\.\d{2}))|(\d+)\s*x\s*\$(\d+(?:\.\d{2}))',
      caseSensitive: false);

  final trailingPriceRx =
  RegExp(r'\$\s*(\d+(?:\s*\.\s*\d{2}))\s*(?:c|hc)?\s*$', caseSensitive: false);

  // ---------- helpers ----------
  double? n(String? x) {                     // <— keep ONE n()
    if (x == null) return null;
    final cleaned = x.replaceAll(' ', '');
    return double.tryParse(cleaned);
  }

  String normalizeName(String s) {
    s = s.toLowerCase();

    // quick OCR char fixes
    const subs = {'0': 'o','1': 'l','5': 's','8': 'b'};
    subs.forEach((k, v) => s = s.replaceAll(k, v));

    s = s.replaceAll(RegExp(r'[·••º°]'), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // join split words using a tiny dictionary
    final dict = <String>{
      'onions','strawberries','broccoli','asparagus','clubhouse','bagel','bananas',
      'parmesan','ginger','lettuce','pepper','kiwi','garlic','chips','dressed','rye',
    };
    final tokens = s.split(' ');
    for (int i = 0; i < tokens.length - 1; i++) {
      final joined = (tokens[i] + tokens[i + 1]);
      if (dict.contains(joined)) {
        tokens[i] = joined;
        tokens.removeAt(i + 1);
        i--;
      }
    }
    s = tokens.join(' ');

    // simple plural → singular
    s = s.replaceAll(RegExp(r'\bpeppers\b'), 'pepper');
    s = s.replaceAll(RegExp(r'\btomatoes\b'), 'tomato');
    s = s.replaceAll(RegExp(r'\bbagels\b'), 'bagel');

    // strip long SKUs & extra spaces
    s = s.replaceAll(RegExp(r'\b\d{5,}\b'), '').trim();
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return s;
  }

  String normUnit(String u) => u.toLowerCase() == 'lbs' ? 'lb' : u.toLowerCase();

  // ---------- 6) Build rows ----------
  final out = <ParsedRow>[];

  for (final block in merged) {
    final parts = block.split('\n');
    final nameLine = parts.first.trim();
    if (trailingPriceRx.hasMatch(nameLine) && nameLine.split(' ').length == 1) continue;

    final row = ParsedRow(name: normalizeName(nameLine), raw: block);
    bool matched = false;

    final w = weightedRx.firstMatch(block);
    if (w != null) {
      final qty = n(w.group(1));
      final unit = normUnit(w.group(2)!);
      final unitPrice = n(w.group(3));
      row.qty = qty ?? 1;
      row.unit = unit;
      row.unitPrice = unitPrice;
      row.lineTotal = (qty != null && unitPrice != null)
          ? double.parse((qty * unitPrice).toStringAsFixed(2))
          : null;
      matched = true;
    }

    if (!matched) {
      final m = multiRx.firstMatch(block);
      if (m != null) {
        final qty = n(m.group(1) ?? m.group(3));
        final priceEach = n(m.group(2) ?? m.group(4));
        row.qty = (qty ?? 1).toDouble();
        row.unit = 'pcs';
        row.unitPrice = priceEach;
        row.lineTotal = (qty != null && priceEach != null)
            ? double.parse((qty * priceEach).toStringAsFixed(2))
            : priceEach;
        matched = true;
      }
    }

    if (!matched) {
      final t = trailingPriceRx.firstMatch(block);
      if (t != null) {
        final price = n(t.group(1));
        row.qty = 1;
        row.unit = 'pcs';
        row.unitPrice = price;
        row.lineTotal = price;
        matched = true;
      }
    }

    if (row.name.length < 3 || RegExp(r'[^a-z0-9\s/+-]').hasMatch(row.name) || !matched) {
      row.needsReview = true;
    }

    out.add(row);
  }

  return out.where((r) => !RegExp(r'^(subtotal|total|tax|tender|change)$').hasMatch(r.name)).toList();
}
