import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'app_toast.dart';

String _last10Digits(String? number) {
  if (number == null) return '';
  final digits = number.replaceAll(RegExp(r'\D'), '');
  return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
}

/// Manual-trigger only (confirmed decision, ARCHITECTURE.md §13 item 14) — nothing is ever
/// auto-queued on document creation. Only visible to whoever holds whatsapp.manage.
class WhatsappSendButton extends ConsumerWidget {
  final int messageType;
  final int referenceType;
  final String referenceId;

  /// Pre-fills the recipient field (e.g. the document's customer's stored contact number) — still
  /// a normal editable field, this only saves re-typing the common case.
  final String? defaultRecipientNumber;

  const WhatsappSendButton({super.key, required this.messageType, required this.referenceType, required this.referenceId, this.defaultRecipientNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.has(Permissions.whatsappManage)) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.chat_outlined),
      tooltip: 'Send via WhatsApp',
      onPressed: () => showDialog(
        context: context,
        builder: (_) => _SendDialog(
          messageType: messageType,
          referenceType: referenceType,
          referenceId: referenceId,
          defaultRecipientNumber: defaultRecipientNumber,
        ),
      ),
    );
  }
}

class _SendDialog extends ConsumerStatefulWidget {
  final int messageType;
  final int referenceType;
  final String referenceId;
  final String? defaultRecipientNumber;
  const _SendDialog({required this.messageType, required this.referenceType, required this.referenceId, this.defaultRecipientNumber});

  @override
  ConsumerState<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends ConsumerState<_SendDialog> {
  // This field only ever holds a plain 10-digit local number (the country code is added on the
  // Host, not typed here) - trim a longer stored value (e.g. one saved with a country code
  // already, or a landline-style number) down to its last 10 digits so it fits the field's cap.
  late final _number = TextEditingController(text: _last10Digits(widget.defaultRecipientNumber));
  bool _saving = false;
  String? _error;

  Future<void> _send() async {
    if (_number.text.trim().isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/whatsapp/send',
      (json) => json as Map<String, dynamic>,
      body: {
        'messageType': widget.messageType,
        'referenceType': widget.referenceType,
        'referenceId': widget.referenceId,
        'recipientNumber': _number.text.trim(),
        'customMessage': null,
      },
      // A document send (Quotation/Invoice/Proforma) attaches the PDF and can take noticeably
      // longer than a plain text message - matches the Host's own 45s bridge-call timeout.
      receiveTimeout: const Duration(seconds: 50),
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess(data: final data):
        Navigator.of(context).pop();
        // WhatsappOutboxStatus enum: 0=Queued, 1=Sending, 2=Sent, 3=Failed - serialized as its raw
        // int value (no JsonStringEnumConverter registered), same as whatsapp_screen.dart's outbox list.
        final sent = data['status'] == 2;
        if (sent) {
          AppToast.success('Sent via WhatsApp.');
        } else {
          AppToast.info('Could not send immediately — queued for retry.');
        }
      case ApiFailure(message: final msg):
        setState(() {
          _saving = false;
          _error = msg;
        });
      case ApiNetworkError(message: final msg):
        setState(() {
          _saving = false;
          _error = 'Could not reach the Host: $msg';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send via WhatsApp'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _number,
              decoration: const InputDecoration(labelText: 'Recipient number', hintText: '98XXXXXXXX', counterText: ''),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _send,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send'),
        ),
      ],
    );
  }
}
