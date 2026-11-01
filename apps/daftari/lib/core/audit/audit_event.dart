enum AuditEventType {
  login,
  loginFailed,
  logout,
  userCreated,
  userDeleted,
  passwordChanged,
  receiptCreated,
  stockUpdateFailed,
  stockRetryResolved,
  expenseCreated,
}

class AuditEntry {
  final DateTime timestamp;
  final AuditEventType type;
  final String? username;
  final String details;
  final bool success;

  const AuditEntry({
    required this.timestamp,
    required this.type,
    this.username,
    required this.details,
    required this.success,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'username': username,
    'details': details,
    'success': success,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: AuditEventType.values.byName(json['type'] as String),
    username: json['username'] as String?,
    details: json['details'] as String,
    success: json['success'] as bool,
  );
}
