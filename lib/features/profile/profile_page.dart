import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../waste_dashboard/data/impact_factors/impact_factors.dart';
import '../../waste_dashboard/domain/models/impact_factor.dart';
import '../../waste_dashboard/domain/services/impact_calculator.dart';
import '../../waste_dashboard/domain/services/equivalency_mapper.dart';
import '../../waste_dashboard/presentation/pages/waste_dashboard.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Sign in to see your Waste Impact summary.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<_ProfileSummaryData>(
        future: _loadProfileSummary(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: Text('No data yet. Start logging usage!'));
          }

          final saved = data.saved;
          final divertedPct = data.divertedPct;
          final drivingLine = data.drivingLine;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0.6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Waste Impact (summary)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Last 7 days',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _row('CO₂ saved', _fmt(saved.co2SavedKg, 'kg')),
                        _row('Water saved', _fmt(saved.waterSavedL, 'L')),
                        _row('Energy (equiv.)', _fmt(saved.energySavedKwh, 'kWh')),
                        _row('Money saved', _money(saved.moneySaved)),
                        _row('Waste diverted', '${_round(divertedPct, 1)}%'),
                        const SizedBox(height: 8),
                        Text(
                          drivingLine,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.dashboard_customize),
                  label: const Text('Open Waste Dashboard (detailed)'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WasteDashboardPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------- UI helpers ---------

  static Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static String _fmt(num v, String unit) => '${_roundSmart(v)} $unit';

  // Exact money with two decimals in CAD.
  static String _money(num v) => '\$${v.toStringAsFixed(2)} CAD';

  static double _roundSmart(num value) {
    final v = value.toDouble().abs();
    if (v >= 1000) return _round(value, 0);
    if (v >= 100) return _round(value, 1);
    if (v >= 10) return _round(value, 1);
    if (v >= 1) return _round(value, 2);
    return _round(value, 3);
  }

  static double _round(num value, int places) {
    var p = 1.0;
    for (var i = 0; i < places; i++) {
      p *= 10.0;
    }
    return (value * p).roundToDouble() / p;
  }

  // --------- Data loader: last 7 days summary ---------

  static Future<_ProfileSummaryData> _loadProfileSummary(String userId) async {
    // 1) Load impact factors (CSV)
    final store = await ImpactFactorsStore.load();

    // 2) Time window: last 7 days
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    // 3) Firestore refs
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(userId);

    // 4) Load consumption + waste logs in that period
    final consSnap = await userDoc
        .collection('consumption_logs')
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('at', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    final wasteSnap = await userDoc
        .collection('waste_logs')
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('at', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    // 5) Optional price overrides
    QuerySnapshot<Map<String, dynamic>>? priceSnap;
    try {
      priceSnap = await userDoc.collection('price_overrides').get();
    } catch (_) {
      priceSnap = null;
    }

    // 6) Aggregate logs to ConsumedItem / ExpiredItem
    final consumedMap = <String, double>{};
    final expiredMap = <String, double>{};

    // Consumption
    for (final doc in consSnap.docs) {
      final data = doc.data();
      final leaf = (data['leafKey'] as String?) ?? '';
      final kg = (data['kg'] as num?)?.toDouble() ?? 0;
      if (leaf.isEmpty || kg <= 0) continue;

      final key = (data['key'] as String?)?.trim();
      final category = (data['category'] as String?)?.trim();

      final canonicalKey =
      _buildCanonicalKey(key: key, leafKey: leaf, category: category);

      consumedMap.update(
        canonicalKey,
            (v) => v + kg,
        ifAbsent: () => kg,
      );
    }

    // Waste
    for (final doc in wasteSnap.docs) {
      final data = doc.data();
      final leaf = (data['leafKey'] as String?) ?? '';
      final kg = (data['kg'] as num?)?.toDouble() ?? 0;
      if (leaf.isEmpty || kg <= 0) continue;

      final key = (data['key'] as String?)?.trim();
      final category = (data['category'] as String?)?.trim();

      final canonicalKey =
      _buildCanonicalKey(key: key, leafKey: leaf, category: category);

      expiredMap.update(
        canonicalKey,
            (v) => v + kg,
        ifAbsent: () => kg,
      );
    }

    final consumed = consumedMap.entries
        .map((e) => ConsumedItem(name: e.key, kg: e.value))
        .toList();
    final expired = expiredMap.entries
        .map((e) => ExpiredItem(name: e.key, kg: e.value))
        .toList();

    // 7) Build price overrides map
    final priceOverrides = <String, double>{};
    if (priceSnap != null) {
      for (final doc in priceSnap.docs) {
        final data = doc.data();
        final price = (data['pricePerKg'] as num?)?.toDouble();
        if (price != null && price > 0) {
          priceOverrides[_normKey(doc.id)] = price;
        }
      }
    }

    // 8) Build factorsByKey with overrides (same pattern as dashboard)
    final factorsByKey = _buildFactorsWithOverrides(store, priceOverrides);

    // 9) Run calculations
    final calc = ImpactCalculator();
    final saved =
    calc.calcSaved(consumed: consumed, factorsByKey: factorsByKey);
    final divertedPct =
    calc.computeWasteDivertedPct(consumed: consumed, expired: expired);

    final drivingLine =
    EquivalencyMapper.co2ToDrivingLine(saved.co2SavedKg);

    return _ProfileSummaryData(
      saved: saved,
      divertedPct: divertedPct,
      drivingLine: drivingLine,
    );
  }

  // --------- Key / factor helpers (mirroring waste_dashboard) ---------

  static String _buildCanonicalKey({
    String? key,
    required String leafKey,
    String? category,
  }) {
    if (key != null && key.trim().isNotEmpty) {
      return _normKey(key);
    }
    final leaf = _normKey(leafKey);
    if (category != null && category.trim().isNotEmpty) {
      final cat = _normKey(category);
      return '$cat.$leaf';
    }
    return leaf;
  }

  static Map<String, ImpactFactor> _buildFactorsWithOverrides(
      ImpactFactorsStore store,
      Map<String, double> priceOverrides,
      ) {
    final byKey = <String, ImpactFactor>{};

    // Start with CSV rows, apply price overrides if present
    for (final f in store.rows) {
      final normKey = _normKey(f.foodOrCategory);
      final override = priceOverrides[normKey];
      byKey[normKey] = ImpactFactor(
        foodOrCategory: f.foodOrCategory,
        co2ePerKg: f.co2ePerKg,
        waterLPerKg: f.waterLPerKg,
        energyKwhPerKg: f.energyKwhPerKg,
        pricePerKg: override ?? f.pricePerKg,
        sourceMeta: f.sourceMeta,
        version: f.version,
      );
    }

    // Also index by leaf for fallback lookups
    for (final f in store.rows) {
      final leaf = _leafOf(f.foodOrCategory);
      final normLeaf = _normKey(leaf);
      byKey.putIfAbsent(normLeaf, () => byKey[_normKey(f.foodOrCategory)]!);
    }

    return byKey;
  }

  static String _normKey(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  static String _leafOf(String nameOrKey) {
    final norm = _normKey(nameOrKey);
    final parts = norm.split('.');
    return parts.isEmpty ? norm : parts.last;
  }
}

// Small bundle type for the FutureBuilder
class _ProfileSummaryData {
  final ImpactTotals saved;
  final double divertedPct;
  final String drivingLine;

  const _ProfileSummaryData({
    required this.saved,
    required this.divertedPct,
    required this.drivingLine,
  });
}
