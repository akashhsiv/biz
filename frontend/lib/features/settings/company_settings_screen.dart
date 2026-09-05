import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Admin-only editor for the shop's identity — name/logo/GST/address/contact, shown on generated
/// PDFs and in the app's nav header. Bank details, UPI, signature, and document templates live on
/// the separate Shop Configuration screen (confirmed decision 2026-08-28 — this one stays lean).
/// Both screens edit the same single-row CompanySettings record via the same PUT endpoint (which
/// replaces the whole row), so each screen re-sends the other's fields unchanged from whatever was
/// last loaded — see [_save].
class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  ConsumerState<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  final _shopName = TextEditingController();
  final _gstin = TextEditingController();
  final _state = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();

  bool _showLogoOnDocuments = true;

  bool _loaded = false;
  bool _saving = false;
  String? _error;
  CompanySettings? _original;

  void _populate(CompanySettings s) {
    _original = s;
    if (_loaded) return;
    _shopName.text = s.shopName;
    _gstin.text = s.gstin;
    _state.text = s.state;
    _address.text = s.address ?? '';
    _contact.text = s.contactNumber ?? '';
    _showLogoOnDocuments = s.showLogoOnDocuments;
    _loaded = true;
  }

  Future<void> _save() async {
    if (_shopName.text.trim().isEmpty || _gstin.text.trim().isEmpty || _state.text.trim().isEmpty) {
      setState(() => _error = 'Shop name, GSTIN, and state are required.');
      return;
    }

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
        'shopName': _shopName.text.trim(),
        'gstin': _gstin.text.trim(),
        'state': _state.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'contactNumber': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        'bankName': o?.bankName,
        'bankAccountNumber': o?.bankAccountNumber,
        'bankIfscCode': o?.bankIfscCode,
        'bankBranch': o?.bankBranch,
        'upiId': o?.upiId,
        'showLogoOnDocuments': _showLogoOnDocuments,
        'showSignatureBlock': o?.showSignatureBlock ?? false,
        'quotationTermsAndConditions': o?.quotationTermsAndConditions,
        'quotationFooterNote': o?.quotationFooterNote,
        'proformaTermsAndConditions': o?.proformaTermsAndConditions,
        'proformaFooterNote': o?.proformaFooterNote,
        'salesInvoiceTermsAndConditions': o?.salesInvoiceTermsAndConditions,
        'salesInvoiceFooterNote': o?.salesInvoiceFooterNote,
        'purchaseOrderTermsAndConditions': o?.purchaseOrderTermsAndConditions,
        'purchaseOrderFooterNote': o?.purchaseOrderFooterNote,
        'whatsappQuotationMessageTemplate': o?.whatsappQuotationMessageTemplate,
        'whatsappProformaMessageTemplate': o?.whatsappProformaMessageTemplate,
        'whatsappSalesInvoiceMessageTemplate': o?.whatsappSalesInvoiceMessageTemplate,
        'whatsappDepositReceiptMessageTemplate': o?.whatsappDepositReceiptMessageTemplate,
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

  Future<void> _pickLogo() async {
    const typeGroup = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final api = ref.read(apiClientProvider);
    final result = await api.put<void>(
      '/api/company-settings/logo',
      (_) {},
      body: {'logoBase64': base64Encode(bytes)},
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(companySettingsProvider);
        ref.invalidate(companyLogoBytesProvider);
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(companySettingsProvider);
    final logoAsync = ref.watch(companyLogoBytesProvider);

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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeader(title: 'Shop Details', subtitle: 'Your shop\'s identity, shown on generated PDFs and in the app'),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        logoAsync.when(
                          data: (bytes) => CircleAvatar(
                            radius: 40,
                            backgroundImage: bytes == null ? null : MemoryImage(Uint8List.fromList(bytes)),
                            child: bytes == null ? const Icon(Icons.storefront, size: 36) : null,
                          ),
                          loading: () => const CircleAvatar(radius: 40, child: CircularProgressIndicator()),
                          error: (_, _) => const CircleAvatar(radius: 40, child: Icon(Icons.storefront, size: 36)),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.upload), label: const Text('Upload Logo')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Shop Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppPalette.textSecondary)),
                  const SizedBox(height: 12),
                  TextField(controller: _shopName, decoration: const InputDecoration(labelText: 'Shop Name')),
                  const SizedBox(height: 8),
                  TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
                  const SizedBox(height: 8),
                  TextField(controller: _state, decoration: const InputDecoration(labelText: 'State')),
                  const SizedBox(height: 8),
                  TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contact,
                    decoration: const InputDecoration(labelText: 'Contact Number'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show shop logo on PDFs'),
                    value: _showLogoOnDocuments,
                    onChanged: (v) => setState(() => _showLogoOnDocuments = v),
                  ),
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SkeletonBox(width: 80, height: 80, borderRadius: BorderRadius.all(Radius.circular(40))),
                  const SizedBox(height: 24),
                  for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonBox(height: 48)),
                ],
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
