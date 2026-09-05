import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_variant.dart';
import '../../core/shortcuts/app_shell_shortcuts.dart';
import '../../core/shortcuts/nav_shortcuts.dart';
import '../../core/shortcuts/shortcuts_help_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/company_settings_provider.dart';
import 'connectivity_banner.dart';
import 'nav_item.dart';
import 'top_status_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  final List<NavItem> items;

  const AppShell({super.key, required this.items});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selected = 0;

  @override
  void dispose() {
    AppShellShortcuts.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final visibleItems = widget.items
        .where((i) => i.requiredPermission == null || auth.has(i.requiredPermission!))
        .toList();

    final selected = _selected.clamp(0, visibleItems.length - 1);

    // Registered every build (not just once) via a focus-independent global dispatch - the previous
    // CallbackShortcuts + Focus(autofocus: true) approach silently never fired unless that exact
    // Focus node held keyboard focus, which nothing reliably guaranteed (same root cause the
    // page-level Ctrl+N/F5 shortcuts hit before PageShortcutRegistry replaced their own
    // CallbackShortcuts). See GlobalShortcutsListener, which calls these.
    AppShellShortcuts.register(
      onNavigate: (i) {
        if (i >= 0 && i < visibleItems.length) setState(() => _selected = i);
      },
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      onHelp: () => showShortcutsHelp(context),
    );

    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: Row(
              children: [
                _Sidebar(
                  items: visibleItems,
                  selectedIndex: selected,
                  onSelect: (i) => setState(() => _selected = i),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      TopStatusBar(
                        section: _sidebarSectionFor(visibleItems[selected].label),
                        pageTitle: visibleItems[selected].label,
                      ),
                      Expanded(child: visibleItems[selected].builder(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Purely cosmetic grouping for the sidebar — which section label a nav item's row falls under.
/// Doesn't affect permission filtering, click targets, or the underlying flat [NavItem] list itself;
/// an item with no known label falls back to its own label as a one-off section (safe default for
/// any future nav item added without updating this map).
String _sidebarSectionFor(String label) {
  const sections = {
    'Dashboard': 'OVERVIEW',
    'Customers': 'SALES',
    'Quotations': 'SALES',
    'Proformas': 'SALES',
    'Sales Invoices': 'SALES',
    'Returns': 'SALES',
    'Purchases': 'PURCHASE',
    'Items': 'INVENTORY',
    'Stock': 'INVENTORY',
    'Deposits': 'FINANCE',
    'Finance': 'FINANCE',
    'Expenses': 'FINANCE',
    'WhatsApp': 'COMMUNICATION',
    'Users': 'ADMINISTRATION',
    'Reports': 'ADMINISTRATION',
    'Shop Details': 'ADMINISTRATION',
    'Shop Configuration': 'ADMINISTRATION',
    'Error Log': 'ADMINISTRATION',
  };
  return sections[label] ?? label.toUpperCase();
}

sealed class _SidebarEntry {}

class _SidebarHeader extends _SidebarEntry {
  final String label;
  _SidebarHeader(this.label);
}

class _SidebarItem extends _SidebarEntry {
  final int index; // index into the original (unsectioned) items list — keeps selection/shortcuts unchanged
  _SidebarItem(this.index);
}

/// A hand-rolled sidebar instead of [NavigationRail]: with a growing number of modules, a fixed
/// (non-scrolling) rail runs out of vertical room on anything but a large monitor — the earlier
/// NavigationRail-based version silently overflowed once nav items passed a dozen or so. This one
/// always scrolls the destination list, independent of leading/trailing, at any window height.
class _Sidebar extends ConsumerWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.items, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = <_SidebarEntry>[];
    String? lastSection;
    for (var i = 0; i < items.length; i++) {
      final section = _sidebarSectionFor(items[i].label);
      if (section != lastSection) {
        entries.add(_SidebarHeader(section));
        lastSection = section;
      }
      entries.add(_SidebarItem(i));
    }

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppPalette.sidebarBackground, AppPalette.sidebarBackgroundEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandingHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, entryIndex) {
                final entry = entries[entryIndex];
                if (entry is _SidebarHeader) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(18, entryIndex == 0 ? 6 : 18, 12, 6),
                    child: Text(
                      entry.label,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.white.withValues(alpha: 0.38)),
                    ),
                  );
                }

                final i = (entry as _SidebarItem).index;
                final selected = i == selectedIndex;
                final color = selected ? AppPalette.sidebarTextActive : AppPalette.sidebarText;
                final shortcutLabel = NavShortcuts.labelFor(i);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Tooltip(
                    message: shortcutLabel == null
                        ? items[i].label
                        : '${items[i].label} (Ctrl+${shortcutLabel.startsWith('⇧') ? 'Shift+${shortcutLabel.substring(1)}' : shortcutLabel})',
                    waitDuration: const Duration(milliseconds: 500),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(i),
                        hoverColor: AppPalette.sidebarHover,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: selected ? AppPalette.sidebarActive : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          child: Row(
                            children: [
                              SizedBox(width: 20, child: Icon(items[i].icon, size: 18, color: color)),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  items[i].label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: color),
                                ),
                              ),
                              if (shortcutLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(shortcutLabel, style: const TextStyle(fontSize: 9, color: Colors.white)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showShortcutsHelp(context),
                    icon: const Icon(Icons.keyboard_outlined, size: 15, color: AppPalette.sidebarText),
                    label: const Text('Shortcuts', style: TextStyle(fontSize: 11, color: AppPalette.sidebarText)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppPalette.sidebarHover,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppPalette.sidebarHover,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout, size: 16, color: AppPalette.sidebarText),
                    tooltip: 'Log out (Ctrl+L)',
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the shop's own name/logo once Shop Settings has been configured, falling back to the
/// generic build-variant title (which is all this used to show) while that loads or if unset.
class _BrandingHeader extends ConsumerWidget {
  const _BrandingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(companySettingsProvider);
    final logoAsync = ref.watch(companyLogoBytesProvider);

    final settings = settingsAsync.valueOrNull;
    final shopName = settings?.shopName ?? AppVariant.appTitle;
    final gstin = settings?.gstin;
    final logoBytes = logoAsync.valueOrNull;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppPalette.primary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
              image: logoBytes == null ? null : DecorationImage(image: MemoryImage(Uint8List.fromList(logoBytes)), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: logoBytes == null ? const Icon(Icons.storefront, size: 18, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (gstin != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'GSTIN: $gstin',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
