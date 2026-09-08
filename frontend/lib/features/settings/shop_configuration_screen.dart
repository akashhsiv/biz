import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/shortcuts/app_key_sets.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'company_settings_model.dart';
import 'company_settings_provider.dart';

/// Payment/branding/document-template settings, split out of the identity-only Shop Details screen
/// (confirmed decision 2026-08-28): Bank Details, UPI ID (for the QR shown on documents),
/// Authorized Signature image, the per-document-type Terms/Footer templates, WhatsApp message
/// templates, and a read-only view of the backup system. See CompanySettingsScreen's doc comment
/// for why _save resends the identity fields unchanged from whatever was last loaded.
class ShopConfigurationScreen extends ConsumerStatefulWidget {
  const ShopConfigurationScreen({super.key});

  @override
  ConsumerState<ShopConfigurationScreen> createState() => _ShopConfigurationScreenState();
}

class _ShopConfigurationScreenState extends ConsumerState<ShopConfigurationScreen> {
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _bankIfsc = TextEditingController();
  final _bankBranch = TextEditingController();
  final _upiId = TextEditingController();

  final _salesInvoiceTerms = TextEditingController();
  final _salesInvoiceFooter = TextEditingController();
  final _purchaseOrderTerms = TextEditingController();
  final _purchaseOrderFooter = TextEditingController();

  final _waSalesInvoiceTemplate = TextEditingController();
  final _waDepositReceiptTemplate = TextEditingController();

  bool _showSignatureBlock = false;

  bool _loaded = false;
  bool _saving = false;
  String? _error;
  CompanySettings? _original;

  void _populate(CompanySettings s) {
    _original = s;
    if (_loaded) return;
    _bankName.text = s.bankName ?? '';
    _bankAccount.text = s.bankAccountNumber ?? '';
    _bankIfsc.text = s.bankIfscCode ?? '';
    _bankBranch.text = s.bankBranch ?? '';
    _upiId.text = s.upiId ?? '';
    _salesInvoiceTerms.text = s.salesInvoiceTermsAndConditions ?? '';
    _salesInvoiceFooter.text = s.salesInvoiceFooterNote ?? '';
    _purchaseOrderTerms.text = s.purchaseOrderTermsAndConditions ?? '';
    _purchaseOrderFooter.text = s.purchaseOrderFooterNote ?? '';
    _waSalesInvoiceTemplate.text = s.whatsappSalesInvoiceMessageTemplate ?? '';
    _waDepositReceiptTemplate.text = s.whatsappDepositReceiptMessageTemplate ?? '';
    _showSignatureBlock = s.showSignatureBlock;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final o = _original;
    final api = ref.read(apiClientProvider);
    final result = await api.put<void>(
      '/api/company-settings',
      (_) {},
      body: {
        'shopName': o?.shopName ?? '',
        'gstin': o?.gstin ?? '',
        'state': o?.state ?? '',
        'address': o?.address,
        'contactNumber': o?.contactNumber,
        'bankName': _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        'bankAccountNumber': _bankAccount.text.trim().isEmpty ? null : _bankAccount.text.trim(),
        'bankIfscCode': _bankIfsc.text.trim().isEmpty ? null : _bankIfsc.text.trim(),
        'bankBranch': _bankBranch.text.trim().isEmpty ? null : _bankBranch.text.trim(),
        'upiId': _upiId.text.trim().isEmpty ? null : _upiId.text.trim(),
        'showLogoOnDocuments': o?.showLogoOnDocuments ?? true,
        'showSignatureBlock': _showSignatureBlock,
        'salesInvoiceTermsAndConditions': _salesInvoiceTerms.text.trim().isEmpty ? null : _salesInvoiceTerms.text.trim(),
        'salesInvoiceFooterNote': _salesInvoiceFooter.text.trim().isEmpty ? null : _salesInvoiceFooter.text.trim(),
        'purchaseOrderTermsAndConditions': _purchaseOrderTerms.text.trim().isEmpty ? null : _purchaseOrderTerms.text.trim(),
        'purchaseOrderFooterNote': _purchaseOrderFooter.text.trim().isEmpty ? null : _purchaseOrderFooter.text.trim(),
        'whatsappSalesInvoiceMessageTemplate': _waSalesInvoiceTemplate.text.trim().isEmpty ? null : _waSalesInvoiceTemplate.text.trim(),
        'whatsappDepositReceiptMessageTemplate': _waDepositReceiptTemplate.text.trim().isEmpty ? null : _waDepositReceiptTemplate.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(companySettingsProvider);
        AppToast.success('Saved.');
      case ApiFailure(message: final msg):
        setState(() => _error = msg);
      case ApiNetworkError(message: final msg):
        setState(() => _error = 'Could not reach the Host: $msg');
    }
  }

  Future<void> _pickSignature() async {
    const typeGroup = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final api = ref.read(apiClientProvider);
    final result = await api.put<void>(
      '/api/company-settings/signature',
      (_) {},
      body: {'signatureBase64': base64Encode(bytes)},
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(companySettingsProvider);
        ref.invalidate(companySignatureBytesProvider);
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(companySettingsProvider);
    final signatureAsync = ref.watch(companySignatureBytesProvider);

    return CallbackShortcuts(
      bindings: {
        if (!_saving) AppKeys.ctrlS: _save,
      },
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: settingsAsync.when(
          data: (settings) {
            if (settings == null) return const Center(child: Text('Could not load shop settings.'));
            _populate(settings);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(title: 'Shop Configuration', subtitle: 'Payment details, document branding, and message templates'),
                    const SizedBox(height: 20),
                    Text('Payment Details (shown on PDFs)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'Bank Name')),
                    const SizedBox(height: 8),
                    TextField(controller: _bankAccount, decoration: const InputDecoration(labelText: 'Account Number')),
                    const SizedBox(height: 8),
                    TextField(controller: _bankIfsc, decoration: const InputDecoration(labelText: 'IFSC Code')),
                    const SizedBox(height: 8),
                    TextField(controller: _bankBranch, decoration: const InputDecoration(labelText: 'Branch')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _upiId,
                      decoration: const InputDecoration(labelText: 'UPI ID', hintText: 'shopname@upi'),
                    ),
                    Text(
                      'When set, a QR code (pre-filled with each document\'s amount) is shown on Sales Invoices.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    Text('Authorized Signature', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        signatureAsync.when(
                          data: (bytes) => Container(
                            width: 120,
                            height: 60,
                            decoration: BoxDecoration(border: Border.all(color: AppPalette.border), borderRadius: BorderRadius.circular(6)),
                            alignment: Alignment.center,
                            child: bytes == null
                                ? const Icon(Icons.draw_outlined, color: AppPalette.textMuted)
                                : Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain),
                          ),
                          loading: () => const SizedBox(width: 120, height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                          error: (_, _) => const SizedBox(width: 120, height: 60),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(onPressed: _pickSignature, icon: const Icon(Icons.upload), label: const Text('Upload Signature')),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show "Authorized Signatory" block'),
                      value: _showSignatureBlock,
                      onChanged: (v) => setState(() => _showSignatureBlock = v),
                    ),
                    const SizedBox(height: 24),
                    Text('Document Templates', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Editable per document type below. Leave a field blank to fall back to the default.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _DocumentTemplateSection(title: 'Sales Invoice', termsController: _salesInvoiceTerms, footerController: _salesInvoiceFooter),
                    _DocumentTemplateSection(title: 'Purchase Order', termsController: _purchaseOrderTerms, footerController: _purchaseOrderFooter),
                    const SizedBox(height: 24),
                    Text('WhatsApp Message Templates', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Leave blank to use the default wording. Available variables shown under each field.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _WhatsappTemplateField(
                      label: 'Sales Invoice',
                      controller: _waSalesInvoiceTemplate,
                      variables: '{customerName} {invoiceNumber} {grandTotal} {shopName}',
                    ),
                    _WhatsappTemplateField(
                      label: 'Deposit Receipt',
                      controller: _waDepositReceiptTemplate,
                      variables: '{customerName} {shopName}',
                    ),
                    const SizedBox(height: 24),
                    const _BackupStatusCard(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    Tooltip(
                      message: 'Ctrl+S',
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonBox(height: 48))],
                ),
              ),
            ),
          ),
          error: (e, _) => Center(child: Text('Failed to load: $e')),
        ),
      ),
    );
  }
}

/// One document type's Terms & Conditions + footer note editor, collapsed by default so 4 of
/// these don't turn this screen into an intimidating wall of text fields.
class _DocumentTemplateSection extends StatelessWidget {
  final String title;
  final TextEditingController termsController;
  final TextEditingController footerController;

