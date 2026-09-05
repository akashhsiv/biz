# Biz — Product Requirements & System Architecture

## 1. Product Overview

**Biz** is a cloud-based, multi-shop business management platform that can grow into a complete **POS / ERP application**.

The initial focus is on:

- Inventory management
- Product management
- Sales
- Purchases
- Vendor management
- Customer management
- Customer-specific commission and rate tracking
- Staff management
- Salary tracking
- Notifications
- Document attachments
- Reports
- CSV export
- Multi-shop management
- User and category-based permissions

The architecture should be designed so that additional ERP/POS modules can be added later without redesigning the core system.

---

# 2. Multi-Shop Structure

A company can have multiple shops.

```text
Company
│
├── Shop A
├── Shop B
└── Shop C
```

Each shop should have its own:

- Users
- Categories
- Products / inventory
- Vendors
- Customers
- Sales
- Purchases
- Staff
- Notifications
- Reports
- WhatsApp connection

Data must remain isolated between shops unless a future feature explicitly allows cross-shop access.

---

# 3. User Management & Permissions

Users belong to a shop and receive permissions based on their assigned role and category access.

A user can be allowed to work with one or more categories.

Example:

```text
User: Arun

Allowed Categories:
✓ Paint
✓ Chemical

Sales:
✓ Allowed

Purchase:
✓ Allowed
```

Another user:

```text
User: Kumar

Allowed Categories:
✓ Plumbing
✓ Sanitary

Sales:
✓ Allowed

Purchase:
✗ Not Allowed
```

## Important

Category restrictions must be enforced by the **backend**, not only by hiding categories in the UI.

The UI should show only the categories and actions the user is allowed to access.

---

# 4. Shop Categories

Categories are editable by the Shop Admin.

Example categories:

```text
Paint & Chemical
Cement & Steel
Plumbing
Sanitary
Electrical
Hardware
```

The category structure should be flexible enough for each business to create its own categories.

---

# 5. Product Management

Products should contain the information required for inventory, purchasing and sales.

Possible product information:

- Product name
- Product code / SKU
- Category
- Unit
- GST / tax information
- Purchase price
- Selling price
- Margin
- Minimum stock
- Active / inactive status

A product can exist in multiple shops.

Each shop can maintain its own:

- Stock
- Minimum stock
- Purchase history
- Selling price
- Pricing configuration

---

# 6. Vendor Management

Vendors can be associated with one or more categories.

Example:

```text
Vendor: JSW

Categories:
✓ Paint
```

Another vendor:

```text
Vendor: ABC Traders

Categories:
✓ Plumbing
✓ Sanitary
```

When creating a purchase, selecting a vendor should restrict the available products to the categories/products applicable to that vendor.

Example:

```text
Vendor: JSW
Category: Paint

Products shown:
- JSW Paint A
- JSW Paint B
- JSW Primer
```

Products from unrelated categories should not unnecessarily appear.

Vendor-category relationships should be maintained at the appropriate shop/company scope defined during final DB design.

---

# 7. Purchase Management

Purchases are a major part of Biz.

A purchase should support:

- Vendor
- Purchase date
- Invoice/document number
- Products
- Quantity
- Purchase price
- GST
- Total amount
- Paid amount
- Outstanding amount
- Due date
- Payment status
- Attachments

## Purchase Price

The actual purchase price and GST used in a purchase must be preserved as part of the purchase transaction.

Historical purchase prices should not be lost when the product's current purchase price changes.

---

# 8. Purchase Payment Tracking

Purchases may be paid fully or partially.

Example:

```text
Purchase Total       ₹85,000
Paid                 ₹50,000
Outstanding          ₹35,000
Due Date             15-09-2026

Status: Partially Paid
```

Possible statuses:

- Paid
- Partially Paid
- Pending
- Overdue

The system should maintain payment history rather than only storing the latest payment amount.

---

# 9. Purchase Document Attachments

Purchases can contain multiple document attachments.

Examples:

- Supplier invoice
- Purchase bill
- Delivery challan
- Quotation
- Payment receipt
- Transport document
- Other supporting documents

Example UI:

```text
Purchase #PUR-2026-00125

Vendor: JSW
Date: 04-09-2026
Total: ₹85,000
Outstanding: ₹35,000

Documents
────────────────────────
📄 JSW_Invoice_125.pdf
📄 Delivery_Challan_125.pdf
🖼 Payment_Receipt.jpg

[ + Add Document ]
```

