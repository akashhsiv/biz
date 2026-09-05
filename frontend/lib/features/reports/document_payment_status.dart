/// Mirrors the backend's `DocumentPaymentStatus` enum (Erp.Domain.Common.Enums) — member order is
/// critical since it is serialized/deserialized as an int, same convention as every other enum in
/// this codebase (e.g. `PurchaseOrderStatus`, `QuotationStatus`).
enum DocumentPaymentStatus { paid, partiallyPaid, credit, overdue }

extension DocumentPaymentStatusLabel on DocumentPaymentStatus {
  String get label => switch (this) {
        DocumentPaymentStatus.paid => 'Paid',
        DocumentPaymentStatus.partiallyPaid => 'Partially Paid',
        DocumentPaymentStatus.credit => 'Credit',
        DocumentPaymentStatus.overdue => 'Overdue',
      };
}
