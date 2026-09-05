# Local Host–Slave ERP — Phase 1: Architecture & Requirements

Status: **Phase 1 confirmed. Phase 2 (database) complete. Phase 3 (backend) complete and smoke-tested**, including PDF generation, automatic/manual backups, reports, and a WhatsApp outbox (bridge service scaffolded, not device-paired) — see `backend/` and `whatsapp-service/`. Phase 4 (Flutter Slave app) has not started.

## Decisions Confirmed So Far

| # | Topic | Decision |
|---|---|---|
| A1 | Backup schedule | Automatic daily backup to a configurable path (see §11, updated). |
| A2 | WhatsApp/Baileys ban risk | Accepted as optional/best-effort; proceed with Baileys as designed. |
| A3 | Scale target | Design and test for **up to 10 concurrent Slave PCs**, under load, with explicit handling of the concurrency edge cases in §3 (row locking, unique constraints, isolation levels) — see §13 (new). |
| A4 | Timestamps | Confirmed: all audit/stock/financial timestamps are stamped by the Host server, never the Slave's local clock. |
| A5 | Installer | The Host installer must be all-in-one — it provisions PostgreSQL itself (not a manual prerequisite). See §8, updated. |

All 15 open questions from §13 are now resolved — see the updated §13 below. Phase 2 (DB schema) can proceed.

---

## 1. Architecture Overview

```
                              COMPANY LAN
                                   │
                     ┌─────────────▼─────────────┐
                     │          HOST PC           │
                     │  ASP.NET Core Web API      │
                     │  Application Services      │
                     │  Domain / Business Rules   │
                     │  EF Core                   │
                     │  PostgreSQL (local only)   │
                     │  Audit Log Writer          │
                     │  HTML → PDF Service        │
                     │  WhatsApp Outbox + Baileys │
                     │  Backup Job                │
                     │  Windows Service host      │
                     └─────────────┬──────────────┘
                                   │ HTTP/REST (LAN, port 5000)
              ┌────────────────────┼────────────────────┐
              │                    │                     │
        ┌─────▼─────┐        ┌─────▼─────┐         ┌─────▼─────┐
        │  Slave 1   │        │  Slave 2   │         │  Slave 3   │
        │  Flutter   │        │  Flutter   │         │  Flutter   │
        │  Desktop   │        │  Desktop   │         │  Desktop   │
        └────────────┘        └────────────┘         └────────────┘
```

Non-negotiable rules carried through the whole design:

- Slaves **never** talk to PostgreSQL directly. Only the Host process does.
- The Host is the **only** place business rules are evaluated (totals, deposit sufficiency, stock deduction, conversions). Flutter renders and requests; it never decides.
- Everything works with the LAN cable unplugged from the wall (i.e., no internet), **except** WhatsApp send/receive.
- A WhatsApp failure can never roll back or block a committed ERP transaction.
- Nothing financial or stock-related is ever hard-deleted or silently overwritten — only appended, reversed, or adjusted, with an audit trail.

---

## 2. Modules & Dependencies

```
Auth & Users ──┬─> Roles & Permissions ──> (gates everything below)
               │
Customers ─────┼─> Customer Deposits (Amount In) ──> Deposit Allocation
               │
Items ─────────┼─> Stock ──> Stock Movements
               │
Quotations ────┴─> Proforma Invoices ──> Sales Invoices ──> Sales Returns
               │
Purchase Orders ──> Purchase Receipts ──> Amount Out ──> Shop Balance
               │
Reports  <──── (reads from all ledgers/movements, read-only)
Audit Log <──── (written by every module, read by Shop Admin)
PDF Service <── (reads finalized documents from any module)
WhatsApp <────── (subscribes to committed events; never blocks them)
Backup <──────── (whole-database, independent of all modules)
```

Module list:

1. Authentication & Session
2. Users, Roles, Permissions
3. Customers (GST-registered / unregistered)
4. Items (stock / non-stock)
5. Customer Deposits (Amount In) & Allocation
6. Quotations
7. Proforma Invoices
8. Sales Invoices
9. Stock & Stock Movements
10. Sales Returns & Return Policies
11. Purchase Orders
12. Purchase Receipts & Purchase Payments
13. Amount Out & Shop Balance (financial ledger)
14. Reports
15. Audit Log
16. PDF/Document Generation
17. WhatsApp Integration
18. Host Infrastructure (health, dashboard, backup, connection info)

---

## 3. Database Design (PostgreSQL, EF Core migrations)

