import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/constants/backend_config.dart';
import 'core/logging/file_logger.dart';
import 'core/platform/desktop_window.dart';
import 'core/providers.dart';
import 'features/shops/shops_provider.dart';
import 'shared/widgets/custom_title_bar.dart';
import 'shared/widgets/overlay_host.dart';

void main() {
  // Binding init and runApp must happen in the same zone - FileLogger.install runs its callback
  // inside runZonedGuarded, so everything (including the async window setup) has to happen inside
  // that callback rather than before it, or Flutter's "Zone mismatch" assertion fires.
  FileLogger.install(() {
    WidgetsFlutterBinding.ensureInitialized();
    _initWindowAndRun();
  });
}

Future<void> _initWindowAndRun() async {
  // window_manager has no Android/iOS implementation - guard every call behind isDesktopWindowed
  // (Platform.isWindows today) so a mobile build doesn't crash on startup calling into a platform
  // channel nothing registered.
  if (isDesktopWindowed) {
    // Frameless window (confirmed decision 2026-08-28) - CustomTitleBar (mounted in _Bootstrap/ErpApp
    // below) replaces the native title bar entirely with its own draggable/sidebar-themed one.
    await windowManager.ensureInitialized();
    // Below this, the sidebar + master-detail/table layouts start clipping and overlapping rather
    // than reflowing - there's no responsive breakpoint for "narrower than the sidebar can support",
    // so the window itself is kept from ever getting that small instead.
    const minimumSize = Size(1024, 700);
    const windowOptions = WindowOptions(titleBarStyle: TitleBarStyle.hidden, size: Size(1280, 800), minimumSize: minimumSize);
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(minimumSize);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: _Bootstrap()));
}

/// Restores a cached session (if any) before the first frame decides which screen to show —
/// avoids a flash of the login screen for an already-logged-in user.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // The backend is a single fixed cloud address now (no more per-install LAN Host to type or
    // auto-discover) - set it once, unconditionally, before anything else touches the API client.
    ref.read(apiClientProvider).setBaseUrl(kBackendBaseUrl);
    ref.read(authControllerProvider.notifier).restoreFromCache().then((_) async {
      await ref.read(selectedShopControllerProvider.notifier).restoreFromCache();
      // Previously only done on ConnectionController's first successful connect (there was no Host
      // to validate against before that). The backend address is now fixed and always known, so
      // this is the equivalent hook - validate any cached session once at startup instead.
      await ref.read(authControllerProvider.notifier).validateSession();
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        // CustomTitleBar's Tooltips need an Overlay ancestor - it sits outside MaterialApp's own
        // Navigator (which owns the only Overlay otherwise), so it needs its own here.
        builder: (context, child) => OverlayHost(
          child: Column(children: [const CustomTitleBar(), Expanded(child: child!)]),
        ),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return const ErpApp();
  }
}