Users with appropriate permissions should be able to:

- Upload
- View
- Download
- Delete

The system should allow PDFs and images to be viewed directly in the application where practical.

Document deletion should preferably be a separate permission from normal purchase access.

---

# 10. Sales / POS

Biz should be designed to support a future or current POS module.

Sales should support:

- Customer
- Products
- Quantity
- Selling price
- Discounts
- GST
- Commission
- Payment
- Outstanding amount
- Returns
- Invoice/document information

The POS should respect:

- Shop
- User permissions
- Category permissions
- Product availability
- Current stock

---

# 11. Selling Price & Margin

Selling prices can be derived using product margins.

The exact meaning of margin should be finalized before implementation:

- Markup on purchase price, or
- Actual profit margin

GST treatment should also be explicitly defined as either:

- GST included in selling price, or
- GST added on top of selling price

These rules should be centralized in the backend.

---

# 12. Customer Management

Customers should have a complete transaction history.

Customer tracking should include:

- Customer details
- Sales
- Products purchased
- Purchase history
- Outstanding amount
- Payments
- Returns
- Commission
- Commission status
- Date-wise activity

Example:

```text
Customer: Ravi

Total Sales        ₹1,50,000
Outstanding         ₹25,000
Commission           ₹7,500

Commission Status:
₹5,000 Paid
₹2,500 Pending
```

---

# 13. Customer-Specific Pricing & Commission

Biz should support customer-based pricing and commission.

A customer may have a different rate or commission arrangement for specific products.

The exact business definition of **commission** must be finalized:

- Commission paid to the customer
- Commission earned through the customer
- Customer-specific discount/rate
- Other commission arrangement

Commission should be tracked independently so that historical transactions are not changed when future rates are modified.

---

# 14. Commission Tracking

Commission reports should support:

- Customer-wise commission
- Product-wise commission
- Invoice-wise commission
- Date-wise commission
- Total commission
- Pending commission
- Paid commission
- Partially paid commission
- Cancelled / adjusted commission

Example:

```text
Customer Commission

Customer     Sales       Commission     Status
------------------------------------------------
Customer A   ₹50,000     ₹2,500         Pending
Customer B   ₹80,000     ₹4,000         Paid

Total        ₹1,30,000   ₹6,500
```

Possible commission statuses:

- Pending
- Partially Paid
- Paid
- Cancelled
- Adjusted

---

# 15. Inventory Management

Inventory should be maintained separately for each shop.

The system should support:

- Current stock
- Stock in
- Stock out
- Purchase stock
- Sales stock
- Returns
- Adjustments
- Stock movement history
- Minimum stock
- Low-stock alerts

Negative stock should not be allowed unless explicitly enabled by a future business rule.

---

# 16. Low Stock Alerts

Each shop/product can have a minimum stock level.

Example:

```text
Product: Asian Paint — 5L

Current Stock: 2
Minimum Stock: 10

Status: Low Stock
```

Low-stock alerts can be delivered through:

- Mobile notifications
- WhatsApp notifications

Notification preferences are configurable per shop.

---

# 17. Staff Management

Biz should maintain staff information for each shop.

Staff details can include:

- Staff name
- Employee ID
- Mobile number
- Address
- Joining date
- Designation
- Department/category
- Employment status
- Salary type
- Basic salary
- Allowances
- Deductions
- Notes

Salary types may include:

- Monthly
- Daily
- Hourly

---

# 18. Salary Tracking

Salary should be tracked historically.

Example:

```text
Staff: Ravi
Month: September 2026

Basic Salary       ₹20,000
Allowance            ₹2,000
Deduction            ₹1,000
--------------------------------
Net Salary          ₹21,000

Paid                ₹15,000
Pending              ₹6,000

Status: Partially Paid
```

Salary tracking should support:

- Salary calculation
- Salary payments
- Partial payments
- Pending salary
- Payment history
- Salary adjustments
- Monthly salary records

Possible statuses:

- Pending
- Partially Paid
- Paid

---

# 19. Notifications

Notifications are managed at the **shop level**.

Biz supports two main notification channels:

1. WhatsApp using Baileys
2. Mobile push notifications

```text
Shop
│
├── WhatsApp / Baileys Session
├── Notification Settings
└── Mobile App Users
```

---

# 20. WhatsApp / Baileys Integration

Each shop should have its own WhatsApp session.

The Shop Admin connects WhatsApp by scanning a QR code.

