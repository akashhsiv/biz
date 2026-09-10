import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/platform/desktop_window.dart';
import '../../core/theme/app_theme.dart';
import '../../features/notifications/notifications_provider.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/whatsapp/whatsapp_screen.dart';
import '../../features/whatsapp/whatsapp_status_provider.dart';
import 'user_menu.dart';

/// The single top bar for the signed-in app shell — breadcrumb for the active page on the left,
/// then the live clock, WhatsApp/Host status, signed-in user, and the window's own minimize/
/// maximize/close controls on the right. This *is* the app's title bar once a user is signed in:
/// [CustomTitleBar] (the separate strip shown before login/connection, where there's no other bar
/// to fold these controls into) is skipped entirely once AppShell is showing — see app.dart.
class TopStatusBar extends ConsumerStatefulWidget {
  final String section;
  final String pageTitle;

  const TopStatusBar({super.key, required this.section, required this.pageTitle});

  @override
  ConsumerState<TopStatusBar> createState() => _TopStatusBarState();
}

class _TopStatusBarState extends ConsumerState<TopStatusBar> with WindowListener {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    // window_manager has no Android/iOS implementation - AppShell (and this bar) mounts on both
    // platforms, so unlike CustomTitleBar this one can't just skip building on mobile.
    if (isDesktopWindowed) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((v) {
        if (mounted) setState(() => _maximized = v);
      });
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    if (isDesktopWindowed) windowManager.removeListener(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Container(
      height: 52,
      color: AppPalette.sidebarBackground,
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Text(widget.section, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.chevron_right, size: 14, color: Colors.white.withValues(alpha: 0.3)),
          ),
          Text(widget.pageTitle, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700)),
          // The rest of the bar is empty most of the time — make it double as the window's drag
          // region, same as the title bar it replaces. DragToMoveArea is a no-op gesture region on
          // platforms without window_manager, but it's still safe to build there (it just never
          // receives a drag), so it's not gated behind isDesktopWindowed like the window buttons are.
          Expanded(
            child: DragToMoveArea(
              child: Container(
                alignment: Alignment.centerRight,
                color: Colors.transparent,
                child: Text(
                  DateFormat('HH:mm:ss').format(_now),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          _WhatsappStatusChip(canManage: auth.has(Permissions.whatsappManage)),
          const SizedBox(width: 20),
          const _NotificationBellButton(),
          const SizedBox(width: 12),
          UserMenuButton(
            fullName: auth.fullName,
            roleName: auth.roleName,
            light: true,
            onLogout: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          if (isDesktopWindowed) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.12)),
            _TitleBarButton(icon: Icons.remove, tooltip: 'Minimize', onPressed: () => windowManager.minimize()),
            _TitleBarButton(
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _maximized ? 'Restore' : 'Maximize',
              iconSize: 13,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _TitleBarButton(
              icon: Icons.close,
              tooltip: 'Close',
              hoverColor: const Color(0xFFE81123),
              onPressed: () => windowManager.close(),
            ),
          ] else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;
  final Color? hoverColor;

  const _TitleBarButton({required this.icon, required this.tooltip, required this.onPressed, this.iconSize = 15, this.hoverColor});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onPressed,
        hoverColor: hoverColor ?? Colors.white.withValues(alpha: 0.12),
        child: SizedBox(width: 44, height: 52, child: Icon(icon, size: iconSize, color: Colors.white)),
      ),
    );
  }
}

class _WhatsappStatusChip extends ConsumerWidget {
  final bool canManage;

  const _WhatsappStatusChip({required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(whatsappConnectionStatusProvider);

    return statusAsync.when(
      data: (s) {
        final reachable = s != null && s['reachable'] == true;
        final connected = s != null && s['connected'] == true;
        final color = connected ? const Color(0xFF4ADE80) : (reachable ? const Color(0xFFFBBF24) : const Color(0xFFF87171));
        final label = connected ? 'WhatsApp Connected' : (reachable ? 'WhatsApp Not Paired' : 'WhatsApp Offline');

        final chip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        );

        // Fetching the full status (with QR) needs whatsapp.manage on the backend - only offer the
        // tap-to-view-QR/error dialog to whoever could actually act on it anyway.
        if (!canManage || connected) return chip;

        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => showDialog(context: context, builder: (_) => const WhatsappStatusDialog()),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: chip),
        );
      },
      loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Bell icon + unread-count badge opening [NotificationsScreen], matching the drill-down navigation
/// pattern used elsewhere in the app (Navigator.push to a standalone Scaffold rather than a dialog,
/// since the inbox is a full list with its own filters/actions).
class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadCountProvider);
    final count = countAsync.valueOrNull ?? 0;

    return Tooltip(
      message: 'Notifications',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, size: 20, color: Colors.white),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(color: const Color(0xFFF87171), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
