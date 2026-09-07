import 'dart:convert';

/// Mirrors NotificationEventDto from Erp.Api.Controllers.NotificationsController - EventType/Status
/// arrive as their C# enum names (e.g. "LowStock"), not integers, so they're kept as raw strings
/// here rather than parsed into a Dart enum: a value this client doesn't recognise yet (a new event
/// type added server-side) still round-trips and displays via the generic fallback in
/// [NotificationDisplay.of] instead of throwing.
class NotificationItem {
  final String id;
  final String eventType;
  final String payloadJson;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  NotificationItem({
    required this.id,
    required this.eventType,
    required this.payloadJson,
    required this.status,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] as String,
        eventType: json['eventType'] as String,
        payloadJson: json['payloadJson'] as String? ?? '{}',
        status: json['status'] as String? ?? 'Pending',
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: json['readAt'] == null ? null : DateTime.parse(json['readAt'] as String),
      );
}

/// Human-readable title/body derived from (eventType, payloadJson) for display in the inbox.
/// PayloadJson is a free-form server-side blob (see NotificationEvent.PayloadJson's doc comment) -
/// decoding is entirely defensive: a missing field or an unparsable/non-object payload falls back to
/// a generic label instead of crashing the list.
class NotificationDisplay {
  final String title;
  final String body;

  const NotificationDisplay(this.title, this.body);

  factory NotificationDisplay.of(NotificationItem item) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(item.payloadJson);
      payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      payload = <String, dynamic>{};
    }

    String field(String key, [String fallback = '']) {
      final v = payload[key];
      return v == null ? fallback : v.toString();
    }

    switch (item.eventType) {
      case 'LowStock':
        final name = field('itemName', 'An item');
        final current = field('currentStock');
        final min = field('minimumStock');
        return NotificationDisplay(
          'Low Stock: $name',
          current.isEmpty || min.isEmpty ? 'Stock has fallen below the minimum level.' : 'Current stock $current is below the minimum of $min.',
        );
      case 'PurchaseDue':
        final vendor = field('vendorName', 'A vendor');
        final due = field('dueDate');
        return NotificationDisplay('Purchase Due: $vendor', due.isEmpty ? 'A purchase order payment is due soon.' : 'Payment is due on $due.');
      case 'PurchaseOverdue':
        final vendor = field('vendorName', 'A vendor');
        final outstanding = field('outstanding');
        return NotificationDisplay(
          'Purchase Overdue: $vendor',
          outstanding.isEmpty ? 'A purchase order payment is overdue.' : 'Outstanding amount: $outstanding.',
        );
      case 'SalesPaymentDue':
        final customer = field('customerName', 'A customer');
        final due = field('dueDate');
        return NotificationDisplay('Payment Due: $customer', due.isEmpty ? 'A sales invoice payment is due soon.' : 'Payment is due on $due.');
      case 'SalesPaymentOverdue':
        final customer = field('customerName', 'A customer');
        final outstanding = field('outstanding');
        return NotificationDisplay(
          'Payment Overdue: $customer',
          outstanding.isEmpty ? 'A sales invoice payment is overdue.' : 'Outstanding amount: $outstanding.',
        );
      case 'CustomerOutstanding':
        final customer = field('customerName', 'A customer');
        final outstanding = field('outstanding');
        return NotificationDisplay(
          'Customer Outstanding: $customer',
          outstanding.isEmpty ? 'A customer has an outstanding balance.' : 'Outstanding balance: $outstanding.',
        );
      default:
        return NotificationDisplay(item.eventType, 'You have a new notification.');
    }
  }
}
