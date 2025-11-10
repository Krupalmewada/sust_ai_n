// lib/features/ocr_scan/domain/parse_receipt_text.dart
//
// Store-agnostic receipt parser.
//
// Pipeline
// 1) Normalize OCR lines.
// 2) Find the dynamic "items block" using price/qty density (no store rules).
// 3) Collapse continuation fragments onto the previous item line (e.g. "@ $/kg",
//    "/kg", or a bare "0.165 kg") and attach price-only lines to the prior item.
// 4) Extract {name, qty, unit, unitPrice, lineTotal}, merge duplicates,
//    and compute subtotal/tax/total + food/non-food spend.
//
// Output rows match your ParsedRow model.

import 'dart:math';
import 'parsed_row.dart';
import 'spell_correct.dart'; // NEW: lightweight correction utils


// ------------------------------- Models --------------------------------------

class ReceiptMoney {
  final double? subtotal;
  final double? tax;
  final double? total;
  const ReceiptMoney({this.subtotal, this.tax, this.total});
}

class ReceiptParseResult {
  final List<ParsedRow> items;     // Items with lineTotal/unitPrice when found
  final double foodSpend;          // Sum of lineTotal for food
  final double nonFoodSpend;       // Sum of lineTotal for non-food
  final ReceiptMoney money;        // Parsed subtotal/tax/total if present
  final List<String> nonFoodLines; // Raw lines flagged as non-food

  const ReceiptParseResult({
    required this.items,
    required this.foodSpend,
    required this.nonFoodSpend,
    required this.money,
    required this.nonFoodLines,
  });
}

// ------------------------------- Regexes -------------------------------------

/// Trailing price like: "... 2.99", "... $2.99", "... 1,234.56", "... 2.99 C"
final RegExp _priceTailRe = RegExp(
  r'(?:[$£€]\s*)?\d{1,3}(?:[.,]\d{3})*[.,]\d{2}\s*[A-Z]?$',
);

/// Any price occurrence (for density scoring as well)
final RegExp _priceAnyRe = RegExp(
  r'(?<!\w)(?:[$£€]\s*)?\d{1,3}(?:[.,]\d{3})*[.,]\d{2}\s*[A-Z]?(?!\w)',
);

/// A line that is basically just a price (no words)
final RegExp _priceOnlyLineRe = RegExp(
  r'^\s*[£$€]?\s*\d{1,3}(?:[.,]\d{3})*[.,]\d{2}\s*[A-Z]?\s*$',
);

bool _isPriceOnlyLine(String s) => _priceOnlyLineRe.hasMatch(s);

/// A "qty then unit" line that has extras like NET or @ $/kg
final RegExp _qtyUnitWithExtrasRe = RegExp(
  r'^\s*\d+(?:[.,]\d+)?\s*(kg|g|lb|lbs|oz|l|ml)\b.*$',
  caseSensitive: false,
);

/// Rightmost (tail) price capture, tolerating a trailing currency letter
final RegExp _priceTailCaptureRe = RegExp(
  r'([£$€]?\s*\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s*[A-Z]?$',
);

double? _extractPriceTail(String s) {
  final m = _priceTailCaptureRe.firstMatch(s);
  if (m == null) return null;
  final raw = m.group(1)!.replaceAll(RegExp(r'[£$€\s]'), '');
  return double.tryParse(raw.replaceAll(',', '.'));
}

/// Inline qty+unit: "1.5 kg", "2 pcs", "3 pk", "12 ct", "3lb", "5 EA", "each"
final RegExp _unitInlineRe = RegExp(
  r'(?<![A-Za-z0-9])(\d+(?:[.,]\d+)?)[ ]*(kg|g|lb|lbs|oz|l|ml|pcs?|pack|pk|ea|each|dozen|dz|bag|ct|count)\b',
  caseSensitive: false,
);

/// Multipliers: "2 x", "x 2", "2 pcs", "3 pk", "4 @"
final RegExp _xQtyRe = RegExp(
  r'\b(\d+)\s*(?:x|@|pcs?|pack|pk|ct|count)\b',
  caseSensitive: false,
);

/// Bare qty+unit line (continuation): "0.165 kg", "2 lb"
final RegExp _bareQtyUnitLineRe = RegExp(
  r'^\s*(\d+(?:[.,]\d+)?)[ ]*(kg|g|lb|lbs|oz|l|ml)\s*(?:@.*)?$',
  caseSensitive: false,
);