Conventions used throughout: every table has `id UUID PK`, `created_by`, `created_at`, `updated_by`, `updated_at`; monetary columns are `numeric(18,2)`; quantities are `numeric(18,3)`; nothing that appears on a financial or stock document is ever physically deleted — an `is_active` / status column is used instead.

### 3.1 Identity & Access

**users**
- Purpose: login accounts for Shop Admin / Sales / Purchase staff.
- PK `id`. Fields: `username`, `password_hash`, `full_name`, `is_active`, `last_login_at`.
- FK: `role_id -> roles.id`.
- Index: unique on `username`.
- Audit: login/logout, user created/deactivated, role changed.

**roles**
- Purpose: `Shop Admin`, `Sales Team`, `Purchase Team` (extensible).
- PK `id`. Fields: `name`, `description`, `is_system_role`.

**permissions**
- Purpose: catalog of fine-grained permission keys (e.g. `sales.invoice.create`, `finance.amount_out.create`).
- PK `id`. Fields: `key`, `description`, `module`.

**role_permissions**
- Purpose: many-to-many role↔permission grants.
- PK (`role_id`,`permission_id`). FKs to `roles`, `permissions`.

**refresh_tokens** (or session table, if token auth is chosen — see Q&A)
- Purpose: server-side session/refresh-token tracking so tokens can be revoked.
- FK `user_id -> users.id`. Index on `token_hash`, `expires_at`.

### 3.2 Customers

**customers**
- Purpose: single customer master for both GST-registered and unregistered customers.
- PK `id`. Fields: `customer_code`, `name`, `customer_type` (`registered`/`unregistered`), `gst_number` (nullable), `contact_number`, `email`, `billing_address`, `shipping_address`, `is_active`.
- Index: unique `customer_code`; index on `gst_number`, `name` (search).
- No hard delete — `is_active=false` once any transaction exists.
- Audit: create/update, GST field changes flagged specially (compliance-sensitive).

### 3.3 Items & Stock

**item_categories**
- Purpose: grouping for reporting and return-policy scoping.
- PK `id`. Fields: `name`, `is_active`.

**items**
- Purpose: item master (stock and non-stock).
- PK `id`. Fields: `sku`, `name`, `category_id (FK)`, `unit`, `item_kind` (`stock`/`non_stock`), `purchase_price`, `selling_price`, `tax_rate`/`tax_group_id`, `is_active`.
- Index: unique `sku`.
- No hard delete — deactivate.

**stock_balances**
- Purpose: current on-hand quantity per stock item (cached, reconciled from movements).
- PK `item_id (FK, 1:1 with items where item_kind=stock)`. Fields: `quantity_on_hand`, `last_movement_id`, `updated_at`.
- This is a derived/cache table; `stock_movements` is the source of truth.

**stock_movements**
- Purpose: append-only ledger of every stock change.
- PK `id`. Fields: `item_id (FK)`, `movement_type` (`opening`,`purchase`,`sale`,`return`,`adjustment`,`reversal`), `quantity_delta`, `quantity_before`, `quantity_after`, `reference_type` (`sales_invoice`,`proforma`,`purchase_receipt`,`sales_return`,`manual_adjustment`), `reference_id`, `reason` (nullable, required for manual adjustment/reversal).
- Index: `(item_id, created_at)`, `(reference_type, reference_id)`.
- Never updated or deleted after insert.

### 3.4 Financial Ledger (shared spine for Amount In / Amount Out / Shop Balance)

**financial_transactions**
- Purpose: single append-only ledger row for every rupee that moves — this is what "shop balance" and "customer deposit balance" are computed from.
- PK `id`. Fields: `transaction_type` (`amount_in`,`amount_out`,`deposit_allocation`,`deposit_reversal`,`purchase_payment`,`refund`,`adjustment`), `direction` (`credit`/`debit`), `amount`, `customer_id (FK, nullable)`, `supplier_id (FK, nullable)`, `reference_type`, `reference_id`, `reason` (nullable), `is_reversal_of (FK to self, nullable)`.
- Index: `(customer_id, created_at)`, `(transaction_type, created_at)`.
- Append-only. A correction is a new row referencing the original via `is_reversal_of`.

**customer_deposits**
- Purpose: one row per deposit event made by a customer (Amount In, customer-specific).
- PK `id`. FK `customer_id`, `financial_transaction_id (FK)`. Fields: `amount`, `payment_method`, `received_by`, `notes`.
- Index: `(customer_id, created_at)`.

