import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../shared/widgets/app_toast.dart';
import 'shop_selector_screen.dart';
import 'shops_provider.dart';

/// Sits between login and AppShell once a session is authenticated but no shop has been selected
/// yet for it (nothing persisted from a previous session, multi-shop rework). Fetches the user's
/// accessible shops: a single shop is auto-selected with no picker shown; more than one shows
/// [ShopSelectorScreen]; zero shows a blocking message since the app has nothing to display.
class ShopGate extends ConsumerStatefulWidget {
  const ShopGate({super.key});

  @override
  ConsumerState<ShopGate> createState() => _ShopGateState();
}

class _ShopGateState extends ConsumerState<ShopGate> {
  bool _autoSelecting = false;

  Future<void> _autoSelectSingleShop(String shopId) async {
    if (_autoSelecting) return;
    setState(() => _autoSelecting = true);
    final result = await ref.read(selectedShopControllerProvider.notifier).selectShop(shopId);
    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        break; // selectedShopControllerProvider's state now holds the shop id, AppShell shows next.
      case ApiFailure():
      case ApiNetworkError():
        // Fall through to showing the picker (with just the one shop) so the user can retry the tap
        // manually instead of being stuck on a spinner forever.
        setState(() => _autoSelecting = false);
        AppToast.error('Could not select your shop automatically. Tap it below to retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopsProvider);

    return shopsAsync.when(
      data: (shops) {
        if (shops.length == 1) {
          if (!_autoSelecting) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectSingleShop(shops.first.id));
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // Zero shops or more than one: ShopSelectorScreen itself shows the "no shops assigned"
        // message for the empty case, so there's nothing extra to branch on here.
        return const ShopSelectorScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const ShopSelectorScreen(),
    );
  }
}