/// Continuation tokens
final RegExp _atStartRe = RegExp(r'^\s*@'); // "@ $/lb"
final RegExp _perWeightRe = RegExp(r'/\s*(?:kg|lb|lbs)\b', caseSensitive: false);

/// Footer / totals boundary
final RegExp _totalLikeRe = RegExp(
  r'^\s*(sub[-\s]?total|total\s*tax|total|tender|change|balance|amount\s+due|grand\s+total|tax|gst|pst|hst|vat)\b',
  caseSensitive: false,
);

/// Obvious noise (headers, loyalty, payments, separators, addresses, etc.)
final List<RegExp> _noise = <RegExp>[
  RegExp(r'^\s*([*=\-–—_]{3,})\s*$'),
  RegExp(r'^\s*(you\s+saved|instant\s+savings|points\s+earned|points|loyalty|savings|coupon|discount)\b',
      caseSensitive: false),
  RegExp(r'^\s*(payment|debit|credit|visa|mastercard|amex|cash|tender|change)\b',
      caseSensitive: false),
  RegExp(r'^\s*(number\s+of\s+items)\b', caseSensitive: false),
  RegExp(r'^\s*(served\s+by|clerk|cashier|operator|member\s*card)\b',
      caseSensitive: false),
  RegExp(r'\(\d{3}\)\s*\d{3}[-\s]\d{4}'),                     // (905) 793-4867
  RegExp(r'\b\d{3}[-\s]\d{3}[-\s]\d{4}\b'),                   // 555-555-5555
  RegExp(r'\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b'),                    // Canadian postal
  RegExp(r'\b\d{5}(?:-\d{4})?\b'),                            // US ZIP
  RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'),               // dates
  RegExp(r'\border\s*#?\s*\w+\b', caseSensitive: false),
  RegExp(r'\b(invoice|receipt)\s*#?\s*\w+\b', caseSensitive: false),
  RegExp(r'\b(st|street|ave|avenue|rd|road|blvd|drive|dr|unit|suite|city|state)\b',
      caseSensitive: false),
  RegExp(r'^\s*special\s*$', caseSensitive: false),
  RegExp(r'^\s*date\s*$', caseSensitive: false),
  RegExp(r'^\s*(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\s*$',
      caseSensitive: false),
  RegExp(r'^\s*number\s+of\s+items\b', caseSensitive: false),
];

// --------------------------- Non-food heuristics -----------------------------

final List<RegExp> _nonFoodHints = <RegExp>[
  RegExp(r'\b(bag|bags|bag fee|reusable)\b', caseSensitive: false),
  RegExp(r'\b(deposit|bottle|crv|eco fee|levy)\b', caseSensitive: false),
  RegExp(r'\b(gift\s*card|prepaid|phone\s*card|top[-\s]?up)\b', caseSensitive: false),
  RegExp(r'\b(detergent|cleaner|bleach|soap|shampoo|conditioner|tissue|toilet|paper|foil|wrap|batter(y|ies)|lightbulb)\b',
      caseSensitive: false),
  RegExp(r'\b(household|home|lawn|garden|pet)\b', caseSensitive: false),
  RegExp(r'\b(pharmacy|rx|med|medicine|vitamin|supplement)\b', caseSensitive: false),
  RegExp(r'\b(utensil|knife|plate|cup|straw)\b', caseSensitive: false),
  RegExp(r'\b(lottery|lotto)\b', caseSensitive: false),
];

bool _looksNonFood(String name) {
  for (final r in _nonFoodHints) {
    if (r.hasMatch(name)) return true;
  }
  return false;
}

// ----------------------------- Small helpers ---------------------------------

String _tidy(String s) {
  var out = s.trim();
  out = out.replaceAll(RegExp(r'[–—]+'), '-');
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  return out;
}

bool _hasLetters(String s) => RegExp(r'[A-Za-z]').hasMatch(s);
bool _hasPriceAny(String s) => _priceAnyRe.hasMatch(s);
bool _hasPriceTail(String s) => _priceTailRe.hasMatch(s);
bool _hasInlineQty(String s) => _unitInlineRe.hasMatch(s) || _xQtyRe.hasMatch(s);
bool _isTotalLike(String s) => _totalLikeRe.hasMatch(s);

