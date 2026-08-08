enum SessionTier { normal, multi }

enum SessionRecordStatus { completed }

/// Immutable ledger record for a completed station session.
///
/// Parallel to [ReceiptEntity] for retail transactions: sessions are NOT
/// retail receipts, they are station billing records.
class SessionRecordEntity {
  final String id;
  final String shiftId;
  final String stationId;
  final String stationName;
  final String parentCategory;
  final SessionTier tier;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final bool wasFixedDuration;
  final int? fixedDurationMinutes;
  final double hourlyRate;
  final int minimumGameCost;
  final int subtotalPiastres;
  final int discountPiastres;
  final int taxPiastres;
  final int totalPiastres;
  final int taxPercent;
  final int discountPercent;
  final String username;
  final String paymentType;
  final int? amountPaidPiastres;
  final SessionRecordStatus status;

  const SessionRecordEntity({
    required this.id,
    required this.shiftId,
    required this.stationId,
    required this.stationName,
    required this.parentCategory,
    required this.tier,
    this.startTime,
    this.endTime,
    this.durationMinutes = 0,
    this.wasFixedDuration = false,
    this.fixedDurationMinutes,
    this.hourlyRate = 0,
    this.minimumGameCost = 0,
    this.subtotalPiastres = 0,
    this.discountPiastres = 0,
    this.taxPiastres = 0,
    required this.totalPiastres,
    this.taxPercent = 0,
    this.discountPercent = 0,
    this.username = '',
    this.paymentType = 'cash',
    this.amountPaidPiastres,
    this.status = SessionRecordStatus.completed,
  });

  SessionRecordEntity copyWith({
    String? id,
    String? shiftId,
    String? stationId,
    String? stationName,
    String? parentCategory,
    SessionTier? tier,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    bool? wasFixedDuration,
    int? fixedDurationMinutes,
    double? hourlyRate,
    int? minimumGameCost,
    int? subtotalPiastres,
    int? discountPiastres,
    int? taxPiastres,
    int? totalPiastres,
    int? taxPercent,
    int? discountPercent,
    String? username,
    String? paymentType,
    int? amountPaidPiastres,
    SessionRecordStatus? status,
  }) {
    return SessionRecordEntity(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      parentCategory: parentCategory ?? this.parentCategory,
      tier: tier ?? this.tier,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      wasFixedDuration: wasFixedDuration ?? this.wasFixedDuration,
      fixedDurationMinutes: fixedDurationMinutes ?? this.fixedDurationMinutes,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      minimumGameCost: minimumGameCost ?? this.minimumGameCost,
      subtotalPiastres: subtotalPiastres ?? this.subtotalPiastres,
      discountPiastres: discountPiastres ?? this.discountPiastres,
      taxPiastres: taxPiastres ?? this.taxPiastres,
      totalPiastres: totalPiastres ?? this.totalPiastres,
      taxPercent: taxPercent ?? this.taxPercent,
      discountPercent: discountPercent ?? this.discountPercent,
      username: username ?? this.username,
      paymentType: paymentType ?? this.paymentType,
      amountPaidPiastres: amountPaidPiastres ?? this.amountPaidPiastres,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRecordEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          shiftId == other.shiftId &&
          stationId == other.stationId &&
          stationName == other.stationName &&
          parentCategory == other.parentCategory &&
          tier == other.tier &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          durationMinutes == other.durationMinutes &&
          wasFixedDuration == other.wasFixedDuration &&
          fixedDurationMinutes == other.fixedDurationMinutes &&
          hourlyRate == other.hourlyRate &&
          minimumGameCost == other.minimumGameCost &&
          subtotalPiastres == other.subtotalPiastres &&
          discountPiastres == other.discountPiastres &&
          taxPiastres == other.taxPiastres &&
          totalPiastres == other.totalPiastres &&
          taxPercent == other.taxPercent &&
          discountPercent == other.discountPercent &&
          username == other.username &&
          paymentType == other.paymentType &&
          amountPaidPiastres == other.amountPaidPiastres &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
    Object.hash(
      id,
      shiftId,
      stationId,
      stationName,
      parentCategory,
      tier,
      startTime,
      endTime,
      durationMinutes,
      wasFixedDuration,
      fixedDurationMinutes,
      hourlyRate,
      minimumGameCost,
      subtotalPiastres,
      discountPiastres,
      taxPiastres,
      totalPiastres,
      taxPercent,
      discountPercent,
    ),
    Object.hash(username, paymentType, amountPaidPiastres, status),
  );
}