**deposit_allocations**
- Purpose: traceable link between a deposit (or pool of deposits) and the document it was applied to.
- PK `id`. FK `customer_id`, `document_type` (`proforma`,`sales_invoice`), `document_id`, `amount_allocated`, `status` (`active`,`reversed`), `reversed_at`, `reversed_reason`.
- Index: `(customer_id)`, `(document_type, document_id)`.
- Available deposit for a customer = SUM(customer_deposits.amount) − SUM(active deposit_allocations.amount_allocated) ± authorized adjustments/reversals recorded as `financial_transactions`.

**shop_balance_snapshot** (optional, cache only)
- Purpose: fast-read cached balance, always reconcilable by re-summing `financial_transactions`.
- Single row (or per-day snapshot rows for reporting), `balance`, `as_of`.

### 3.5 Sales Chain

**quotations**
- PK `id`. Fields: `quotation_number` (unique, sequential), `customer_id (FK)`, `status` (`draft`,`issued`,`converted`,`cancelled`,`expired`), `subtotal`, `discount_total`, `tax_total`, `grand_total`, `sales_person_id (FK users)`.
- Index: unique `quotation_number`; `(customer_id, created_at)`.

**quotation_lines**
- PK `id`. FK `quotation_id`. Fields: `item_id (FK, nullable for free-text non-stock line)`, `description`, `quantity`, `rate`, `discount`, `tax_rate`, `line_total`.

**proforma_invoices**
- PK `id`. Fields: `proforma_number` (unique), `quotation_id (FK)`, `customer_id (FK)`, `status` (`open`,`fully_funded`,`converted`,`cancelled`), `grand_total`, `allocated_total`, `outstanding_total`.
- Index: unique `proforma_number`; `(customer_id)`.
- Lines mirror quotation lines at the time of conversion (**proforma_lines**, snapshot copy — quotations may later be edited/archived without altering an issued proforma).

**proforma_lines**
- Snapshot of items/qty/rate/tax at conversion time. Same shape as `quotation_lines` plus `proforma_id (FK)`.

**sales_invoices**
- PK `id`. Fields: `invoice_number` (unique, sequential, statutory), `source_type` (`quotation_direct`,`proforma_conversion`), `source_id`, `customer_id (FK)`, `status` (`active`,`cancelled`), `grand_total`, `deposit_allocated_total`.
- Index: unique `invoice_number`; `(customer_id, created_at)`.

**sales_invoice_lines**
- Snapshot lines, same shape, plus `sales_invoice_id (FK)` and `item_id`.

**sales_returns**
- PK `id`. Fields: `return_number` (unique), `sales_invoice_id (FK)`, `customer_id (FK)`, `status` (`requested`,`approved`,`rejected`,`completed`,`cancelled`), `reason`, `approved_by`, `total_refund_amount`.

**sales_return_lines**
- FK `sales_return_id`, `sales_invoice_line_id`, `quantity_returned`, `refund_amount`, `restock` (bool — whether it creates a stock_movement `return`).

**return_policies**
- PK `id`. Fields: `name`, `category_id (FK, nullable = applies to all)`, `return_window_days`, `restocking_fee_percent`, `is_active`.

### 3.6 Purchase Chain

**suppliers**
- PK `id`. Fields: `name`, `gst_number`, `contact_number`, `address`, `is_active`.

**purchase_orders**
- PK `id`. Fields: `po_number` (unique), `supplier_id (FK)`, `status` (`draft`,`submitted`,`processing`,`partially_completed`,`completed`,`cancelled`), `payment_status` (`processing`,`completed`,`cancelled`), `grand_total`, `created_by`.

**purchase_order_lines**
- FK `purchase_order_id`, `item_id`, `quantity_ordered`, `quantity_received`, `rate`, `tax_rate`, `line_total`.

**purchase_receipts**
- PK `id`. Fields: `receipt_number`, `purchase_order_id (FK)`, `received_by`, `received_at`.

**purchase_receipt_lines**
- FK `purchase_receipt_id`, `po_line_id`, `quantity_received` — each insert creates a `stock_movements` row (`movement_type = purchase`).

**purchase_payments**
- PK `id`. FK `purchase_order_id`, `financial_transaction_id (FK, nullable until completed)`. Fields: `amount`, `status` (`processing`,`completed`,`cancelled`), `payment_method`.

### 3.7 Audit