bool _isNoiseLine(String s) {
  if (s.isEmpty) return true;
  for (final r in _noise) {
    if (r.hasMatch(s)) return true;
  }
  return false;
}

// Keepers for candidate "itemish" lines during block finding.
bool _isCandidate(String s) {
  if (_isNoiseLine(s) || _isTotalLike(s)) return false;
  if (!_hasLetters(s)) return false;
  return _hasPriceTail(s) || _hasInlineQty(s) || _hasPriceAny(s);
}

// Extra noise guard
final RegExp _numberOfItemsRe =
RegExp(r'^\s*number\s+of\s+items\b', caseSensitive: false);

// N @ 1 / $X (multi-buy)
final RegExp _multiAtRe =
RegExp(r'\b(\d+)\s*@\s*\d+\s*/\s*([£$€]?\s*\d+(?:[.,]\d+)?)');

// Is this line a plausible item-name line on its own?
bool _isLikelyItemNameLine(String s) {
  if (s.isEmpty) return false;
  if (_isNoiseLine(s) || _isTotalLike(s)) return false;
  if (_numberOfItemsRe.hasMatch(s)) return false;
  if (_isPriceOnlyLine(s)) return false;
  // Avoid pure savings & points (already in _noise but extra safety)
  if (RegExp(r'^\s*(you\s+saved|instant\s+savings|points\s+earned)\b', caseSensitive: false).hasMatch(s)) {
    return false;
  }
  return _hasLetters(s);
}

// Parse "N @ 1 / $X" -> returns the total money for that line if present
double? _extractMultiAtTotal(String s) {
  final m = _multiAtRe.firstMatch(s);
  if (m == null) return null;
  final n = int.tryParse(m.group(1)!);
  final priceRaw = m.group(2)!.replaceAll(RegExp(r'[£$€\s]'), '').replaceAll(',', '.');
  final px = double.tryParse(priceRaw);
  if (n == null || px == null) return null;
  return n * px;
}

// Fallback: scan the whole receipt when the block finder misses.
// Pass in the already-normalized lines (e.g., the same allLines you use elsewhere).
List<ParsedRow> _fallbackItemsFromWholeReceipt(List<String> allLines) {
  // 1) Collapse continuation fragments across the whole receipt
  final collapsed = _collapseContinuations(allLines);

  // 2) Bind price-only lines to the previous non-price line
  final collapsedWithPrices = <String>[];
  for (final l in collapsed) {
    if (_isPriceOnlyLine(l) && collapsedWithPrices.isNotEmpty) {
      final idx = collapsedWithPrices.length - 1;
      collapsedWithPrices[idx] = '${collapsedWithPrices[idx]}  ${l.trim()}';
    } else {
      collapsedWithPrices.add(l);
    }
  }

  // 3) Build candidate rows
  final items = <ParsedRow>[];

  for (final s1 in collapsedWithPrices) {
    final s = _tidy(s1);
    if (_isNoiseLine(s) || _isTotalLike(s)) continue;
    if (!_isLikelyItemNameLine(s)) continue;

    // qty/unit extraction
    double? qty;
    String? unit;

    final m1 = _unitInlineRe.firstMatch(s);
    if (m1 != null) {
      qty = double.tryParse(m1.group(1)!.replaceAll(',', '.'));
      unit = m1.group(2);
    } else {
      final m2 = _xQtyRe.firstMatch(s);
      if (m2 != null) {
        qty = double.tryParse(m2.group(1)!);
        unit = 'pcs';
      } else {
        final bare = _bareQtyUnitLineRe.firstMatch(s);
        if (bare != null) {
          qty = double.tryParse(bare.group(1)!.replaceAll(',', '.'));
          unit = bare.group(2);
        }
      }
    }

    final name0 = _cleanName(s);
    if (name0.isEmpty) continue;

    // require at least some price/qty evidence in fallback too
    final looksItem = _hasLetters(name0) &&
        (_hasInlineQty(s) || _hasPriceAny(s) || _hasPriceTail(s));
    if (!looksItem) continue;

    final lt = _extractPriceTail(s) ?? _extractMultiAtTotal(s);

    // normalize qty/unit and compute unitPrice if possible
    final q = (qty == null || qty.isNaN || qty <= 0) ? 1.0 : qty;
    final u = (unit == null || unit.isEmpty) ? 'pcs' : unit.toLowerCase();
    double? unitPriceVal;
    if (lt != null && q > 0) unitPriceVal = lt / q;

    final row = ParsedRow(
      name: name0,
      qty: q,
      unit: u,
      lineTotal: lt,
      unitPrice: unitPriceVal,
      needsReview: false, // no external flag in this scope
      raw: s1,            // <<— use the current collapsed line string
    );
    row.normalize();
    items.add(row);
  }

  // 4) Merge duplicates (name|unit)
  final byKey = <String, ParsedRow>{};
  for (final r in items) {
    final key = '${r.name.toLowerCase()}|${r.unit.toLowerCase()}';
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = r;
    } else {
      // merge qty; keep first price info if already present
      byKey[key] = ParsedRow(
        name: existing.name,
        qty: existing.qty + r.qty,
        unit: existing.unit,
        unitPrice: existing.unitPrice ?? r.unitPrice,
        lineTotal: existing.lineTotal ?? r.lineTotal,
        needsReview: existing.needsReview || r.needsReview,
        raw: existing.raw, // keep earliest raw
      )..normalize();
    }
  }

  return byKey.values.toList();
}



