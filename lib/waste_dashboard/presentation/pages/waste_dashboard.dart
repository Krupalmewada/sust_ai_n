import 'package:flutter/material.dart';

// Relative imports from this page location.
import '../../data/impact_factors/impact_factors.dart';
import '../../domain/services/impact_calculator.dart';
import '../../domain/services/equivalency_mapper.dart';

class WasteDashboardPage extends StatelessWidget {
  const WasteDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waste Dashboard')),
      body: FutureBuilder<ImpactFactorsStore>(
        future: ImpactFactorsStore.load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load impact factors.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final store = snap.data;
          if (store == null) {
            return const Center(child: Text('No impact factors found.'));
          }

          // ---------- Dummy data (replace later with real inventory/recipes) ----------
          // Names should match your CSV keys or their leafs (e.g., "veg.tomato" or "tomato").
          final consumed = <ConsumedItem>[
            const ConsumedItem(name: 'veg.tomato', kg: 0.20), // 200g
            const ConsumedItem(name: 'grain.rice', kg: 0.10), // 100g
            const ConsumedItem(name: 'dairy.milk', kg: 0.25), // 250g
            const ConsumedItem(name: 'protein.chicken', kg: 0.30), // 300g
          ];

          final expired = <ExpiredItem>[
            const ExpiredItem(name: 'fruit.banana', kg: 0.25), // 250g
            const ExpiredItem(name: 'veg.spinach', kg: 0.10), // 100g
          ];

          // Build a quick map for the calculator (exact + leaf access).
          final factorsByKey = {
            ...store.byKey,
            // also include leaf keys for direct lookup
            for (final e in store.byLeaf.entries) e.key: e.value,
          };

          final calc = ImpactCalculator();

          final saved = calc.calcSaved(
            consumed: consumed,
            factorsByKey: factorsByKey,
          );

          final missed = calc.calcMissed(
            expired: expired,
            factorsByKey: factorsByKey,
          );

          final divertedPct = calc.computeWasteDivertedPct(
            consumed: consumed,
            expired: expired,
          );

          // ---------- Friendly lines ----------
          final drivingLine =
          EquivalencyMapper.co2ToDrivingLine(saved.co2SavedKg);
          final showersLine =
          EquivalencyMapper.waterToShowersLine(saved.waterSavedL);
          final homesLine =
          EquivalencyMapper.kwhToHomesLine(saved.energySavedKwh);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle('This Week at a Glance'),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _counterCard(
                      title: 'CO₂ Saved',
                      value: _fmt(saved.co2SavedKg, 'kg'),
                      subtitle: drivingLine,
                      icon: Icons.eco,
                    ),
                    _counterCard(
                      title: 'Water Saved',
                      value: _fmt(saved.waterSavedL, 'L'),
                      subtitle: showersLine,
                      icon: Icons.water_drop,
                    ),
                    _counterCard(
                      title: 'Energy (equiv.)',
                      value: _fmt(saved.energySavedKwh, 'kWh'),
                      subtitle: homesLine,
                      icon: Icons.bolt,
                    ),
                    _counterCard(
                      title: 'Money Saved',
                      value: _money(saved.moneySaved),
                      subtitle: 'Based on price/kg factors',
                      icon: Icons.savings,
                    ),
                    _counterCard(
                      title: 'Waste Diverted',
                      value: '${_round(divertedPct, 1)}%',
                      subtitle: 'Used vs. expired this period',
                      icon: Icons.recycling,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _SectionTitle('Positive Framing'),

                _infoCard(
                  title: 'Missed Savings',
                  body:
                  'Cooking the expired items would have saved ~${_fmt(missed.missedSavingsCo2Kg, 'kg CO₂')}.',
                  icon: Icons.lightbulb,
                ),

                const SizedBox(height: 12),
                _infoCard(
                  title: 'Suggestion',
                  body:
                  'Next opportunity: try a quick stir-fry with spinach and tomatoes to avoid expiry next time.',
                  icon: Icons.tips_and_updates,
                ),

                const SizedBox(height: 24),
                _SectionTitle('Fun Comparison'),

                _infoCard(
                  title: 'Your Impact',
                  body:
                  "• $drivingLine\n• $showersLine\n• $homesLine",
                  icon: Icons.insights,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- UI helpers ----------------

  static String _fmt(num v, String unit) => '${_roundSmart(v)} $unit';

  static String _money(num v) => '₹${_roundSmart(v)}'; // change to C$ if you prefer

  static double _roundSmart(num value) {
    final v = value.toDouble().abs();
    if (v >= 1000) return _round(value, 0);
    if (v >= 100) return _round(value, 1);
    if (v >= 10) return _round(value, 1);
    if (v >= 1) return _round(value, 2);
    return _round(value, 3);
  }

  static double _round(num value, int places) {
    final p = MathPow.pow10(places);
    return (value * p).roundToDouble() / p;
  }

  Widget _counterCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 0.6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// Small helper to avoid importing dart:math and to keep rounding consistent.
class MathPow {
  static double pow10(int places) {
    var p = 1.0;
    for (var i = 0; i < places; i++) {
      p *= 10.0;
    }
    return p;
  }
}