**audit_logs**
- PK `id`. Fields: `user_id (FK)`, `role_at_time`, `action` (enum/string, e.g. `quotation.converted`), `entity_type`, `entity_id`, `old_value` (jsonb, nullable), `new_value` (jsonb, nullable), `reason` (nullable), `created_at`.
- Index: `(entity_type, entity_id)`, `(user_id, created_at)`, `(action, created_at)`.
- Append-only, no update/delete path exposed anywhere.

### 3.8 WhatsApp

**whatsapp_outbox**
- PK `id`. Fields: `message_type` (`quotation`,`proforma`,`sales_invoice`,`deposit_receipt`,`custom`), `reference_type`, `reference_id`, `recipient_number`, `payload` (jsonb), `status` (`queued`,`sending`,`sent`,`failed`), `attempts`, `last_error`, `sent_at`.
- Consumed by a background worker; never part of the transaction that creates the referenced document.

### 3.9 Idempotency

**idempotency_keys**
- PK `id` = client-supplied key (UUID). Fields: `endpoint`, `request_hash`, `response_status`, `response_body` (jsonb), `created_at`.
- Used on all critical POST endpoints (conversions, payments, deposits) — a repeated key with the same request returns the stored response instead of re-executing.

### 3.10 Backups

**backup_history**
- PK `id`. Fields: `file_path`, `size_bytes`, `backup_type` (`automatic`,`manual`), `status` (`success`,`failed`), `triggered_by`.

---

## 4. Text ERD (key relationships)

```
users ─┬─< role_permissions >─ permissions
       └─ roles

customers ─┬─< customer_deposits >─ financial_transactions
           ├─< deposit_allocations
           ├─< quotations ─< quotation_lines
           ├─< proforma_invoices ─< proforma_lines
           ├─< sales_invoices ─< sales_invoice_lines
           └─< sales_returns ─< sales_return_lines

quotations ─(1:1 optional)─> proforma_invoices ─(1:1 optional)─> sales_invoices
sales_invoices ─< sales_returns

items ─┬─< quotation_lines / proforma_lines / sales_invoice_lines / purchase_order_lines
       ├─< stock_movements
       └─ stock_balances (1:1)

suppliers ─< purchase_orders ─< purchase_order_lines
purchase_orders ─< purchase_receipts ─< purchase_receipt_lines
purchase_orders ─< purchase_payments ─> financial_transactions

financial_transactions ── (referenced by) customer_deposits, deposit_allocations,
                            purchase_payments, amount_out entries, refunds, adjustments

audit_logs ── (references) any entity_type/entity_id above, non-FK by design
whatsapp_outbox ── (references) any document above, non-FK by design
```

---

## 5. Role / Permission Matrix

| Capability | Shop Admin | Sales Team | Purchase Team |
|---|---|---|---|
| Customers (create/edit) | ✅ | ✅ | ❌ (view only) |
| GST detail edit | ✅ | ✅ | ❌ |
| Item master (create/edit/deactivate) | ✅ | ❌ (view only) | ❌ (view only) |
| Quotations | ✅ | ✅ | ❌ |
| Proforma invoices | ✅ | ✅ | ❌ |
| Sales invoices | ✅ | ✅ | ❌ |
| Sales returns (request) | ✅ | ✅ | ❌ |
| Sales returns (approve) | ✅ | ❌ | ❌ |
| Return policy management | ✅ | ❌ | ❌ |
| Customer deposits (Amount In) | ✅ | ✅ (record only) | ❌ |
| Purchase orders | ✅ | ❌ | ✅ |
| Purchase receipts | ✅ | ❌ | ✅ |
| Purchase payments | ✅ | ❌ | ✅ (initiate) / ✅ Admin (approve) |
| Amount Out | ✅ | ❌ | ❌ |
| Shop balance view | ✅ | ❌ | ❌ |
| Stock view | ✅ | ✅ (read-only) | ✅ |
| Stock adjustments (manual) | ✅ | ❌ | ❌ |
| Reports — sales | ✅ | ✅ (own/team) | ❌ |
| Reports — purchase | ✅ | ❌ | ✅ (own/team) |
| Reports — finance | ✅ | ❌ | ❌ |
| Reports — full/all | ✅ | ❌ | ❌ |
| User management | ✅ | ❌ | ❌ |
| Role/permission management | ✅ | ❌ | ❌ |
| Audit log view | ✅ | ❌ | ❌ |
| WhatsApp management | ✅ | ❌ | ❌ |
| Financial adjustments | ✅ | ❌ | ❌ |

This is implemented as `role_permissions` rows against granular `permissions.key` entries, not hardcoded role checks — so it stays adjustable without redeploying.

