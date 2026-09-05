// Registers/unregisters this service as a real Windows service using node-windows, so it starts
// automatically alongside ErpHost instead of needing anyone to run `npm start` by hand. Pattern
// copied from this org's own proven Angadi WhatsApp server installer (node-windows + a bundled
// node.exe next to this script, falling back to system Node if none is bundled).
//
// Usage: node win-service.cjs install [port]   (also auto-starts it; port defaults to 3001)
//        node win-service.cjs uninstall

const Service = require('node-windows').Service;
const path = require('path');
const fs = require('fs');
const net = require('net');

const bundledNode = path.join(__dirname, 'node.exe');
const execPath = fs.existsSync(bundledNode) ? bundledNode : undefined;

// Port is fixed at install time (passed as the 2nd arg to `install`) rather than read from the
// environment at service-start time, because node-windows bakes env vars into the generated
// service config, not the running shell's environment.
const action = process.argv[2];
const requestedPort = parseInt(process.argv[3] || '3001', 10);

/// install.bat already picks a free port before calling this script (via find-free-port.ps1), but
/// that check and this install aren't atomic, and this script can also be run by hand (e.g. an
/// admin re-running it with a stale/hardcoded port). Rather than silently register a service that
/// will fail to bind and just look "not running" with no clue why, verify the port ourselves and
/// walk forward to the next free one if needed - then write the port actually used to a file the
/// caller (install.bat, or a person reading it directly) can pick up.
function isPortFree(port) {
  return new Promise((resolve) => {
    const tester = net.createServer();
    tester.once('error', () => resolve(false));
    tester.once('listening', () => tester.close(() => resolve(true)));
    tester.listen(port, '127.0.0.1');
  });
}

async function findFreePort(startPort) {
  let port = startPort;
  while (!(await isPortFree(port))) port++;
  return port;
}

async function main() {
  if (action === 'uninstall') {
    const svc = new Service({ name: 'ERP WhatsApp Bridge', script: path.join(__dirname, 'index.js') });
    svc.on('uninstall', () => console.log('Service uninstalled successfully.'));
    svc.uninstall();
    return;
  }

  const port = await findFreePort(requestedPort);
  if (port !== requestedPort) {
    console.log(`Port ${requestedPort} is already in use - using ${port} instead.`);
  }
  fs.writeFileSync(path.join(__dirname, 'resolved-port.txt'), String(port), 'utf8');

  const svcOptions = {
    name: 'ERP WhatsApp Bridge',
    description: 'Baileys WhatsApp Web bridge for the ERP Host - decoupled so a disconnected phone never blocks the ERP itself.',
    script: path.join(__dirname, 'index.js'),
    nodeOptions: [],
    wait: 2,
    grow: 0.5,
    maxRestarts: 10,
    env: [{ name: 'PORT', value: String(port) }],
  };

  if (execPath) {
    svcOptions.execPath = execPath;
    console.log('Using bundled Node.js:', execPath);
  }

  const svc = new Service(svcOptions);
  svc.on('install', () => {
    console.log(`Service installed successfully on port ${port}. Starting...`);
    svc.start();
  });
  svc.on('start', () => console.log('Service started successfully.'));
  svc.on('alreadyinstalled', () => {
    console.log('Service is already installed. Starting...');
    svc.start();
  });
  svc.on('error', (err) => console.error('Service error:', err));
  svc.install();
}

main().catch((err) => {
  console.error('Failed to install WhatsApp bridge service:', err);
  process.exit(1);
});