// -------------------------- Items block detection ----------------------------

({int start, int end}) _findItemsBlock(List<String> lines) {
  final n = lines.length;
  if (n == 0) return (start: 0, end: -1);

  final evid = List<int>.generate(n, (i) => _isCandidate(lines[i]) ? 1 : 0);

  const W = 8;
  int bestStart = 0, bestEnd = max(0, n - 1);
  double bestDensity = -1;

  int sum = 0;
  for (int i = 0; i < min(W, n); i++) {
    sum += evid[i];
  }

  for (int i = 0; i < n; i++) {
    final win = min(W, n - i);
    final density = win == 0 ? 0.0 : sum / win;
    if (density > bestDensity) {
      bestDensity = density;
      bestStart = i;
      bestEnd = i + win - 1;
    }
    if (i + W < n) sum += evid[i + W];
    if (i < n) sum -= evid[i];
  }

  // Expand forward until totals/footer. Allow short noise runs so we can
  // reach continuation lines like "0.322kg NET @ $15.99/kg".
  int end = bestEnd;
  int noiseRun = 0;
  for (int i = bestEnd + 1; i < n; i++) {
    final s = lines[i];
    if (_isTotalLike(s)) break;

    if (_isCandidate(s) || _looksContinuationLine(s) ||
        (!_isNoiseLine(s) && _hasLetters(s))) {
      end = i;
      noiseRun = 0;
      continue;
    }

    if (_isNoiseLine(s)) {
      noiseRun++;
      if (noiseRun <= 3) continue; // skip up to 3 consecutive noise lines
    }
    break; // clear non-noise/non-candidate => stop
  }

  // Back up start to avoid headers.
  int start = bestStart;
  for (int i = bestStart - 1; i >= 0; i--) {
    final s = lines[i];
    if (_isTotalLike(s) || _isNoiseLine(s)) {
      start = i + 1;
      break;
    }
  }

  // Fallback: first candidate .. before totals
  if (bestDensity <= 0) {
    start = 0;
    while (start < n && !_isCandidate(lines[start])) {start++;
    if (start >= n) return (start: 0, end: -1);
    end = n - 1;
    for (int i = start; i < n; i++) {
      if (_isTotalLike(lines[i])) {
        end = i - 1;
        break;
      }
    }
    }
  }

  if (start > end) return (start: 0, end: -1);
  return (start: start, end: end);
}

bool _looksContinuationLine(String s) {
  return _qtyUnitWithExtrasRe.hasMatch(s) ||
      _bareQtyUnitLineRe.hasMatch(s) ||
      _atStartRe.hasMatch(s) ||
      _perWeightRe.hasMatch(s);
}

// ----------------------- Collapse continuation lines -------------------------

