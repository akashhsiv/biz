import 'package:flutter/material.dart';

/// Prompts for a mandatory reason (cancellations, rejections, adjustments — every one of these
/// operations requires a reason per ARCHITECTURE.md's audit rules). Returns null if the user
/// cancelled or left it blank.
Future<String?> showReasonDialog(BuildContext context, {required String title}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Reason (required)'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            Navigator.of(context).pop(text.isEmpty ? null : text);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}
