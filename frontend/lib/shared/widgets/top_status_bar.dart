import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../features/connection/connection_controller.dart';
import '../../features/host/host_status_card.dart';
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
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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
    final connection = ref.watch(connectionControllerProvider);

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
          // region, same as the title bar it replaces.
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
          if (connection.hostUrl != null) ...[
            _HostAddressChip(hostUrl: connection.hostUrl!, canViewStatus: auth.has(Permissions.hostStatusView)),
            const SizedBox(width: 20),
          ],
          _WhatsappStatusChip(canManage: auth.has(Permissions.whatsappManage)),
          const SizedBox(width: 20),
          UserMenuButton(
            fullName: auth.fullName,
            roleName: auth.roleName,
            light: true,
            onLogout: () => ref.read(authControllerProvider.notifier).logout(),
          ),
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
        ],
      ),
    );
  }
}

/// The Host address text, promoted to a button (when the signed-in user can see Host status) that
/// opens the same [HostStatusCard] previously embedded directly in the Dashboard — a detail view
/// reachable from anywhere instead of only from that one page.
class _HostAddressChip extends StatelessWidget {
  final String hostUrl;
  final bool canViewStatus;

  const _HostAddressChip({required this.hostUrl, required this.canViewStatus});

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lan_outlined, size: 13, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 5),
        Text(
          hostUrl.replaceFirst('http://', ''),
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35), fontFamily: 'monospace'),
        ),
      ],
    );

    if (!canViewStatus) return chip;

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => showDialog(
        context: context,
        builder: (_) => const Dialog(child: SizedBox(width: 440, child: HostStatusCard())),
      ),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: chip),
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
