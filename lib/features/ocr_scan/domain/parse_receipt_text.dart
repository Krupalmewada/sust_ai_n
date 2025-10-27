// Single parser for both receipts and free-form notes.
// It returns a list of ParsedRow that your EditItems sheet already consumes.

import 'dart:math';
import 'parsed_row.dart'; // <-- uses your existing model

/// If your ParsedRow has different field names or a copyWith, adjust below.
/// Assumed shape:
/// class ParsedRow { final String name; final double qty; final String unit; ... }

final _noise = <RegExp>[
  RegExp(r'^\s*(total|subtotal|tax|gst|pst|hst|vat|cash|change|tip)\b', caseSensitive: false),
  RegExp(r'^\s*(loyalty|savings|coupon|discount|payment|mastercard|visa|amex)\b', caseSensitive: false),
  RegExp(r'^\s*(sold items|net sales|returns|balance|grand total)\b', caseSensitive: false),
  RegExp(r'^\s*date\b', caseSensitive: false),
  RegExp(r'^\s*special\b', caseSensitive: false),
  RegExp(r'^\s*[*\-=_]{4,}\s*$'),
];

String _tidy(String s) {
  var out = s.trim();
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  out = out.replaceAll(RegExp(r'[–—]+'), '-');
  return out;
}

/// Remove money and pricing fragments to keep only product tokens.
String _stripPrices(String s) {
  var out = s;
  out = out.replaceAll(RegExp(r'(\$|£|€)\s*\d+[.,]?\d*'), '');        // $ 4.99
  out = out.replaceAll(RegExp(r'\b\d+[.,]\d{2}\b'), '');             // 12.34
  out = out.replaceAll(RegExp(r'\b\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})\b'), ''); // 1,234.56
  out = out.replaceAll(RegExp(r'\b@[^\n]+'), '');                    // @ $/lb
  out = out.replaceAll(RegExp(r'\b[A-Z]\b$'), '');                   // trailing flags “F”
  return out;
}

bool _looksLikeItem(String line) {
  if (line.trim().isEmpty) return false;
  for (final r in _noise) {
    if (r.hasMatch(line)) return false;
  }
  // must contain alpha and not be just a long code
  if (!RegExp(r'[A-Za-z]').hasMatch(line)) return false;
  if (RegExp(r'^\s*#?\d{6,}\s*$').hasMatch(line)) return false;
  return true;
}

/// qty + unit patterns we will detect
final _unitRe = RegExp(
  r'(?<![A-Za-z0-9])(?:(\d+(?:[.,]\d+)?))\s*(kg|g|lb|oz|l|ml|pcs?|pack|pk|dozen|dz|bag|ct|count)\b',
  caseSensitive: false,
);

/// Also match “2x”, “x2”, “2 pk”, “3 pcs”
final _xQtyRe = RegExp(r'\b(\d+)\s*(?:x|pcs?|pack|pk|ct|count)\b', caseSensitive: false);

String _cleanName(String s) {
  var out = s;
  out = _stripPrices(out);
  out = out.replaceAll(_unitRe, '');
  out = out.replaceAll(_xQtyRe, '');
  out = out.replaceAll(RegExp(r'\bNET\b.*', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'\b@.*'), '');
  out = _tidy(out);
  return out.length <= 2 ? '' : out;
}

ParsedRow _row(String name, {double? qty, String? unit}) {
  final q = (qty == null || qty.isNaN || qty <= 0) ? 1.0 : qty;
  final u = (unit == null || unit.isEmpty) ? 'pcs' : unit.toLowerCase();
  return ParsedRow(name: name, qty: q, unit: u);
}

/// Main entry for RECEIPT text.
/// Call this for mode == receipt.
List<ParsedRow> parseReceiptText(String raw) {
  if (raw.trim().isEmpty) return const [];
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .map((e) => _tidy(_stripPrices(e)))
      .where(_looksLikeItem)
      .toList();

  final items = <ParsedRow>[];
  for (var line in lines) {
    final unit = _unitRe.firstMatch(line);
    final multi = _xQtyRe.firstMatch(line);

    double? qty;
    String? u;

    if (unit != null) {
      qty = double.tryParse(unit.group(1)!.replaceAll(',', '.'));
      u = unit.group(2);
    } else if (multi != null) {
      qty = double.tryParse(multi.group(1)!);
      u = 'pcs';
    }

    final name = _cleanName(line);
    if (name.isEmpty) continue;

    items.add(_row(name, qty: qty, unit: u));
  }

  // Merge duplicates: same name+unit -> sum qty
  final merged = <String, ParsedRow>{};
  for (final it in items) {
    final key = '${it.name.toLowerCase()}|${it.unit.toLowerCase()}';
    final prev = merged[key];
    if (prev == null) {
      merged[key] = it;
    } else {
      merged[key] = _row(
        it.name,
        qty: (prev.qty + max(0.0, it.qty)),
        unit: it.unit,
      );
    }
  }
  return merged.values.toList();
}

/// Main entry for NOTE text.
/// Call this for mode == note (handwritten or typed list).
List<ParsedRow> parseNoteText(String raw) {
  if (raw.trim().isEmpty) return const [];
  final parts = raw.split(RegExp(r'\r?\n|,|•|- ')).map(_tidy).where((e) => e.isNotEmpty);

  final out = <ParsedRow>[];
  for (var line in parts) {
    // inline unit form: "1 kg apples"
    final unit = _unitRe.firstMatch(line);
    final multi = _xQtyRe.firstMatch(line);

    double? qty;
    String? u;

    if (unit != null) {
      qty = double.tryParse(unit.group(1)!.replaceAll(',', '.'));
      u = unit.group(2);
    } else if (multi != null) {
      qty = double.tryParse(multi.group(1)!);
      u = 'pcs';
    } else {
      // leading bare number => pcs: "2 apples"
      final lead = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s+([A-Za-z].*)$').firstMatch(line);
      if (lead != null) {
        qty = double.tryParse(lead.group(1)!.replaceAll(',', '.'));
        u = 'pcs';
        line = lead.group(2)!;
      }
    }

    final name = _cleanName(line);
    if (name.isEmpty) continue;

    out.add(_row(name, qty: qty, unit: u));
  }
  // You can also merge duplicates here if you wish (same as receipt)
  return out;
}
