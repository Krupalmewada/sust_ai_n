import 'package:flutter/material.dart';

import '../../waste_dashboard/data/impact_factors/impact_factors.dart';
import '../../waste_dashboard/domain/services/impact_calculator.dart';
import '../../waste_dashboard/domain/services/equivalency_mapper.dart';
import '../../waste_dashboard/presentation/pages/waste_dashboard.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<ImpactFactorsStore>(
        future: ImpactFactorsStore.load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final store = snap.data;
          if (store == null) return const Center(child: Text('No data.'));

          // --- Dummy summary data (replace later with real) ---
          final consumed = <ConsumedItem>[
            const ConsumedItem(name: 'veg.tomato', kg: 0.20),
            const ConsumedItem(name: 'grain.rice', kg: 0.10),
            const ConsumedItem(name: 'dairy.milk', kg: 0.25),
          ];
          final expired = <ExpiredItem>[
            const ExpiredItem(name: 'fruit.banana', kg: 0.25),
          ];

          final factorsByKey = {
            ...store.byKey,
            for (final e in store.byLeaf.entries) e.key: e.value,
          };

          final calc = ImpactCalculator();
          final saved = calc.calcSaved(consumed: consumed, factorsByKey: factorsByKey);
          final divertedPct = calc.computeWasteDivertedPct(consumed: consumed, expired: expired);

          final drivingLine = EquivalencyMapper.co2ToDrivingLine(saved.co2SavedKg);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0.6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Waste Impact (summary)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        _row('CO₂ saved', _fmt(saved.co2SavedKg, 'kg')),
                        _row('Water saved', _fmt(saved.waterSavedL, 'L')),
                        _row('Energy (equiv.)', _fmt(saved.energySavedKwh, 'kWh')),
                        _row('Money saved', _money(saved.moneySaved)),
                        _row('Waste diverted', '${_round(divertedPct, 1)}%'),
                        const SizedBox(height: 8),
                        Text(drivingLine, style: const TextStyle(color: Colors.grey)),
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
                      MaterialPageRoute(builder: (_) => const WasteDashboardPage()),
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
  static String _money(num v) => '₹${_roundSmart(v)}';

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
}
