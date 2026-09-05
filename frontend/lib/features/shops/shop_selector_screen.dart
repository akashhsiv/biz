import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import 'shop_model.dart';
import 'shops_provider.dart';

/// Shown after login when the user has access to more than one shop (multi-shop rework) and no
/// valid shop is already selected for this session. Picking a shop calls POST /api/auth/select-shop,
/// which scopes the current session token's role/permissions to that shop server-side.
class ShopSelectorScreen extends ConsumerStatefulWidget {
  const ShopSelectorScreen({super.key});

  @override
  ConsumerState<ShopSelectorScreen> createState() => _ShopSelectorScreenState();
}

class _ShopSelectorScreenState extends ConsumerState<ShopSelectorScreen> {
  String? _selecting;

  Future<void> _select(Shop shop) async {
    setState(() => _selecting = shop.id);
    final result = await ref.read(selectedShopControllerProvider.notifier).selectShop(shop.id);
    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        break;
      case ApiFailure(message: final msg):
        setState(() => _selecting = null);
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        setState(() => _selecting = null);
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopsProvider);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(title: 'Select a Shop', subtitle: 'Choose which shop to work in for this session'),
                const SizedBox(height: 16),
                shopsAsync.when(
                  data: (shops) => Card(
                    child: shops.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No shops are assigned to your account. Contact an administrator.'),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final shop in shops)
                                ListTile(
                                  leading: const Icon(Icons.storefront_outlined),
                                  title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(shop.gstin),
                                  trailing: _selecting == shop.id
                                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.chevron_right),
                                  enabled: shop.isActive && _selecting == null,
                                  onTap: shop.isActive && _selecting == null ? () => _select(shop) : null,
                                ),
                            ],
                          ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load shops: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(shopsProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
