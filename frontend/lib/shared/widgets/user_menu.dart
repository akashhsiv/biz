import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Top-bar identity control — avatar initials + name + role + a dropdown for Logout. Replaces the
/// previous static, non-interactive "icon + name + role" text in [TopStatusBar]; [onLogout] is
/// always the app's one existing logout action, never new logic of its own.
class UserMenuButton extends StatelessWidget {
  final String fullName;
  final String roleName;
  final VoidCallback onLogout;

  /// True when this sits on a dark bar (the top header) — swaps name/chevron to white/near-white
  /// instead of the default dark-on-light text colors.
  final bool light;

  const UserMenuButton({super.key, required this.fullName, required this.roleName, required this.onLogout, this.light = false});

  String get _initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text(roleName, style: const TextStyle(fontSize: 12, color: AppPalette.textMuted))),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [Icon(Icons.logout, size: 16, color: AppPalette.error), SizedBox(width: 10), Text('Log out')]),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: light ? Colors.white.withValues(alpha: 0.16) : AppPalette.primaryLight,
            child: Text(_initials, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: light ? Colors.white : AppPalette.primaryDark)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fullName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: light ? Colors.white : AppPalette.textPrimary)),
              Text(roleName, style: TextStyle(fontSize: 10, color: light ? Colors.white.withValues(alpha: 0.55) : AppPalette.textMuted)),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 16, color: light ? Colors.white.withValues(alpha: 0.7) : AppPalette.textMuted),
        ],
      ),
    );
  }
}