List<String> _collapseContinuations(List<String> slice) {
  final out = <String>[];
  for (int i = 0; i < slice.length; i++) {
    final s = slice[i];

    final isContinuation =
        _atStartRe.hasMatch(s) ||
            _perWeightRe.hasMatch(s) ||
            _bareQtyUnitLineRe.hasMatch(s) ||
            _qtyUnitWithExtrasRe.hasMatch(s);

    if (isContinuation && out.isNotEmpty) {
      // Attach to last non-noise anchor (skip a few noise lines)
      int anchor = out.length - 1;
      int steps = 0;
      while (anchor >= 0 &&
          steps < 3 &&
          (_isNoiseLine(out[anchor]) || _isTotalLike(out[anchor]))) {
        anchor--;
        steps++;
      }
      if (anchor >= 0) {
        out[anchor] = '${out[anchor]}  ${s.trim()}';
        continue;
      }
    }

    out.add(s);
  }
  return out;
}

// ------------------------------ Price tail help ------------------------------

List<double> _selectItemPricesFromTail(List<double> tail, int need) {
  final out = <double>[];
  final counts = <double, int>{};
  for (final v in tail) {
    counts[v] = (counts[v] ?? 0) + 1;
  }

  for (final v in tail) {
    if (out.length >= need) break;
    if (v <= 0) continue;
    if (v >= 20) continue;                  // avoid obvious big totals
    if ((counts[v] ?? 0) >= 3) continue;    // repeated totals
    out.add(v);
  }
  return out;
}

// Collect trailing block of price-only lines at the end, in forward order.
List<double> _collectTrailingPrices(List<String> lines) {
  int i = lines.length - 1;
  while (i >= 0 && _isPriceOnlyLine(lines[i])) {
    i--;
  }
  final prices = <double>[];
  for (int k = i + 1; k < lines.length; k++) {
    final v = _extractPriceTail(lines[k]);
    if (v == null || v <= 0) continue; // skip negatives like -15.00 (LOYALTY)

    // If a totals-like label appears in the two lines above this price,
    // treat it as a receipt total, not an item line price.
    bool totalsNeighbor = false;
    for (int look = 1; look <= 2; look++) {
      final idx = k - look;
      if (idx >= 0) {
        final prev = _tidy(lines[idx]);
        if (_isTotalLike(prev)) {
          totalsNeighbor = true;
          break;
        }
      }
    }
    if (totalsNeighbor) continue;

    prices.add(v);
  }
  return prices;
}

// ------------------------------ Cleaning -------------------------------------

String _stripPricesEtc(String s) {
  var out = s;

  // Remove any price tokens (allow trailing currency marker)
  out = out.replaceAll(RegExp(r'[$£€]\s*\d+(?:[.,]\d+)?\s*[A-Z]?'), '');
  out = out.replaceAll(RegExp(r'\b\d{1,3}(?:[.,]\d{3})*[.,]\d{2}\s*[A-Z]?\b'), '');
  out = out.replaceAll(RegExp(r'\b\d+[.,]\d{2}\s*[A-Z]?\b'), '');

  // Remove "@ ...", "/kg", trailing codes like "HC", "C", "PTS", "NET", and "YOU SAVED ..."
  out = out.replaceAll(RegExp(r'\s*@\s*\S+'), '');
  out = out.replaceAll(RegExp(r'\s*/\s*(kg|lb|lbs)\b', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'\b(NET|HC|C|F|PTS)\b', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'\byou\s+saved\b.*$', caseSensitive: false), '');

  // Defensive: phones/dates/order-like
  out = out.replaceAll(RegExp(r'\(\d{3}\)\s*\d{3}[-\s]\d{4}'), '');
  out = out.replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'), '');
  out = out.replaceAll(RegExp(r'\border\s*#?\s*\w+\b', caseSensitive: false), '');

  return _tidy(out);
}

String _cleanName(String s) {
  var out = s;

  // Strip inline qty/unit and simple multipliers
  out = out.replaceAll(_unitInlineRe, '');
  out = out.replaceAll(_xQtyRe, '');

  // Remove prices/tokens
  out = _stripPricesEtc(out);

  // Prevent address/heading leakage
  if (RegExp(r'\b(st|street|ave|rd|road|drive|dr|blvd|unit|suite|city|state)\b',
      caseSensitive: false).hasMatch(out)) {
    return '';
  }

  out = _tidy(out);
  if (out.length <= 2 || !_hasLetters(out)) return '';
  return out;
}