---

## 6. Business Flows

**Customer creation** — Sales/Admin submits customer → backend validates GST number format if `customer_type=registered` → row inserted → audit `customer.created`.

**Customer deposit (Amount In)** — Admin/Sales records a deposit → backend creates `customer_deposits` row + matching `financial_transactions` (credit) row in one transaction → audit `amount_in.created`.

**Quotation** — Sales creates quotation with stock/non-stock lines → backend recalculates every line total, discount, tax, grand total server-side (client totals are display-only) → saved as `draft`/`issued`.

**Quotation → conversion decision** — `POST /api/quotations/{id}/convert`:
1. Backend loads quotation + recomputes grand total.
2. Computes customer's available deposit (`SUM(deposits) − SUM(active allocations)`).
3. If `available_deposit >= grand_total` → creates **Sales Invoice**, allocates deposit for the full amount, reduces stock, writes stock movements, writes audit log — all in one DB transaction.
4. Else → creates **Proforma Invoice** for the full grand total, allocates whatever deposit is available, reduces stock immediately (see below), writes audit log — one DB transaction.
5. Quotation status set to `converted`.

**Additional deposit against an open proforma** — Admin/Sales records another deposit → deposit is available; a separate explicit allocation step (`POST /api/proformas/{id}/allocate-deposit` or reuse of `.../convert`) applies it to the proforma's outstanding balance.

**Proforma → Sales Invoice ("Clear Dues")** — `POST /api/proformas/{id}/convert`: backend checks `outstanding_total == 0`; if so, creates Sales Invoice from the proforma's snapshot lines, marks proforma `converted`; stock is **not** moved again (it already moved at proforma creation) — the sales invoice is essentially a re-classification of a fully-paid proforma. Audit `proforma.converted`.

