import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_header.dart';
import 'notification_model.dart';
import 'notifications_provider.dart';

/// The in-app notification inbox (Low Stock / Purchase Due / Purchase Overdue / Sales Payment Due-
/// Overdue / Customer Outstanding events) - a shared shop-wide feed, not a personal one, matching
/// NotificationEvent.ReadAt's shop-wide read-tracking model on the backend.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final filter = NotificationsFilter(unreadOnly: _unreadOnly);
    final itemsAsync = ref.watch(notificationsProvider(filter));

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(title: const Text('Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Notifications',
              subtitle: 'Low stock, purchase and payment alerts for this shop.',
              actions: [
                FilterChip(
                  label: const Text('Unread only'),
                  selected: _unreadOnly,
                  onSelected: (v) => setState(() => _unreadOnly = v),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await ref.read(notificationsActionsProvider).markAllRead();
                    if (!ok || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked read.')));
                  },
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark all read'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  if (items == null) {
                    return const EmptyState(icon: Icons.error_outline, title: 'Could not load notifications.');
                  }
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.notifications_none,
                      title: _unreadOnly ? 'No unread notifications.' : 'No notifications yet.',
                    );
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _NotificationTile(item: items[i]),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const EmptyState(icon: Icons.error_outline, title: 'Could not load notifications.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationItem item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = NotificationDisplay.of(item);
    final unread = !item.isRead;

    return InkWell(
      onTap: unread ? () => ref.read(notificationsActionsProvider).markRead(item.id) : null,
      child: Container(
        color: unread ? AppPalette.primaryLight.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Icon(Icons.circle, size: 8, color: unread ? AppPalette.primary : Colors.transparent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(display.body, style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary)),
                  const SizedBox(height: 4),
                  Text(_relativeTime(item.createdAt), style: const TextStyle(fontSize: 11, color: AppPalette.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }
}
