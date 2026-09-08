/// A hand-maintained registry of every keyboard shortcut in the app, grouped for display in
/// [ShortcutsHelpDialog]. Kept as plain data (not derived from the actual key bindings) because
/// those live scattered across each screen's own `CallbackShortcuts` — this is the one place a
/// developer adding a new shortcut must also update, and the one place a user can see the whole
/// list at a glance instead of hunting for tooltips one button at a time.
class ShortcutGroup {
  final String title;
  final List<ShortcutEntry> entries;
  const ShortcutGroup(this.title, this.entries);
}

class ShortcutEntry {
  final String keys;
  final String description;
  const ShortcutEntry(this.keys, this.description);
}

const List<ShortcutGroup> appShortcutGroups = [
  ShortcutGroup('Global', [
    ShortcutEntry('F1', 'Show this keyboard shortcuts list'),
    ShortcutEntry('Ctrl+L', 'Log out'),
    ShortcutEntry('Ctrl+1 … Ctrl+9, Ctrl+0', 'Jump to the 1st–10th sidebar module'),
    ShortcutEntry('Ctrl+Shift+1 … Ctrl+Shift+5', 'Jump to the 11th–15th sidebar module'),
    ShortcutEntry('Esc', 'Close the open dialog (built into every dialog in the app)'),
  ]),
  ShortcutGroup('Customers, Items, Deposits, Returns, Suppliers, Purchase Orders, Users', [
    ShortcutEntry('Ctrl+N', "New — opens that screen's create dialog (if you have permission)"),
    ShortcutEntry('F5', 'Refresh the list'),
  ]),
  ShortcutGroup('Stock', [
    ShortcutEntry('Ctrl+N', 'Adjust Stock (if you have permission)'),
    ShortcutEntry('F5', 'Refresh'),
  ]),
  ShortcutGroup('Finance', [
    ShortcutEntry('Ctrl+N', 'Record Amount Out'),
    ShortcutEntry('F5', 'Refresh'),
  ]),
  ShortcutGroup('Sales Invoices, Roles, Reports, WhatsApp', [
    ShortcutEntry('F5', 'Refresh — these have no direct "New" action'),
  ]),
  ShortcutGroup('Shop Settings', [
    ShortcutEntry('Ctrl+S', 'Save changes'),
  ]),
];
