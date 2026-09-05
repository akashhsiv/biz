import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared "New X" action, sized to its label (icon + text) instead of a bare "+" circle, so it's
/// self-explanatory at a glance instead of relying on the tooltip alone.
///
/// Deliberately NOT a FloatingActionButton: the app theme forces `shape: CircleBorder()` on every
/// FAB (including `.extended`), which clips a wide label down to a circle instead of expanding to
/// fit it - a plain FilledButton sized to its own content sidesteps that entirely.
class AppFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final String tooltip;
  final IconData icon;

  const AppFab({super.key, required this.onPressed, this.label = 'New', required this.tooltip, this.icon = Icons.add});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: const LinearGradient(
            colors: [AppPalette.primary, AppPalette.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: AppPalette.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: const StadiumBorder(),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ),
      ),
    );
  }
}
