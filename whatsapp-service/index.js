// Minimal Baileys bridge for the ERP Host.
//
// Responsibilities:
//   - Maintain one WhatsApp Web session (QR-linked to a real phone number).
//   - Expose POST /send {to, message} for the .NET Host's outbox worker to call.
//   - Expose GET /health for the Host's WhatsApp status check.
//
// This process is intentionally separate from the .NET API (ARCHITECTURE.md §36): if this
// service is down, unlinked, or the phone has no internet, the ERP itself keeps working —
// messages simply stay queued in the Host's whatsapp_outbox table until this service is back.
//
// First-time setup: `npm install`, then `npm start`. A QR code prints to the console — scan it
// with WhatsApp on the linked phone (Settings > Linked Devices). The session is cached in
// ./auth-session so re-linking is only needed if that folder is deleted or the link is revoked.

const fs = require('fs');
const express = require('express');
const qrcode = require('qrcode-terminal');
const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
} = require('@whiskeysockets/baileys');

const PORT = process.env.PORT || 3001;
const AUTH_DIR = process.env.AUTH_DIR || './auth-session';

let sock = null;
let isReady = false;
// The raw QR payload Baileys emits (not an image) — a Dart QR-rendering widget on the client turns
// this string into a scannable code, so nothing here needs to generate an image itself. Cleared
// once a session connects, and re-populated automatically if Baileys needs to re-link.
let currentQr = null;

async function connect() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);

  sock = makeWASocket({ auth: state, printQRInTerminal: false });

  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      currentQr = qr;
      console.log('Scan this QR code with WhatsApp (Linked Devices):');
      qrcode.generate(qr, { small: true });
    }

    if (connection === 'open') {
      isReady = true;
      currentQr = null;
      console.log('WhatsApp session linked and connected.');
    }

    if (connection === 'close') {
      isReady = false;
      const shouldReconnect = lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
      console.log('Connection closed.', shouldReconnect ? 'Reconnecting...' : 'Logged out — delete auth-session/ to re-link.');
      if (shouldReconnect) connect();
      else currentQr = null;
    }
  });
}

connect().catch((err) => console.error('Failed to start WhatsApp session:', err));

const app = express();
// Default 100kb body limit is too small once a base64-encoded PDF is attached to a send.
app.use(express.json({ limit: '25mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: isReady ? 'connected' : 'not_connected' });
});

// Polled by the .NET Host (which proxies it to the Flutter client) to show a pairing QR when no
// session is linked yet. `qr` is null once connected or before Baileys has emitted one.
app.get('/status', (_req, res) => {
  res.json({ connected: isReady, qr: isReady ? null : currentQr });
});

// Deletes the cached session so the next connection attempt re-emits a fresh QR — used when a
// shop needs to re-pair (e.g. switched phones, or unlinked the device from WhatsApp itself).
app.post('/logout', async (_req, res) => {
  try {
    if (sock) {
      try { await sock.logout(); } catch { /* already unlinked on the phone side, ignore */ }
    }
    isReady = false;
    currentQr = null;
    fs.rmSync(AUTH_DIR, { recursive: true, force: true });
    connect().catch((err) => console.error('Failed to restart WhatsApp session:', err));
    res.json({ status: 'logged_out' });
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.post('/send', async (req, res) => {
  // documentBase64/fileName are optional - when present, the message is sent as a PDF document
  // with `message` as its caption, instead of a plain text message.
  const { to, message, documentBase64, fileName } = req.body ?? {};

  if (!isReady) {
    return res.status(503).json({ error: 'WhatsApp session is not connected.' });
  }
  if (!to || !message) {
    return res.status(400).json({ error: "'to' and 'message' are required." });
  }

  try {
    const digits = to.replace(/\D/g, '');
    const jid = to.includes('@') ? to : `${digits}@s.whatsapp.net`;

    // Baileys/WhatsApp's server accepts a send to any well-formed JID even when no account with
    // that number exists (e.g. a number typed without its country code) - it doesn't throw, it
    // just never delivers. Checking registration first turns that into a real, immediate error
    // instead of a false "sent" that silently goes nowhere - but this query call is itself
    // sometimes flaky/slow on this connection (same class of timeout Baileys logs internally for
    // its own init queries), so a failure here must not block a send that might actually work -
    // only a definite "not registered" answer blocks it; an inconclusive check just proceeds.
    if (!to.includes('@')) {
      try {
        const [result] = await sock.onWhatsApp(jid);
        if (result && !result.exists) {
          return res.status(400).json({
            error: `${digits} is not registered on WhatsApp. Make sure it includes the country code (e.g. 91${digits} for an Indian number).`,
          });
        }
      } catch (checkErr) {
        console.warn(`onWhatsApp check failed for ${digits}, sending anyway: ${checkErr}`);
      }
    }

    if (documentBase64) {
      await sock.sendMessage(jid, {
        document: Buffer.from(documentBase64, 'base64'),
        fileName: fileName || 'document.pdf',
        mimetype: 'application/pdf',
        caption: message,
      });
    } else {
      await sock.sendMessage(jid, { text: message });
    }
    res.json({ status: 'sent' });
  } catch (err) {
    console.error('Send failed:', err);
    res.status(500).json({ error: String(err) });
  }
});

const server = app.listen(PORT, () => console.log(`WhatsApp bridge listening on http://localhost:${PORT}`));

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    // node-windows restarts this process automatically on a crash (maxRestarts in win-service.cjs),
    // so exiting here just means "try again shortly" rather than a permanent failure - but log it
    // clearly so it shows up as the real cause instead of a silent "bridge unreachable" from the Host.
    console.error(`Port ${PORT} is already in use by another program - the WhatsApp bridge cannot start. ` +
      'Re-run win-service.cjs install with a different port, or free up this one.');
  } else {
    console.error('WhatsApp bridge failed to start:', err);
  }
  process.exit(1);
});
