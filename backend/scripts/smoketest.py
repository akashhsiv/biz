import json
import urllib.request
import uuid

BASE = "http://localhost:5000"

def call(method, path, body=None, token=None, idem=None, expect=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if idem:
        req.add_header("Idempotency-Key", idem)
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
            raw = resp.read()
    except urllib.error.HTTPError as e:
        status = e.code
        raw = e.read()

    parsed = json.loads(raw) if raw else None
    if expect and status != expect:
        raise AssertionError(f"{method} {path} -> {status} (expected {expect}): {raw}")
    return status, parsed

def newid():
    return str(uuid.uuid4())

def section(title):
    print(f"\n=== {title} ===")

section("health")
print(call("GET", "/api/health"))

section("login")
status, login = call("POST", "/api/auth/login", {"username": "admin", "password": "ChangeMe123!"}, expect=200)
token = login["token"]
print("logged in as", login["username"], "role", login["roleName"])

section("tax group 18%")
status, tax = call("POST", "/api/tax-groups", {"name": "GST 18%", "ratePercent": 18}, token=token, expect=200)
tax_id = tax["id"]

section("item Widget (non-batch stock item)")
status, item1 = call("POST", "/api/items", {
    "sku": "SKU-WIDGET", "name": "Widget", "categoryId": None, "unit": "pcs", "itemKind": 0,
    "purchasePrice": 50, "sellingPrice": 100, "taxGroupId": tax_id, "isBatchTracked": False
}, token=token, expect=200)
item1_id = item1["id"]
print(item1)

section("opening stock: +100 widgets via manual adjustment")
status, _ = call("POST", "/api/stock/adjustments", {
    "itemId": item1_id, "quantityDelta": 100, "reason": "opening stock"
}, token=token, expect=204)

status, levels = call("GET", "/api/stock", token=token, expect=200)
print(levels)
assert next(l for l in levels if l["itemId"] == item1_id)["quantityOnHand"] == 100

section("customer (same state as shop = Karnataka => CGST/SGST split)")
status, cust = call("POST", "/api/customers", {
    "name": "Test Customer", "customerType": 0, "gstNumber": "29AAAAA0000A1Z5", "gstState": "Karnataka",
    "contactNumber": "9999999999", "email": None, "billingAddress": None, "shippingAddress": None
}, token=token, expect=200)
cust_id = cust["id"]
print(cust)

section("deposit: 500 (enough to cover a 472 quotation)")
status, dep = call("POST", "/api/customer-deposits", {
    "customerId": cust_id, "amount": 500, "paymentMethod": "cash", "notes": "initial"
}, token=token, idem=newid(), expect=200)
print(dep)

status, summary = call("GET", f"/api/customers/{cust_id}/deposit-summary", token=token, expect=200)
print("deposit summary:", summary)
assert summary["available"] == 500

section("quotation 1: 4 widgets @ 100 = 400 + 18% tax(72) = 472 (<=500 deposit)")
status, quote1 = call("POST", "/api/quotations", {
    "customerId": cust_id,
    "lines": [{"itemId": item1_id, "description": "Widget", "quantity": 4, "rate": 100, "discount": 0, "taxRatePercent": None}],
    "overallDiscountType": None, "overallDiscountValue": 0
}, token=token, expect=200)
print(quote1)
quote1_id = quote1["id"]
assert quote1["grandTotal"] == 472.00, quote1["grandTotal"]
assert quote1["taxTotal"] == 72.00

section("convert quotation 1 -> expect SalesInvoice (deposit 500 >= 472)")
idem_key_1 = newid()
status, conv1 = call("POST", f"/api/quotations/{quote1_id}/convert", {}, token=token, idem=idem_key_1, expect=200)
print(conv1)
assert conv1["resultType"] == "SalesInvoice", conv1
invoice1_id = conv1["documentId"]

section("retry convert with SAME idempotency key -> must replay, not double-charge stock/deposit")
status, conv1_retry = call("POST", f"/api/quotations/{quote1_id}/convert", {}, token=token, idem=idem_key_1, expect=200)
assert conv1_retry == conv1, "idempotent replay mismatch!"
print("replay OK:", conv1_retry)

section("stock after sale: 100 - 4 = 96")
status, levels = call("GET", "/api/stock", token=token, expect=200)
widget_stock = next(l for l in levels if l["itemId"] == item1_id)["quantityOnHand"]
print("widget stock:", widget_stock)
assert widget_stock == 96, widget_stock

section("deposit available after sale: 500 - 472 = 28")
status, summary = call("GET", f"/api/customers/{cust_id}/deposit-summary", token=token, expect=200)
print(summary)
assert summary["available"] == 28

section("quotation 2: 3 widgets @ 100 = 300 + 54 tax = 354 (deposit only has 28 available) -> Proforma")
status, quote2 = call("POST", "/api/quotations", {
    "customerId": cust_id,
    "lines": [{"itemId": item1_id, "description": "Widget", "quantity": 3, "rate": 100, "discount": 0, "taxRatePercent": None}],
    "overallDiscountType": None, "overallDiscountValue": 0
}, token=token, expect=200)
quote2_id = quote2["id"]
print(quote2)

status, conv2 = call("POST", f"/api/quotations/{quote2_id}/convert", {}, token=token, idem=newid(), expect=200)
print(conv2)
assert conv2["resultType"] == "ProformaInvoice", conv2
proforma_id = conv2["documentId"]
assert conv2["depositApplied"] == 28
assert conv2["outstanding"] == 326

section("stock decremented immediately even for proforma: 96 - 3 = 93")
status, levels = call("GET", "/api/stock", token=token, expect=200)
widget_stock = next(l for l in levels if l["itemId"] == item1_id)["quantityOnHand"]
print("widget stock:", widget_stock)
assert widget_stock == 93, widget_stock

section("add more deposit (400) then allocate to clear the 326 outstanding")
call("POST", "/api/customer-deposits", {"customerId": cust_id, "amount": 400, "paymentMethod": "cash", "notes": "topup"}, token=token, idem=newid(), expect=200)
status, alloc = call("POST", f"/api/proformas/{proforma_id}/allocate-deposit", {"amount": None}, token=token, idem=newid(), expect=200)
print(alloc)
assert alloc["outstandingTotal"] == 0
assert alloc["status"] == 1  # FullyFunded

section("clear dues: proforma -> sales invoice")
status, conv3 = call("POST", f"/api/proformas/{proforma_id}/convert", {}, token=token, idem=newid(), expect=200)
print(conv3)
assert conv3["resultType"] == "SalesInvoice"

section("cancel first sales invoice (Admin) -> stock restored, deposit released")
status, _ = call("POST", f"/api/sales-invoices/{invoice1_id}/cancel", {"reason": "test cancellation"}, token=token, expect=204)
status, levels = call("GET", "/api/stock", token=token, expect=200)
widget_stock = next(l for l in levels if l["itemId"] == item1_id)["quantityOnHand"]
print("widget stock after cancel:", widget_stock)
assert widget_stock == 97, widget_stock  # 93 + 4 restored

status, summary = call("GET", f"/api/customers/{cust_id}/deposit-summary", token=token, expect=200)
print("deposit summary after cancel:", summary)

section("== PURCHASE FLOW ==")
status, supplier = call("POST", "/api/suppliers", {"name": "Acme Supplies", "gstNumber": "29BBBBB0000B1Z1", "state": "Maharashtra", "contactNumber": None, "address": None}, token=token, expect=200)
supplier_id = supplier["id"]
print(supplier)

status, item2 = call("POST", "/api/items", {
    "sku": "SKU-GADGET", "name": "Gadget", "categoryId": None, "unit": "pcs", "itemKind": 0,
    "purchasePrice": 200, "sellingPrice": 400, "taxGroupId": tax_id, "isBatchTracked": True
}, token=token, expect=200)
item2_id = item2["id"]

status, po = call("POST", "/api/purchase-orders", {
    "supplierId": supplier_id,
    "lines": [{"itemId": item2_id, "quantityOrdered": 10, "rate": 200}]
}, token=token, expect=200)
print(po)
po_id = po["id"]
po_line_id = po["lines"][0]["id"]
assert po["taxTotal"] == 360.00  # inter-state (Karnataka shop vs Maharashtra supplier) => IGST 18% of 2000

call("POST", f"/api/purchase-orders/{po_id}/submit", {}, token=token, expect=204)

status, receipt = call("POST", f"/api/purchase-orders/{po_id}/receipts", {
    "lines": [{"poLineId": po_line_id, "quantityReceived": 10, "batchNumber": "BATCH-1", "expiryDate": None}]
}, token=token, expect=200)
print(receipt)
assert receipt["purchaseOrderStatus"] == 4  # Completed

status, levels = call("GET", "/api/stock", token=token, expect=200)
gadget_stock = next(l for l in levels if l["itemId"] == item2_id)["quantityOnHand"]
assert gadget_stock == 10, gadget_stock

section("purchase payment -> complete -> shop balance decreases")
status, before_balance = call("GET", "/api/finance/shop-balance", token=token, expect=200)
print("balance before payment:", before_balance)

status, payment = call("POST", f"/api/purchase-orders/{po_id}/payments", {"amount": 2360, "paymentMethod": "bank_transfer"}, token=token, expect=200)
print(payment)
call("POST", f"/api/purchase-orders/{po_id}/payments/{payment['id']}/complete", {}, token=token, expect=204)

status, after_balance = call("GET", "/api/finance/shop-balance", token=token, expect=200)
print("balance after payment:", after_balance)
assert after_balance["balance"] == before_balance["balance"] - 2360

section("== RETURNS FLOW ==")
status, invoices = call("GET", f"/api/sales-invoices?customerId={cust_id}", token=token, expect=200)
active_invoice = next(i for i in invoices if i["status"] == 0)
inv_line = active_invoice["lines"][0]
print("returning against invoice", active_invoice["invoiceNumber"], "line", inv_line)

status, ret = call("POST", "/api/sales-returns", {
    "salesInvoiceId": active_invoice["id"], "reason": "customer changed mind",
    "lines": [{"salesInvoiceLineId": inv_line["id"], "quantityReturned": 1, "restock": True}]
}, token=token, expect=200)
print(ret)
ret_id = ret["id"]

call("POST", f"/api/sales-returns/{ret_id}/approve", {}, token=token, expect=204)

status, before_balance = call("GET", "/api/finance/shop-balance", token=token, expect=200)
call("POST", f"/api/sales-returns/{ret_id}/complete", {"refundMethod": 0}, token=token, expect=204)  # CashAmountOut
status, after_balance = call("GET", "/api/finance/shop-balance", token=token, expect=200)
print("balance before/after refund:", before_balance, after_balance)
assert after_balance["balance"] == before_balance["balance"] - ret["totalRefundAmount"]

section("audit logs sample")
status, logs = call("GET", "/api/audit-logs?take=10", token=token, expect=200)
for l in logs[:10]:
    print(l["action"], l["entityType"])

section("logout")
call("POST", "/api/auth/logout", token=token, expect=204)

print("\nALL SMOKE TESTS PASSED")