**Stock deduction & proforma reversal** — Stock is deducted at the moment a quotation becomes either a Sales Invoice or a Proforma (per your spec's explicit statement in §23–24). If a Proforma is later cancelled, a **reversal** `stock_movements` row restores the quantity (original row is untouched).

**Purchase Order → Receipt → Payment → Completion**:
1. Purchase Team creates PO (`draft` → `submitted`).
2. Supplier delivers; Purchase Team records a Purchase Receipt against PO lines → each line creates a `stock_movements` row (`purchase`) and updates `quantity_received` → PO status advances to `processing`/`partially_completed`/`completed` based on received vs ordered quantities.
3. Purchase Payment is tracked independently (`payment_status`); when payment is marked `completed`, backend writes an **Amount Out** `financial_transactions` row.
4. PO's own `status=completed` is driven by receipt-of-goods completeness, not by payment — the two are independent axes per your §26.

**Amount Out (general)** — Admin records a non-PO expense → `financial_transactions` debit row → audit `amount_out.created`.

**Sales Return** — Sales/Admin requests a return referencing a sales invoice line → Admin approves → on `completed`: creates `stock_movements` (`return`, if `restock=true`) and a `financial_transactions` refund/adjustment row → original sales invoice is never edited.

**Financial adjustment** — Admin-only, always a new `financial_transactions` row with `reason` required, never an edit of history.

**WhatsApp** — Any of the above document-creation events, after their own DB transaction commits, insert a row into `whatsapp_outbox`. A background worker (independent process/thread) attempts delivery via the Baileys service and updates `status`/`attempts`. Nothing about this worker's success or failure touches the originating transaction.

---

## 7. REST API (representative — finalized alongside DB schema in Phase 2)

```
GET    /api/health

POST   /api/auth/login
POST   /api/auth/logout
POST   /api/auth/refresh

GET    /api/users            POST /api/users            PUT /api/users/{id}
GET    /api/roles            POST /api/roles            PUT /api/roles/{id}/permissions

GET    /api/customers        POST /api/customers        PUT /api/customers/{id}
GET    /api/items            POST /api/items            PUT /api/items/{id}

POST   /api/customer-deposits
GET    /api/customer-deposits?customerId=
GET    /api/customers/{id}/deposit-summary

GET    /api/quotations       POST /api/quotations       PUT /api/quotations/{id}
POST   /api/quotations/{id}/convert         (Idempotency-Key required)

GET    /api/proformas/{id}
POST   /api/proformas/{id}/allocate-deposit (Idempotency-Key required)
POST   /api/proformas/{id}/convert          (Idempotency-Key required)
POST   /api/proformas/{id}/cancel

GET    /api/sales-invoices/{id}
POST   /api/sales-invoices/{id}/cancel
GET    /api/sales-invoices/{id}/pdf

POST   /api/sales-returns
POST   /api/sales-returns/{id}/approve
POST   /api/sales-returns/{id}/complete
GET    /api/return-policies

GET    /api/suppliers        POST /api/suppliers
GET    /api/purchase-orders  POST /api/purchase-orders  PUT /api/purchase-orders/{id}
POST   /api/purchase-orders/{id}/receipts
POST   /api/purchase-orders/{id}/payments
POST   /api/purchase-orders/{id}/payments/{paymentId}/complete

POST   /api/amount-out
GET    /api/finance/shop-balance
GET    /api/finance/transactions

GET    /api/stock
GET    /api/stock/movements?itemId=
POST   /api/stock/adjustments

GET    /api/reports/sales/...
GET    /api/reports/purchase/...
GET    /api/reports/stock/...
GET    /api/reports/finance/...

GET    /api/audit-logs

POST   /api/whatsapp/send
GET    /api/whatsapp/status

GET    /api/host/status       (IP, port, connected-slave count, backup info)
```

All state-changing endpoints require a bearer token; conversion/payment/deposit endpoints additionally require an `Idempotency-Key` header, keyed off `idempotency_keys`.

---

## 8. Host / Slave Connectivity

- Host binds ASP.NET Core to `http://0.0.0.0:5000` (LAN-reachable), not just `localhost`.
- Host displays IP + port + full URL + connected-slave count on a dashboard screen; "Copy URL" button.
- Recommend a **DHCP reservation** for the Host's MAC address (simplest for a shop network) over manually configuring a static IP; either works, DHCP reservation avoids IP-conflict mistakes. *(Confirm choice — see Q&A.)*
- Slave startup sequence: load saved Host URL from local settings → `GET /api/health` → on success go to Login; on failure show "Connection Failed" with Retry / Change Host, and do **not** proceed to any ERP screen.
- Mid-session disconnection: Flutter's API client distinguishes three outcomes for any critical POST — HTTP success (confirmed success), HTTP error response (confirmed failure), and network/timeout (unknown) — only the first is treated as success; "unknown" surfaces a distinct "couldn't confirm, don't retry blindly, check before resubmitting" state, and retries of the *same* logical operation reuse the same Idempotency-Key so a resend is safe.
- Windows Firewall: allow inbound on the API port from the LAN profile only; PostgreSQL's port is not opened on the firewall at all (bind it to `localhost` only on the Host).
- `/api/health` returns only `{status, databaseReachable}` — no connection strings, versions, or internals.
- V1 requires manually entering the Host URL on each Slave; LAN auto-discovery (e.g. mDNS/UDP broadcast) is a documented future phase, not a Phase-1 dependency.
- **Host installer is all-in-one**: a single setup package bundles a silent/scripted PostgreSQL install (bundled installer or embedded binaries), creates the ERP database and role, applies EF Core migrations, registers the ASP.NET Core app as a Windows Service, opens the firewall port, and launches the Host dashboard at the end — the shop owner should never need to run `dotnet run`, install PostgreSQL separately, or touch a config file by hand. Slave installers remain Flutter-only, with just a Host-URL field on first run.

---

## 9. PDF Architecture

```
Flutter  →  GET /api/{document}/{id}/pdf
                    ↓
        Document Service (Application layer)
                    ↓
        Load document + lines + customer + company info from DB
                    ↓
        Render HTML template (Razor or Scriban template, kept out of controllers)
                    ↓
        HTML → PDF engine (candidates evaluated in Phase 3: e.g. a
        headless-Chromium-based renderer or a managed .NET PDF library —
        final pick depends on licensing for commercial/offline use)
                    ↓
        Return application/pdf stream
```

Templates live under `Infrastructure/Documents/Templates/` as plain HTML+CSS, one per document type (quotation, proforma, sales invoice, PO, purchase receipt, statement). Fully offline — no CDN fonts/assets, everything embedded or local.

---

## 10. WhatsApp Architecture

```
.NET ERP API  →  writes to whatsapp_outbox (same DB, but NOT same transaction
                  as the business document — inserted only after that
                  transaction has already committed)
                    ↓
        Background worker (hosted service inside the same Windows Service,
        or a separate small process) polls whatsapp_outbox for `queued` rows
                    ↓
        Calls a local Baileys Node.js service over HTTP/localhost
                    ↓
        Baileys  →  Internet  →  WhatsApp
                    ↓
        Worker updates outbox row status (sent/failed) + attempts
```

If the Baileys service or internet is down, rows simply stay `queued`/`failed` and are retried later; no ERP endpoint waits on this worker synchronously.

---

## 11. Backup & Recovery

- **Automatic daily backup** (`pg_dump`, custom-format `-Fc` so it restores selectively if needed) runs as an in-process scheduled job inside the Host Windows Service — no dependency on Windows Task Scheduler being configured correctly by hand.
- **Destination path is configurable** from the Host dashboard/settings (defaults to a folder on a second drive if one is detected, e.g. `E:\ERP-Backups\`; falls back to a subfolder on the system drive with a visible warning if no second drive exists, since a second physical location is strongly recommended but the app shouldn't refuse to run without one).
- Retention: keep a rolling window (e.g. last 30 daily backups) and prune older ones automatically — exact retention count to confirm with you.
- Manual "Backup Now" button on the Host dashboard, writing to the same configured path.
- `backup_history` table records every attempt (`success`/`failed`) with file path and size, surfaced on the dashboard ("Last Backup: ...").
- Documented restore procedure (stop service → `pg_restore` into a fresh/empty DB → verify → restart service); tested at least once before go-live.
- Optional future improvement: also copy the latest backup file to a network share or external USB path if configured, as a second-location safeguard beyond the primary backup path.

---

## 12. Scale Target & Concurrency Handling (up to 10 Slave PCs)

Designing and testing against **10 concurrent Slave PCs** hitting the Host at once, with these edge cases explicitly handled rather than assumed away:

- **Same item sold on two Slaves at once** — stock decrement happens inside a DB transaction with a row-level lock (`SELECT ... FOR UPDATE` on `stock_balances`, or an EF Core optimistic-concurrency token) so two simultaneous sales of the last unit can't both succeed; the second request gets a clean "insufficient stock" error, not a race-condition negative quantity.
- **Same deposit allocated to two documents at once** — allocation reads the customer's available balance and writes the allocation in the same transaction with row locking on that customer's deposit rows, so two Slaves can't both allocate the same rupee.
- **Duplicate submits from network retries** — covered by the `Idempotency-Key` mechanism already in §3.9/§7: a resent request with the same key returns the original result instead of re-running the operation.
- **Connection pool sizing** — EF Core/Npgsql pool sized comfortably above 10 concurrent Slaves × a few in-flight requests each (e.g. pool max ~50–100), with PostgreSQL's `max_connections` raised to match; monitored via the Host dashboard.
- **Transaction isolation level** — `Read Committed` for normal reads, escalated to explicit row locks (above) only for the specific hot paths that need it (stock, deposits, financial ledger writes) — not a blanket `Serializable`, which would hurt throughput unnecessarily at this scale.
- **Long-running requests blocking others** — PDF generation and report queries run against read replicas/read-only queries where possible and are kept out of the same transaction scope as any write, so a slow report doesn't hold a lock that blocks a sale on another Slave.
- **Host restart / PostgreSQL restart while Slaves are mid-session** — Slaves detect the failed request per the "confirmed success / confirmed failure / unknown" rule in §8, surface a clear reconnect state, and safely resume once the Host is back — no silent data loss or duplicate submission on reconnect.

This will be load-tested with a simulated 10-Slave concurrent workload before Phase 3 is considered done, not just designed on paper.

---

## 13. Business Rule Decisions (resolved)

1. **Invoice/document numbering** — **Per financial year, resets** (e.g. `INV-2026-0001`, resets each Apr–Mar Indian financial year). A `document_sequences` table tracks the next number per document type per financial year (`doc_type`, `financial_year`, `last_number`), incremented inside the same transaction as document creation to avoid gaps/races across Slaves.
2. **Tax model** — **Full CGST/SGST/IGST split.** `items` carries a base tax rate (or link to a `tax_groups` table for multi-slab GST %); every line and invoice stores `cgst_amount`, `sgst_amount`, `igst_amount` computed server-side from the shop's state vs. the customer's billing state (intra-state → CGST+SGST, inter-state → IGST). `company_settings` (new table, §13a) stores the shop's own GSTIN/state for this comparison.
3. **Discounts** — **Line-level + invoice-level overall.** Each line keeps its own `discount` column; each of `quotations`/`proforma_invoices`/`sales_invoices` gets an additional `overall_discount_type` (`percent`/`flat`) + `overall_discount_value` + `overall_discount_amount`, applied after line totals, before tax.
4. **Proforma cancellation** — **Deposit auto-returns to available**, atomically with the stock reversal, in the same transaction (`deposit_allocations.status = reversed` + `financial_transactions` reversal row + `stock_movements` reversal row + audit log), no separate approval step.
5. **Sales invoice cancellation** — **Allowed, Admin-only**, auto-reverses stock and any deposit allocation, mandatory `reason`, all atomic; original invoice row is never edited, only its `status` flips to `cancelled` and reversal rows are created elsewhere.
6. **Purchase Order cancellation** — Default: **the un-received remainder of a PO can be cancelled** (PO status → `cancelled` if nothing received yet, or a partial-completion state if some lines were already received and only the rest is voided). Any payment still `processing` against that PO must be resolved (cancelled or completed) before the PO itself can be marked cancelled — the two statuses can't be left inconsistent. *(Default applied — flag if you want different handling.)*
7. **Negative stock / batch tracking** — **Never allowed**, and **full batch/lot tracking is added as a feature** (see §13a: `item_batches`, `stock_movement` lines reference a batch). Stock validation is per-batch for batch-tracked items; a non-batch-tracked item just carries a single running quantity (still validated — the "no need to validate" carve-out only applies to *which* batch is decremented, not to whether the total can go negative).
8. **Return refund method** — **Configurable per return** — the approver picks `cash_amount_out` or `credit_to_deposit` when completing a `sales_return`, recorded on the return row and driving which kind of `financial_transactions` row gets written.
9. **Credit limits** — **Out of scope for v1.** No enforcement; `customers` schema leaves room for a future nullable `credit_limit` without a migration headache later.
10. **Authentication mechanism** — **Server-side opaque session token**, stored in a `sessions` table (superseding the earlier `refresh_tokens` sketch — see §13a), instantly revocable by deactivating the row (e.g. force logout, deactivate user).
11. **Host IP strategy** — **DHCP reservation** recommended for the Host's LAN IP (simpler to administer than static IP, still stable across reboots). Documented as a deployment step in Phase 5, not enforced by the software itself.
12. **Multiple GST profiles** — **Single shop/GST profile.** One `company_settings` row (GSTIN, state, address, name) used on every document; no multi-entity support in v1.
13. **User self-registration** — **Confirmed no self-signup** — all accounts are created by Shop Admin only via `POST /api/users`.
14. **WhatsApp send trigger** — **Manual only.** Admin clicks "Send via WhatsApp" per document; nothing is auto-queued to `whatsapp_outbox` on document creation.
15. **Purchase Order → item price sync** — **Manual Item Master edit only.** A purchase receipt records the actual received rate on `purchase_receipt_lines`/`purchase_order_lines`; `items.purchase_price` is never auto-overwritten by a receipt.

## 13a. Schema Additions From These Decisions

- **`company_settings`** — single-row table: `shop_name`, `gstin`, `state`, `address`, `contact_number`, `logo` (for PDFs).
- **`document_sequences`** — `doc_type`, `financial_year`, `last_number`, unique on `(doc_type, financial_year)`; incremented transactionally on document creation.
- **`tax_groups`** (optional if more than one GST slab is needed) — `name`, `rate_percent`; `items.tax_group_id (FK)` replaces a flat `tax_rate` column.
- **`item_batches`** — PK `id`, FK `item_id`, `batch_number`, `quantity_on_hand`, `received_date`, `expiry_date` (nullable), `purchase_receipt_line_id (FK, nullable)`. `items` gets an `is_batch_tracked` flag.
- **`stock_movements`** gets an added nullable `batch_id (FK item_batches)` — populated for batch-tracked items, null otherwise; the negative-stock check locks and validates at the batch row when `batch_id` is set, otherwise at `stock_balances` directly.
- **`sales_returns`** gets a `refund_method` column (`cash_amount_out`/`credit_to_deposit`).
- **`sessions`** replaces the earlier `refresh_tokens` sketch — PK `id` (opaque token or its hash), FK `user_id`, `created_at`, `expires_at`, `revoked_at` (nullable), `last_seen_at`.
- Every document line total calculation (`quotation_lines`, `proforma_lines`, `sales_invoice_lines`, `purchase_order_lines`) is extended with `cgst_amount`, `sgst_amount`, `igst_amount` alongside the existing `tax_rate`/`line_total`.

---

## Next Step

Architecture and all 15 business rules are now confirmed. Proceeding to **Phase 2: PostgreSQL schema + EF Core entity design + migrations + seed data**, incorporating the schema additions in §13a above.
