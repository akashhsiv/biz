import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A single summary metric tile — muted label, large value, optional muted caption/icon. Only ever
/// fed numbers a screen already computed from data it already fetched; never a source of new data.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  /// The one place a tile picks its own color — only to carry meaning (e.g. red for a low-stock
  /// count), never for decoration. Defaults to the standard primary indigo.
  final Color accentColor;

  const KpiCard({super.key, required this.label, required this.value, this.caption, this.icon, this.accentColor = AppPalette.primary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppPalette.textMuted, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppPalette.textPrimary), overflow: TextOverflow.ellipsis),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(caption!, style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays out KPI cards evenly across the available width, wrapping to a new row on narrow windows.
class KpiRow extends StatelessWidget {
  final List<KpiCard> cards;

  const KpiRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (cards.length - 1) * 16) / cards.length;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final c in cards) SizedBox(width: cardWidth.clamp(200, double.infinity), child: c)],
        );
      },
    );
  }
}
