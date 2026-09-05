# ERP WhatsApp Bridge

A small Baileys-based Node service that gives the ERP Host WhatsApp send capability, kept fully
decoupled from the .NET API so a WhatsApp outage never affects a sale — see
[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) §36/§37.

## Setup

```bash
npm install
npm start
```

On first run, a QR code prints to the console. Open WhatsApp on the phone you want to send
from → **Settings → Linked Devices → Link a Device** → scan it. The session is cached in
`./auth-session/`; you only need to re-scan if that folder is deleted or the device is unlinked
from the phone.

## Configure the Host to use it

In the Host's `appsettings.json` (or `appsettings.Development.json`):

```json
{
  "Whatsapp": {
    "BaileysBaseUrl": "http://localhost:3001"
  }
}
```

With that set, `GET /api/whatsapp/status` on the Host reflects this service's `/health`, and the
Host's background outbox worker starts delivering queued messages here every ~30 seconds.

## Endpoints

- `GET /health` → `{ "status": "connected" | "not_connected" }`
- `POST /send` → `{ "to": "9198XXXXXXXX", "message": "..." }`, returns `{ "status": "sent" }`

## Known limitations of this scaffold

- Unofficial client: this uses WhatsApp Web's protocol via Baileys, not Meta's official Business
  API. It carries a real (if generally low, for moderate legitimate use) risk of the linked number
  being banned — flagged to you already in the architecture discussion, accepted as-is.
- No message queue prioritization or rate limiting beyond what the Host's outbox worker does
  (small batches, ~30s polling, 5 retry attempts before a message is marked `Failed`).
- Not yet packaged as a Windows Service — for production, run it under something like
  [pm2](https://pm2.keymetrics.io/) or NSSM so it restarts automatically and survives reboots
  alongside the .NET Host.
