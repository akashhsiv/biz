/// The single cloud-hosted backend this app talks to. The app used to be a LAN Host/Slave setup
/// where each Slave typed or auto-discovered the Host's local IP address on every launch — that
/// flow (ConnectionScreen, UDP discovery, a saved/typed host URL) is gone now that there is one
/// fixed server address for every install, so this is set once, unconditionally, at startup.
const String kBackendBaseUrl = 'http://148.113.6.25:5000';
