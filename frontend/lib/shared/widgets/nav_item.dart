import 'package:flutter/widgets.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String? requiredPermission;
  final WidgetBuilder builder;

  const NavItem({
    required this.label,
    required this.icon,
    required this.builder,
    this.requiredPermission,
  });
}