ParsedRow _row(String name, {double? qty, String? unit}) {
  final q = (qty == null || qty.isNaN || qty <= 0) ? 1.0 : qty;
  final u = (unit == null || unit.isEmpty) ? 'pcs' : unit.toLowerCase();

  final r = ParsedRow(name: name, qty: q, unit: u);
  r.normalize(); // Title-case name + normalize unit
  return r;
}

// --------------------------- Totals extraction --------------------------------

ReceiptMoney _extractTotals(List<String> lines, {int skipTailPrices = 0}) {
  double? subtotal, tax, total;

  final priceRe =
  RegExp(r'(?:[$£€]\s*)?(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s*[A-Z]?');
  bool isCashLike(String s) =>
      RegExp(r'^\s*(cash|tender|change|mastercard|visa|amex|debit|credit)\b',
          caseSensitive: false)
          .hasMatch(s);
  bool isSubtotalLikeLbl(String s) =>
      RegExp(r'^\s*sub[-\s]?total\b', caseSensitive: false).hasMatch(s);
  bool isTaxLikeLbl(String s) =>
      RegExp(r'^\s*(tax|gst|pst|hst|vat|total\s*tax)\b',
          caseSensitive: false)
          .hasMatch(s);
  bool isTotalLikeLbl(String s) =>
      RegExp(r'^\s*total\b', caseSensitive: false).hasMatch(s);

  double? toNumSafe(String v) =>
      double.tryParse(v.replaceAll(RegExp(r'[£$€\s]'), '').replaceAll(',', '.'));

  // Pass 1: labeled totals (ignore CASH/TENDER/CHANGE lines)
  for (int i = 0; i < lines.length; i++) {
    final s = _tidy(lines[i]);
    if (isCashLike(s)) continue;

    if (isSubtotalLikeLbl(s)) {
      final m = priceRe.firstMatch(s);
      if (m != null) subtotal = toNumSafe(m.group(1)!);
      continue;
    }
    if (isTaxLikeLbl(s)) {
      final m = priceRe.firstMatch(s);
      if (m != null) tax = toNumSafe(m.group(1)!);
      continue;
    }
    if (isTotalLikeLbl(s)) {
      final m = priceRe.firstMatch(s);
      if (m != null) total = toNumSafe(m.group(1)!);
      continue;
    }
  }

  // Pass 2: heuristics if still missing
  if (total == null || subtotal == null) {
    final candidates = <double>[];
    for (int i = 0; i < lines.length; i++) {
      final s = _tidy(lines[i]);
      if (isCashLike(s)) continue;
      final m = priceRe.firstMatch(s);
      if (m != null) {
        final v = toNumSafe(m.group(1)!);
        if (v != null && v > 0) candidates.add(v);
      }
    }
    candidates.sort();
    if (total == null && candidates.isNotEmpty) {
      total = candidates.last;
    }
    if (subtotal == null && candidates.length >= 2) {
      subtotal = candidates[candidates.length - 2];
    }
  }

  return ReceiptMoney(subtotal: subtotal, tax: tax, total: total);
}

// ------------------------------- Public APIs ---------------------------------

