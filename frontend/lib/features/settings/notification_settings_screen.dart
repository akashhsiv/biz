import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/shortcuts/app_key_sets.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'notification_settings_model.dart';
import 'notification_settings_provider.dart';

/// Per-shop notification channel matrix - which events (Low Stock/Purchase Due/Purchase Overdue/
/// Customer Outstanding) fire on which channels (WhatsApp/Mobile). Mobile push delivery itself is
/// not implemented yet on the backend, but the setting is real at the data level, so the toggle is
/// still exposed here. Mirrors CompanySettingsScreen's read/edit/save UX.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  NotificationSettings? _current;
  final _dueSoonDaysController = TextEditingController();

  void _populate(NotificationSettings s) {
    if (_loaded) return;
    _current = s;
    _dueSoonDaysController.text = s.dueSoonDays.toString();
    _loaded = true;
  }

  @override
  void dispose() {
    _dueSoonDaysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _current;
    if (current == null) return;

    final dueSoonDays = int.tryParse(_dueSoonDaysController.text.trim());
    if (dueSoonDays == null || dueSoonDays <= 0 || dueSoonDays > 90) {
      setState(() => _error = 'Days before due date must be between 1 and 90.');
      return;
    }
    _current = current.copyWith(dueSoonDays: dueSoonDays);
    final toSave = _current!;

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.put<void>(
      '/api/notification-settings',
      (_) {},
      body: toSave.toJson(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(notificationSettingsProvider);
        AppToast.success('Saved.');
      case ApiFailure(message: final msg):
        setState(() => _error = msg);
      case ApiNetworkError(message: final msg):
        setState(() => _error = 'Could not reach the Host: $msg');
    }
  }

  Widget _headerCell(String text) => Expanded(
        child: Center(
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      );

  Widget _row(String label, bool whatsapp, bool mobile, bool canManage, {
    required ValueChanged<bool> onWhatsapp,
    required ValueChanged<bool> onMobile,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            child: Center(
              child: Checkbox(
                value: whatsapp,
                onChanged: canManage ? (v) => onWhatsapp(v ?? false) : null,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Checkbox(
                value: mobile,
                onChanged: canManage ? (v) => onMobile(v ?? false) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final canManage = ref.watch(authControllerProvider).has(Permissions.notificationsSettingsManage);

    return CallbackShortcuts(
      bindings: {
        if (!_saving && canManage) AppKeys.ctrlS: _save,
      },
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: settingsAsync.when(
          data: (settings) {
            if (settings == null) return const Center(child: Text('Could not load notification settings.'));
            _populate(settings);
            final current = _current!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(
                      title: 'Notification Settings',
                      subtitle: 'Choose which channels each event alerts you on',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _dueSoonDaysController,
                      enabled: canManage,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Alert this many days before due date',
                        helperText: 'Applies to Purchase Due / Sales Payment Due alerts. 1-90 days.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(flex: 2, child: SizedBox()),
                        _headerCell('WhatsApp'),
                        _headerCell('Mobile'),
                      ],
                    ),
                    const Divider(height: 16),
                    _row(
                      'Low Stock',
                      current.lowStockWhatsapp,
                      current.lowStockMobile,
                      canManage,
                      onWhatsapp: (v) => setState(() => _current = current.copyWith(lowStockWhatsapp: v)),
                      onMobile: (v) => setState(() => _current = current.copyWith(lowStockMobile: v)),
                    ),
                    _row(
                      'Purchase Due',
                      current.purchaseDueWhatsapp,
                      current.purchaseDueMobile,
                      canManage,
                      onWhatsapp: (v) => setState(() => _current = current.copyWith(purchaseDueWhatsapp: v)),
                      onMobile: (v) => setState(() => _current = current.copyWith(purchaseDueMobile: v)),
                    ),
                    _row(
                      'Purchase Overdue',
                      current.purchaseOverdueWhatsapp,
                      current.purchaseOverdueMobile,
                      canManage,
                      onWhatsapp: (v) => setState(() => _current = current.copyWith(purchaseOverdueWhatsapp: v)),
                      onMobile: (v) => setState(() => _current = current.copyWith(purchaseOverdueMobile: v)),
                    ),
                    _row(
                      'Customer Outstanding',
                      current.customerOutstandingWhatsapp,
                      current.customerOutstandingMobile,
                      canManage,
                      onWhatsapp: (v) => setState(() => _current = current.copyWith(customerOutstandingWhatsapp: v)),
                      onMobile: (v) => setState(() => _current = current.copyWith(customerOutstandingMobile: v)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (canManage) ...[
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
