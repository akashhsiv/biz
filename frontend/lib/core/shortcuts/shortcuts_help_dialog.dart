import 'package:flutter/material.dart';

import 'shortcuts_help.dart';

void showShortcutsHelp(BuildContext context) {
  showDialog(context: context, builder: (_) => const ShortcutsHelpDialog());
}

class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final group in appShortcutGroups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(group.title, style: Theme.of(context).textTheme.titleSmall),
                ),
                for (final entry in group.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 170,
                          child: _KeyChip(entry.keys),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.description)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _KeyChip extends StatelessWidget {
  final String text;
  const _KeyChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFamily: 'monospace')),
    );
  }
}
