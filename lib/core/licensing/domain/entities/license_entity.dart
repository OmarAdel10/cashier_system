class LicenseEntity {
  final String deviceId;
  final String activationSignature;
  final DateTime activatedAt;

  const LicenseEntity({
    required this.deviceId,
    required this.activationSignature,
    required this.activatedAt,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'activationSignature': activationSignature,
        'activatedAt': activatedAt.toIso8601String(),
      };

  factory LicenseEntity.fromJson(Map<String, dynamic> json) => LicenseEntity(
        deviceId: json['deviceId'] as String,
        activationSignature: json['activationSignature'] as String,
        activatedAt: DateTime.parse(json['activatedAt'] as String),
      );
}