/// Enriched receipt parser: items + money + food/non-food split.
ReceiptParseResult parseReceiptEnriched(String raw) {
  if (raw.trim().isEmpty) {
    return const ReceiptParseResult(
      items: [],
      foodSpend: 0,
      nonFoodSpend: 0,
      money: ReceiptMoney(),
      nonFoodLines: [],
    );
  }

  // Normalize and keep all lines for totals/tail scanning
  final allLines = raw
      .split(RegExp(r'\r?\n'))
      .map(_tidy)
      .where((s) => s.isNotEmpty)
      .toList();

  // Dense items strategy
  final block = _findItemsBlock(allLines);
  if (block.end < block.start) {
    return ReceiptParseResult(
      items: const [],
      foodSpend: 0,
      nonFoodSpend: 0,
      money: _extractTotals(allLines),
      nonFoodLines: const [],
    );
  }

  final slice = allLines.sublist(block.start, block.end + 1);
  final collapsed = _collapseContinuations(slice);

  // Attach price-only lines to prior non-price line
  final collapsedWithPrices = <String>[];
  for (int i = 0; i < collapsed.length; i++) {
    final s = collapsed[i];
    if (_isPriceOnlyLine(s) && collapsedWithPrices.isNotEmpty) {
      final lastIdx = collapsedWithPrices.length - 1;
      collapsedWithPrices[lastIdx] =
      '${collapsedWithPrices[lastIdx]}  ${s.trim()}';
    } else {
      collapsedWithPrices.add(s);
    }
  }

  // Build item rows
  final items = <ParsedRow>[];

  for (final s in collapsedWithPrices) {
    if (_isNoiseLine(s) || _isTotalLike(s)) continue;
    if (!_isLikelyItemNameLine(s)) continue;

    double? qty;
    String? unit;

    final m1 = _unitInlineRe.firstMatch(s);
    if (m1 != null) {
      qty = double.tryParse(m1.group(1)!.replaceAll(',', '.'));
      unit = m1.group(2);
    } else {
      final m2 = _xQtyRe.firstMatch(s);
      if (m2 != null) {
        qty = double.tryParse(m2.group(1)!);
        unit = 'pcs';
      } else {
        final bare = _bareQtyUnitLineRe.firstMatch(s);
        if (bare != null) {
          qty = double.tryParse(bare.group(1)!.replaceAll(',', '.'));
          unit = bare.group(2);
        }
      }
    }

    final name = _cleanName(s);
    if (name.isEmpty) continue;

    final looksItem = _hasLetters(name) &&
        (_hasInlineQty(s) || _hasPriceAny(s) || _hasPriceTail(s));
    final acceptLoose = !looksItem && _hasLetters(name); // allow bare item lines

    if (!looksItem && !acceptLoose) continue;

    // use multi-buy fallback too
    final lineTotal = _extractPriceTail(s) ?? _extractMultiAtTotal(s);

    double? unitPrice;
    if (lineTotal != null && qty != null && qty > 0) {
      unitPrice = lineTotal / qty;
    }

    final row = ParsedRow(
      name: name,
      qty: qty ?? 1,
      unit: unit ?? 'pcs',
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      needsReview: !looksItem,
      raw: s,
    );
    row.normalize();
    items.add(row);
  }

  // Fallback: if many prices are printed later as a tail block,
  // pair first N prices to first N items lacking a lineTotal.
  int consumedTailForItems = 0;
  final itemsNeedingPrice = items.where((r) => r.lineTotal == null).length;
  if (items.isNotEmpty && itemsNeedingPrice > 0) {
    final tail = _collectTrailingPrices(allLines);
    final candidates = _selectItemPricesFromTail(tail, items.length);
    if (candidates.length >= itemsNeedingPrice) {
      int p = 0;
      for (final row in items) {
        if (row.lineTotal == null) {
          row.lineTotal = candidates[p++];
          if (row.qty > 0) row.unitPrice = row.lineTotal! / row.qty;
          consumedTailForItems++;
        }
      }
    }
  }

  // If the main block pass found very little, try a tolerant full-receipt scan
  if (items.isEmpty || items.length < 3) {
    final fallback = _fallbackItemsFromWholeReceipt(allLines);
    if (fallback.isNotEmpty) {
      items
        ..clear()
        ..addAll(fallback);
    }
  }

  // Compute food/non-food spend AFTER assigning any fallback prices
  double foodSum = 0;
  double nonFoodSum = 0;
  final nonFoodLines = <String>[];

  for (final row in items) {
    final isNonFood = _looksNonFood(row.name);
    if (row.lineTotal != null) {
      if (isNonFood) {
        nonFoodSum += row.lineTotal!;
      } else {
        foodSum += row.lineTotal!;
      }
    }
    if (isNonFood) nonFoodLines.add(row.raw);
  }

  final money = _extractTotals(allLines, skipTailPrices: consumedTailForItems);

  return ReceiptParseResult(
    items: items,
    foodSpend: foodSum,
    nonFoodSpend: nonFoodSum,
    money: money,
    nonFoodLines: nonFoodLines,
  );
}

