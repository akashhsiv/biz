import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared "nothing here yet" placeholder — an icon, a short title, optional muted detail text, and
/// an optional call-to-action button. [AppListCard] uses this internally for its own empty rows;
/// it's also usable standalone (e.g. a KPI section before any data exists).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppPalette.textMuted.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: AppPalette.textMuted, fontSize: 13)),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