  const _DocumentTemplateSection({
    required this.title,
    required this.termsController,
    required this.footerController,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        TextField(
          controller: termsController,
          decoration: const InputDecoration(labelText: 'Terms & Conditions', border: OutlineInputBorder()),
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: footerController,
          decoration: const InputDecoration(
            labelText: 'Footer Note',
            hintText: 'Generated by the ERP system. This document was produced entirely offline.',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}

class _WhatsappTemplateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String variables;

  const _WhatsappTemplateField({required this.label, required this.controller, required this.variables});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 2),
          Text(variables, style: const TextStyle(fontSize: 11, color: AppPalette.textMuted, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class _BackupStatusCard extends ConsumerWidget {
  const _BackupStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupAsync = ref.watch(backupStatusProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.backup_outlined, size: 18, color: AppPalette.primary),
                const SizedBox(width: 8),
                Text('Backup & Database', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            backupAsync.when(
              data: (b) {
                if (b == null) return const Text('Could not load backup status.');

                final backupDirectory = b['backupDirectory'] as String?;
                final databaseName = b['databaseName'] as String?;
                final databaseHost = b['databaseHost'] as String?;
                final dailyHourUtc = b['dailyHourUtc'] as int?;
                final retentionCount = b['retentionCount'] as int?;
                final last = b['lastBackup'] as Map<String, dynamic>?;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Backup folder', backupDirectory ?? '-'),
                    _row('Database', '${databaseName ?? '-'} @ ${databaseHost ?? '-'}'),
                    _row('Schedule', 'Runs daily at ${(dailyHourUtc ?? 2).toString().padLeft(2, '0')}:00 UTC, keeps last ${retentionCount ?? '-'}'),
                    if (last == null)
                      _row('Last backup', 'No backup has run yet.')
                    else
                      _row(
                        'Last backup',
                        // BackupStatus enum: 0=Success, 1=Failed (serialized as its raw int value).
                        '${DateTime.parse(last['createdAt'] as String).toLocal()} — '
                        '${last['status'] == 0 ? 'Success' : 'Failed'} '
                        '(${((last['sizeBytes'] as num).toDouble() / 1024 / 1024).toStringAsFixed(1)} MB)',
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load backup status: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppPalette.textMuted, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}