/// Simple list of items (legacy API kept for compatibility).
List<ParsedRow> parseReceiptText(String raw) {
  if (raw.trim().isEmpty) return const [];

  final lines = raw
      .split(RegExp(r'\r?\n'))
      .map(_tidy)
      .where((s) => s.isNotEmpty)
      .toList();

  final block = _findItemsBlock(lines);
  if (block.end < block.start) return const [];

  final collapsed =
  _collapseContinuations(lines.sublist(block.start, block.end + 1));

  final rows = <ParsedRow>[];

  for (final s in collapsed) {
    if (_isNoiseLine(s) || _isTotalLike(s)) continue;
    if (!_isLikelyItemNameLine(s)) continue;

    double? qty;
    String? unit;

    final m1 = _unitInlineRe.firstMatch(s);
    if (m1 != null) {
      qty = double.tryParse(m1.group(1)!.replaceAll(',', '.'));
      unit = m1.group(2);
    } else {
      final m2 = _xQtyRe.firstMatch(s);
      if (m2 != null) {
        qty = double.tryParse(m2.group(1)!);
        unit = 'pcs';
      } else {
        final bare = _bareQtyUnitLineRe.firstMatch(s);
        if (bare != null) {
          qty = double.tryParse(bare.group(1)!.replaceAll(',', '.'));
          unit = bare.group(2);
        }
      }
    }

    final name = _cleanName(s);
    if (name.isEmpty) continue;

    final looksItem = _hasLetters(name) &&
        (_hasInlineQty(s) || _hasPriceAny(s) || _hasPriceTail(s));
    if (!looksItem) continue;

    rows.add(_row(name, qty: qty, unit: unit));
  }

  // Merge duplicates by (name|unit)
  final merged = <String, ParsedRow>{};
  for (final r in rows) {
    final key = '${r.name.toLowerCase()}|${r.unit.toLowerCase()}';
    final existing = merged.putIfAbsent(key, () => r);
    if (identical(existing, r)) continue; // just inserted

    existing.qty += max<double>(0.0, r.qty);
    // (No lineTotal/unitPrice in this path, so nothing else to merge.)
  }
  return merged.values.toList();
}

/// Notes (typed/handwritten lists). Cleans bullets/headers and applies
/// lightweight spelling correction for common grocery terms.
/// Normalization to Title-Case happens in ParsedRow.normalize().
List<ParsedRow> parseNoteText(String raw) {
  if (raw.trim().isEmpty) return const [];

  // Pre-clean: drop common headers and non-letter leaders
  final cleanedLines = raw
      .split(RegExp(r'\r?\n'))
      .map(_tidy)
      .where((e) => e.isNotEmpty)
      .where((e) => !RegExp(r'^\s*(shopping|grocery)\s+list$', caseSensitive: false).hasMatch(e))
  // remove bullets like "·", "•", ".", "-", "|", "+"
      .map((e) => e.replaceFirst(RegExp(r'^[\.\-\u2022\u25CF\u00B7\+\|]+'), ''))
      .toList();

  // Split on line breaks and inline separators
  final parts = cleanedLines
      .expand((line) => line.split(RegExp(r',|•|·|- ')))
      .map(_tidy)
      .where((e) => e.isNotEmpty);

  final out = <ParsedRow>[];
  for (var line in parts) {
    var s = line;

    // Remove any remaining leading bullets or stray symbols
    s = s.replaceFirst(RegExp(r'^[\.\-\u2022\u25CF\u00B7\+\|]+'), '').trim();

    double? qty;
    String? unit;

    final u1 = _unitInlineRe.firstMatch(s);
    final u2 = _xQtyRe.firstMatch(s);

    if (u1 != null) {
      qty = double.tryParse(u1.group(1)!.replaceAll(',', '.'));
      unit = u1.group(2);
    } else if (u2 != null) {
      qty = double.tryParse(u2.group(1)!);
      unit = 'pcs';
    } else {
      // Leading number => pcs
      final lead = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s+([A-Za-z].*)$').firstMatch(s);
      if (lead != null) {
        qty = double.tryParse(lead.group(1)!.replaceAll(',', '.'));
        unit = 'pcs';
        s = lead.group(2)!;
      }
    }

    // Strip prices/tokens and do base cleaning
    var name = _cleanName(s);

    // Extra cleanup: keep only letters, spaces, apostrophes, slashes & hyphens
    // Use double-quoted raw string so single quotes are safe inside
    name = name.replaceAll(RegExp(r"[^A-Za-z \-\/'’]"), '');

    // If name is too short, skip
    if (name.trim().length < 2) continue;

    // Spell-correct per word using lightweight vocab
    name = correctPhrase(name);

    if (name.isEmpty) continue;
    out.add(_row(name, qty: qty, unit: unit));
  }
  return out;
}