```text
Shop Admin
    ↓
Shop Settings
    ↓
WhatsApp Notifications
    ↓
Connect WhatsApp
    ↓
Display QR
    ↓
Scan QR
    ↓
WhatsApp Connected
```

The WhatsApp session belongs to the **shop**, not to an individual admin user.

If the Shop Admin account changes, the shop's WhatsApp connection should remain associated with that shop.

---

# 21. WhatsApp UI

The UI should be simple and understandable.

Connected:

```text
WhatsApp Notifications

Status
● Connected

WhatsApp Number
+91 XXXXX XXXXX

[ Send Test Message ]

[ Disconnect WhatsApp ]
```

Not connected:

```text
WhatsApp Notifications

Status
○ Not Connected

Connect WhatsApp to send alerts and notifications.

[ Connect WhatsApp ]
```

Connection screen:

```text
Connect WhatsApp

1. Open WhatsApp on your phone
2. Go to Linked Devices
3. Scan the QR code

        [ QR CODE ]

Waiting for connection...

[ Cancel ]
```

Technical Baileys session details should not be exposed to normal users.

---

# 22. Mobile Notifications

Mobile push notifications should work independently from WhatsApp.

Examples:

```text
Low Stock Alert
Asian Paint — 5L
Current Stock: 2
Minimum Stock: 10
```

```text
Purchase Overdue
Vendor: JSW
Outstanding: ₹35,000
Due Date: 01-09-2026
```

Mobile notifications should respect the user's shop and permissions.

---

# 23. Notification Settings

Shop Admin should be able to configure notification channels.

Example:

```text
Notification Settings

Low Stock
[✓] WhatsApp
[✓] Mobile

Purchase Due
[✓] WhatsApp
[✓] Mobile

Purchase Overdue
[✓] WhatsApp
[✓] Mobile

Customer Outstanding
[ ] WhatsApp
[✓] Mobile
```

---

# 24. Notification Architecture

Business logic should create notification events.

The business logic should not directly depend on WhatsApp/Baileys.

Example:

```text
Sale Created
    ↓
Stock Updated
    ↓
Stock <= Minimum Stock
    ↓
Create LOW_STOCK Event
    ↓
Notification Engine
    ├── WhatsApp → Baileys
    └── Mobile → Push Notification
```

Purchase overdue:

```text
Purchase
    ↓
Due Date Passed
    ↓
Outstanding Amount > 0
    ↓
Create PURCHASE_OVERDUE Event
    ↓
Notification Engine
    ├── WhatsApp
    └── Mobile
```

This separation allows additional notification channels to be added later.

---

# 25. Reports

Reporting should be a **core feature of Biz**, not a separate afterthought.

Most major modules should provide reports with:

- Search
- Filters
- Date range
- Shop
- Category
- Customer
- Vendor
- Product
- Staff
- Status
- Export CSV

Common UI:

```text
[ Search ]

Date From   [ 01-09-2026 ]
Date To     [ 04-09-2026 ]

Shop        [ All Shops ▼ ]
Category    [ All Categories ▼ ]

[ Filter ]                       [ Export CSV ]
```

The report should show only the filtered results.

---

# 26. Customer Reports

Reports should include:

- Customer sales
- Customer purchases
- Customer outstanding
- Customer payments
- Customer commission
- Customer commission status
- Customer transaction history
- Customer-wise product purchases
- Date-wise customer activity

---

# 27. Purchase Reports

Reports should include:

- Purchase history
- Date-wise purchases
- Vendor-wise purchases
- Product-wise purchases
- Category-wise purchases
- Purchase outstanding
- Purchase due
- Purchase overdue
- Purchase payment history
- Purchase document history

---

# 28. Vendor Reports

Reports should include:

- Vendor purchase history
- Vendor-wise products
- Vendor-wise categories
- Vendor outstanding
- Vendor payment history
- Vendor-wise purchase summary
- Date-wise vendor activity

---

# 29. Product Reports

Reports should include:

- Product sales
- Product purchases
- Current stock
- Stock movement
- Purchase price history
- Selling price history
- Low-stock products
- Product-wise commission
- Category-wise product performance

---

# 30. Commission Reports

Reports should include:

- Customer-wise commission
- Product-wise commission
- Invoice-wise commission
- Date-wise commission
- Pending commission
- Paid commission
- Partially paid commission
- Commission by status

---

# 31. Staff & Salary Reports

Reports should include:

