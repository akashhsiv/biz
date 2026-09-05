import json
import urllib.request
import uuid

BASE = "http://localhost:5000"

def call(method, path, body=None, token=None, idem=None, expect=None, raw_response=False):
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

    if expect and status != expect:
        raise AssertionError(f"{method} {path} -> {status} (expected {expect}): {raw[:300]}")
    if raw_response:
        return status, raw
    parsed = json.loads(raw) if raw else None
    return status, parsed

def newid():
    return str(uuid.uuid4())

def section(title):
    print(f"\n=== {title} ===")

section("login")
_, login = call("POST", "/api/auth/login", {"username": "admin", "password": "ChangeMe123!"}, expect=200)
token = login["token"]

section("host status")
status, host = call("GET", "/api/host/status", token=token, expect=200)
print(host)
assert host["serverRunning"] is True
assert host["databaseConnected"] is True
print("LAN IP detected:", host["lanIp"], "connection URL:", host["connectionUrl"])

section("setup: tax group, item, customer, deposit, quotation -> sales invoice")
_, tax = call("POST", "/api/tax-groups", {"name": "GST 18%", "ratePercent": 18}, token=token, expect=200)
_, item = call("POST", "/api/items", {
    "sku": "SKU-1", "name": "Test Item", "categoryId": None, "unit": "pcs", "itemKind": 0,
    "purchasePrice": 50, "sellingPrice": 100, "taxGroupId": tax["id"], "isBatchTracked": False
}, token=token, expect=200)
call("POST", "/api/stock/adjustments", {"itemId": item["id"], "quantityDelta": 50, "reason": "opening"}, token=token, expect=204)

_, cust = call("POST", "/api/customers", {
    "name": "Report Customer", "customerType": 0, "gstNumber": "29AAAAA0000A1Z5", "gstState": "Karnataka",
    "contactNumber": "9999999999", "email": None, "billingAddress": None, "shippingAddress": None
}, token=token, expect=200)
call("POST", "/api/customer-deposits", {"customerId": cust["id"], "amount": 1000, "paymentMethod": "cash", "notes": None}, token=token, idem=newid(), expect=200)

_, quote = call("POST", "/api/quotations", {
    "customerId": cust["id"],
    "lines": [{"itemId": item["id"], "description": "Test Item", "quantity": 2, "rate": 100, "discount": 0, "taxRatePercent": None}],
    "overallDiscountType": None, "overallDiscountValue": 0
}, token=token, expect=200)
_, conv = call("POST", f"/api/quotations/{quote['id']}/convert", {}, token=token, idem=newid(), expect=200)
print("converted:", conv)
invoice_id = conv["documentId"]

section("PDF generation (this triggers a one-time Chromium download if not cached)")
status, pdf_bytes = call("GET", f"/api/sales-invoices/{invoice_id}/pdf", token=token, expect=200, raw_response=True)
print(f"PDF bytes: {len(pdf_bytes)}, starts with %PDF: {pdf_bytes[:4] == b'%PDF'}")
assert pdf_bytes[:4] == b"%PDF"
with open("scripts/sample_invoice.pdf", "wb") as f:
    f.write(pdf_bytes)

status, quote_pdf = call("GET", f"/api/quotations/{quote['id']}/pdf", token=token, expect=200, raw_response=True)
assert quote_pdf[:4] == b"%PDF"
print("quotation PDF OK, bytes:", len(quote_pdf))

section("reports: sales")
status, sales_report = call("GET", "/api/reports/sales", token=token, expect=200)
print(sales_report)
assert sales_report["invoiceCount"] >= 1
assert sales_report["totalSales"] > 0

section("reports: stock low")
status, low = call("GET", "/api/reports/stock/low?threshold=1000", token=token, expect=200)
print(low)
assert any(r["itemId"] == item["id"] for r in low)

section("reports: finance")
status, finance = call("GET", "/api/reports/finance", token=token, expect=200)
print(finance)

section("reports: audit")
status, audit = call("GET", "/api/reports/audit", token=token, expect=200)
print(audit[:5])

section("backups: manual trigger + history")
status, backup = call("POST", "/api/backups/run", token=token, expect=200)
print(backup)
assert backup["status"] == 0  # Success
status, history = call("GET", "/api/backups", token=token, expect=200)
print(history)
assert len(history) >= 1

section("whatsapp: send (queues; Baileys not configured/running so it will just sit Queued)")
status, wa = call("POST", "/api/whatsapp/send", {
    "messageType": 2, "referenceType": 2, "referenceId": invoice_id, "recipientNumber": "919999999999", "customMessage": None
}, token=token, expect=200)
print(wa)
assert wa["status"] == 0  # Queued

status, wa_status = call("GET", "/api/whatsapp/status", token=token, expect=200)
print(wa_status)
assert wa_status["baileysReachable"] is False  # not configured in this environment
assert wa_status["queuedCount"] >= 1

section("logout")
call("POST", "/api/auth/logout", token=token, expect=204)

print("\nALL PHASE 3B (reports/pdf/backup/host/whatsapp) SMOKE TESTS PASSED")
