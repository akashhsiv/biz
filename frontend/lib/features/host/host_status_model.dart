class HostStatus {
  final bool serverRunning;
  final bool databaseConnected;
  final String? lanIp;
  final int port;
  final String? connectionUrl;
  final DateTime? lastBackupAt;
  final int? lastBackupStatus; // 0 = Success, 1 = Failed
  final int whatsappQueuedCount;
  final int whatsappFailedCount;
  final int connectedSlaveCount;

  HostStatus({
    required this.serverRunning,
    required this.databaseConnected,
    required this.lanIp,
    required this.port,
    required this.connectionUrl,
    required this.lastBackupAt,
    required this.lastBackupStatus,
    required this.whatsappQueuedCount,
    required this.whatsappFailedCount,
    required this.connectedSlaveCount,
  });

  factory HostStatus.fromJson(Map<String, dynamic> json) => HostStatus(
        serverRunning: json['serverRunning'] as bool,
        databaseConnected: json['databaseConnected'] as bool,
        lanIp: json['lanIp'] as String?,
        port: json['port'] as int,
        connectionUrl: json['connectionUrl'] as String?,
        lastBackupAt: json['lastBackupAt'] == null ? null : DateTime.parse(json['lastBackupAt'] as String),
        lastBackupStatus: json['lastBackupStatus'] as int?,
        whatsappQueuedCount: json['whatsappQueuedCount'] as int,
        whatsappFailedCount: json['whatsappFailedCount'] as int,
        connectedSlaveCount: json['connectedSlaveCount'] as int,
      );
}
