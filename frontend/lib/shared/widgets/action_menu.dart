import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// One entry in a [RowActionMenu] — must wrap an action the row already supports today; this widget
/// never invents new capability, it only changes how existing per-row actions are presented.
class RowAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const RowAction({required this.label, required this.icon, required this.onTap, this.isDestructive = false});
}

/// A `⋮` popup menu for a table row's actions — replaces a row of inline icon buttons once a row has
/// more than one or two actions, without changing what any of those actions actually do.
class RowActionMenu extends StatelessWidget {
  final List<RowAction> actions;

  const RowActionMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<RowAction>(
      icon: const Icon(Icons.more_vert, size: 18, color: AppPalette.textMuted),
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      onSelected: (action) => action.onTap(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<RowAction>(
            value: action,
            child: Row(
              children: [
                Icon(action.icon, size: 16, color: action.isDestructive ? AppPalette.error : AppPalette.textSecondary),
                const SizedBox(width: 10),
                Text(action.label, style: TextStyle(fontSize: 13, color: action.isDestructive ? AppPalette.error : AppPalette.textPrimary)),
              ],
            ),
          ),
      ],
    );
  }
}