- Staff list
- Staff-wise salary
- Monthly salary
- Salary paid
- Salary pending
- Salary payment history
- Date-wise salary payments
- Shop-wise staff cost
- Designation-wise salary

---

# 32. Date-Based Reports

Reports should support:

- Today
- Yesterday
- This week
- This month
- Previous month
- Current financial year
- Custom date range

Date filtering should be available wherever it makes business sense.

---

# 33. CSV Export

Reports should be downloadable as **CSV files**.

Example:

```text
Purchase Report

[ Filters ]

--------------------------------------------------
Date       Vendor       Product       Amount
--------------------------------------------------
04-09-26   JSW          Paint A       ₹25,000
04-09-26   ABC          Pipe 1"       ₹15,000
--------------------------------------------------

Total Purchase: ₹40,000

[ Export CSV ]
```

The CSV export should contain the currently filtered report data.

The export should not unexpectedly export unrelated records.

---

# 34. Common Reporting Architecture

Reports should use a common reporting framework.

```text
Biz
│
└── Reports
    ├── Sales
    ├── Purchases
    ├── Customers
    ├── Vendors
    ├── Products
    ├── Inventory
    ├── Commission
    ├── Staff
    ├── Salary
    └── Payments
```

Common filters should be reusable across reports.

---

# 35. Data & Document Storage

Business transaction data should be stored in the cloud database.

Files such as purchase invoices and images should not be stored directly inside PostgreSQL as large binary records unless there is a specific reason.

Recommended approach:

```text
Database
    │
    ├── Document metadata
    │
    └── Storage key
             ↓
       File/Object Storage
             │
             ├── PDF
             ├── JPG
             └── PNG
```

Access to documents must be authenticated and must respect shop/user permissions.

---

# 36. Future ERP / POS Expansion

Biz should be designed as a platform rather than a single-purpose inventory application.

Future modules may include:

- POS
- Sales
- Purchases
- Inventory
- Customer management
- Vendor management
- Staff management
- Salary
- Payments
- Expenses
- Returns
- Quotations
- Invoices
- Reports
- Notifications
- Document management
- Dashboard
- Financial modules
- Multi-shop stock transfer

The architecture should allow these modules to be added without changing the fundamental shop/user/security model.

---

# 37. Core Architecture Direction

The intended architecture is cloud-based.

```text
                Internet
                    │
                    ▼
             Cloud API Server
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
   PostgreSQL Database   Notification Services
                              │
                       ┌──────┴──────┐
                       ▼             ▼
                    Baileys       Mobile Push
                       │
                    WhatsApp
```

Clients may include:

```text
Flutter Desktop
Flutter Mobile
Future Web App
```

All important business rules should be evaluated on the backend.

The client should not be trusted to calculate or enforce business-critical rules.

---

# 38. Important Design Principles

1. **Shop isolation**
   - Every business transaction must belong to the correct shop.

2. **Backend enforcement**
   - Permissions and business rules must be enforced by the API.

3. **Historical accuracy**
   - Purchase prices, selling prices, commissions and payments should preserve historical transaction values.

4. **Simple UI**
   - Shop Admins and staff should be able to understand the application without technical knowledge.

5. **Reusable reporting**
   - Reports should share common filters and CSV export functionality.

6. **Independent notification channels**
   - WhatsApp and mobile notifications should not be tightly coupled to business logic.

7. **Shop-owned WhatsApp**
   - Baileys sessions belong to shops rather than individual users.

8. **Extensible architecture**
   - New ERP/POS modules should be able to use the existing shop, user, product, customer, vendor and reporting foundations.

---

# 39. Items Requiring Final Business Decisions

Before database implementation, the following points should be finalized:

- Company-to-shop relationship
- Whether users can access multiple shops
- Whether categories are company-wide or shop-specific
- Whether products can belong to multiple categories
- Whether a product can have only one primary category
- Exact meaning of selling-price margin
- GST-inclusive or GST-exclusive selling price
- Exact meaning of customer commission
- Commission calculation level
- Commission payment workflow
- Purchase credit period
- Partial payment rules
- Customer outstanding rules
- Vendor outstanding rules
- Staff salary calculation rules
- Salary payment rules
- Notification recipients
- Mobile notification provider
- WhatsApp message templates
- WhatsApp notification recipients
- Document file-size/type limits
- Document retention rules
- Shop-to-shop stock transfer
- Financial year and document numbering
- Report permissions
- CSV export permissions

These decisions should be finalized before the database schema and API contracts are locked.
