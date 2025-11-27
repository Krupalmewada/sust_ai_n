import 'package:flutter/material.dart';

import '../../data/impact_factors/impact_factors.dart';
import '../../domain/services/impact_calculator.dart';
import '../../domain/services/equivalency_mapper.dart';

class WasteImpactSummaryCard extends StatelessWidget {
  final VoidCallback onOpenDetails;

  const WasteImpactSummaryCard({
    super.key,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImpactFactorsStore>(
      future: ImpactFactorsStore.load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }
        if (snap.hasError || !snap.hasData) {
          debugPrint('ImpactFactorsStore.load error: ${snap.error}');
          return _buildErrorCard();
        }

        final store = snap.data!;

        // 🔹 Dummy data for now (placeholder until wired to real inventory logs)
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
        final saved =
        calc.calcSaved(consumed: consumed, factorsByKey: factorsByKey);
        final divertedPct =
        calc.computeWasteDivertedPct(consumed: consumed, expired: expired);

        final drivingLine =
        EquivalencyMapper.co2ToDrivingLine(saved.co2SavedKg);

        return _buildCardContent(
          context: context,
          saved: saved,
          divertedPct: divertedPct,
          drivingLine: drivingLine,
        );
      },

    );
  }

  // ------------ UI builders ------------

  Widget _buildLoadingCard() {
    return _BaseCard(
      onTap: null,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 12),
            Text('Loading waste impact…'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return _BaseCard(
      onTap: null,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Waste impact summary is unavailable right now.',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required BuildContext context,
    required ImpactTotals saved,
    required double divertedPct,
    required String drivingLine,
  }) {
    return _BaseCard(
      onTap: onOpenDetails,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'Your Waste Impact (summary)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Last 7 days',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics
            _metricRow('CO₂ saved', _fmt(saved.co2SavedKg, 'kg')),
            _metricRow('Water saved', _fmt(saved.waterSavedL, 'L')),
            _metricRow('Energy (equiv.)', _fmt(saved.energySavedKwh, 'kWh')),
            _metricRow('Money saved', _money(saved.moneySaved)),
            _metricRow('Waste diverted', '${_round(divertedPct, 1)}%'),

            const SizedBox(height: 8),
            Text(
              drivingLine,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // CTA line
            Row(
              children: const [
                Spacer(),
                Text(
                  'View detailed dashboard  ›',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ------------ Formatting helpers ------------

  static String _fmt(num v, String unit) => '${_roundSmart(v)} $unit';

  /// Show full-precision money (2 decimals) in CAD without extra rounding.
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
}

// Base card with tap ripple
class _BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BaseCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.white,
      elevation: 0.8,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: child,
      ),
    );
  }
}
