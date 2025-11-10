// lib/features/ocr_scan/domain/spell_correct.dart

// Lightweight spelling correction for grocery terms.
// Edit-distance (Damerau-Levenshtein) to a small extensible vocabulary.
// Keep it fast and local-only.

final Set<String> _vocab = {
  // Core groceries (seed — extend over time or load from assets)
  'eggs','milk','butter','cheese','bread','cream','sour','pasta','sauce',
  'bananas','apples','raspberries','ice','icecream','ice-cream','hot','dogs','coffee',
  'yogurt','tomato','tomatoes','onion','onions','garlic','ginger','salt','sugar',
  'rice','flour','oil','olive','pepper','tea','beans','lentils','oats','cereal',
  'juice','water','soda','chips','cookies','chocolate','ketchup','mustard','mayonnaise',
  'chicken','beef','pork','fish','shrimp','ham','bacon','sausage',
  'lettuce','spinach','cucumber','carrot','carrots','potato','potatoes',
  'banana','apple','orange','oranges','grapes','strawberries','blueberries','blackberries',
  'buttermilk','whipped','whipping','sourcream','pasta sauce','pasta-sauce',
};

// Entry point: correct a short phrase (e.g., "ice crerm" -> "Ice Cream").
String correctPhrase(String phrase) {
  final parts = phrase.split(RegExp(r'\s+'));
  final fixed = <String>[];
  for (final raw in parts) {
    final w = raw.trim();
    if (w.isEmpty) continue;
    fixed.add(_correctToken(w.toLowerCase()));
  }
  return fixed.join(' ').trim();
}

String _correctToken(String w) {
  // Already in vocab?
  if (_vocab.contains(w)) return _capitalize(w);

  // Try split into two words (e.g., "icecream" -> "Ice Cream")
  for (int i = 2; i < w.length - 1; i++) {
    final a = w.substring(0, i);
    final b = w.substring(i);
    if (_vocab.contains(a) && _vocab.contains(b)) {
      return '${_capitalize(a)} ${_capitalize(b)}';
    }
  }

  // Nearest vocab within distance 2
  String best = w;
  int bestDist = 3; // only accept <= 2
  for (final v in _vocab) {
    final d = _dlDistance(w, v);
    if (d < bestDist) {
      bestDist = d;
      best = v;
      if (bestDist == 0) break;
    }
  }
  if (bestDist <= 2) return _capitalize(best);

  // Common OCR confusions normalization, then retry once
  final normalized = w
      .replaceAll('|', 'l')
      .replaceAll('0', 'o')
      .replaceAll('2', 'z')
      .replaceAll('5', 's')
      .replaceAll('1', 'l');
  if (normalized != w) return _correctToken(normalized);

  return _capitalize(w);
}

// Damerau–Levenshtein distance (small strings; O(mn))
int _dlDistance(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (int i = 0; i <= m; i++) { dp[i][0] = i; }
  for (int j = 0; j <= n; j++) { dp[0][j] = j; }

  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      final cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
      int val = dp[i - 1][j] + 1;              // deletion
      if (dp[i][j - 1] + 1 < val) val = dp[i][j - 1] + 1; // insertion
      if (dp[i - 1][j - 1] + cost < val) val = dp[i - 1][j - 1] + cost; // subst
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final t = dp[i - 2][j - 2] + cost; // transposition
        if (t < val) val = t;
      }
      dp[i][j] = val;
    }
  }
  return dp[m][n];
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
