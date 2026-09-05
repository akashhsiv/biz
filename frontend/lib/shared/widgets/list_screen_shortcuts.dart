import 'package:flutter/material.dart';

import '../../core/shortcuts/shortcut_registry.dart';

/// Registers a list screen's add/refresh actions so Ctrl+N and F5 (handled globally by
/// GlobalShortcutsListener at the app root) do the same thing as that screen's own add/refresh
/// buttons, as long as this screen is the one currently on display - not dependent on any widget
/// inside it actually holding keyboard focus. Pass null for whichever action the screen/tab doesn't
/// have (e.g. `onNew: null` when the current user lacks the manage permission for it).
///
/// If this screen is one tab among several under a `DefaultTabController` (Purchases, Users,
/// Reports), pass [tabIndex] so only the currently-selected tab's shortcuts are active - otherwise
/// every tab would register itself as soon as it mounts (TabBarView keeps built tabs alive), and
/// whichever one happened to (re)build last would silently steal Ctrl+N/F5 from the tab actually
/// showing on screen.
class ListScreenShortcuts extends StatefulWidget {
  final VoidCallback? onNew;
  final VoidCallback? onRefresh;
  final Widget child;
  final int? tabIndex;

  const ListScreenShortcuts({super.key, this.onNew, this.onRefresh, required this.child, this.tabIndex});

  @override
  State<ListScreenShortcuts> createState() => _ListScreenShortcutsState();
}

class _ListScreenShortcutsState extends State<ListScreenShortcuts> {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.tabIndex != null) {
      final controller = DefaultTabController.of(context);
      if (!identical(controller, _tabController)) {
        _tabController?.removeListener(_onTabChanged);
        _tabController = controller;
        _tabController!.addListener(_onTabChanged);
        _syncActive();
      }
    } else {
      _syncActive();
    }
  }

  @override
  void didUpdateWidget(covariant ListScreenShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    // onNew/onRefresh are fresh closures every build (they close over the latest setState/ref) -
    // keep the registry pointed at the current ones whenever this is the active page/tab.
    if (widget.tabIndex == null || _tabController?.index == widget.tabIndex) {
      _syncActive();
    }
  }

  void _onTabChanged() {
    if (_tabController!.indexIsChanging) return;
    _syncActive();
  }

  void _syncActive() {
    final isActive = widget.tabIndex == null || _tabController?.index == widget.tabIndex;
    if (isActive) {
      PageShortcutRegistry.setActive(this, onNew: widget.onNew, onRefresh: widget.onRefresh);
    } else {
      PageShortcutRegistry.clearIfActive(this);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    PageShortcutRegistry.clearIfActive(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
