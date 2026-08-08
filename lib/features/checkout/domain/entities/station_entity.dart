enum StationType { playstation, table }

enum PricingTier { normal, multi }

enum StationStatus { available, active, overtime }

class StationEntity {
  final String id;
  final String name;
  final String parentCategory;
  final StationType stationType;
  final double normalHourlyRate;
  final double multiHourlyRate;
  final int minimumGameCostNormal;
  final int minimumGameCostMulti;
  final String iconAsset;
  final StationStatus status;
  final DateTime? sessionStartTime;
  final bool isFixedDuration;
  final int? fixedDurationMinutes;
  final int? overtimeStartMinutes;
  final PricingTier? sessionTier;

  const StationEntity({
    required this.id,
    required this.name,
    required this.parentCategory,
    required this.stationType,
    required this.normalHourlyRate,
    required this.multiHourlyRate,
    required this.minimumGameCostNormal,
    required this.minimumGameCostMulti,
    required this.iconAsset,
    this.status = StationStatus.available,
    this.sessionStartTime,
    this.isFixedDuration = false,
    this.fixedDurationMinutes,
    this.overtimeStartMinutes,
    this.sessionTier,
  });

  int get elapsedMinutes {
    final start = sessionStartTime;
    if (start == null) return 0;
    return DateTime.now().difference(start).inMinutes;
  }

  int get currentTotalPiastres {
    if (sessionStartTime == null || status == StationStatus.available) {
      return 0;
    }
    final rate = _activeHourlyRate;
    final minutes = elapsedMinutes;
    return ((rate / 60) * minutes * 100).round();
  }

  double get _activeHourlyRate {
    if (sessionTier == PricingTier.multi) return multiHourlyRate;
    return normalHourlyRate;
  }

  static const _unset = Object();

  StationEntity copyWith({
    String? id,
    String? name,
    String? parentCategory,
    StationType? stationType,
    double? normalHourlyRate,
    double? multiHourlyRate,
    int? minimumGameCostNormal,
    int? minimumGameCostMulti,
    String? iconAsset,
    StationStatus? status,
    Object? sessionStartTime = _unset,
    bool? isFixedDuration,
    Object? fixedDurationMinutes = _unset,
    Object? overtimeStartMinutes = _unset,
    Object? sessionTier = _unset,
  }) {
    return StationEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      parentCategory: parentCategory ?? this.parentCategory,
      stationType: stationType ?? this.stationType,
      normalHourlyRate: normalHourlyRate ?? this.normalHourlyRate,
      multiHourlyRate: multiHourlyRate ?? this.multiHourlyRate,
      minimumGameCostNormal:
          minimumGameCostNormal ?? this.minimumGameCostNormal,
      minimumGameCostMulti: minimumGameCostMulti ?? this.minimumGameCostMulti,
      iconAsset: iconAsset ?? this.iconAsset,
      status: status ?? this.status,
      sessionStartTime: identical(sessionStartTime, _unset)
          ? this.sessionStartTime
          : sessionStartTime as DateTime?,
      isFixedDuration: isFixedDuration ?? this.isFixedDuration,
      fixedDurationMinutes: identical(fixedDurationMinutes, _unset)
          ? this.fixedDurationMinutes
          : fixedDurationMinutes as int?,
      overtimeStartMinutes: identical(overtimeStartMinutes, _unset)
          ? this.overtimeStartMinutes
          : overtimeStartMinutes as int?,
      sessionTier: identical(sessionTier, _unset)
          ? this.sessionTier
          : sessionTier as PricingTier?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          parentCategory == other.parentCategory &&
          stationType == other.stationType &&
          normalHourlyRate == other.normalHourlyRate &&
          multiHourlyRate == other.multiHourlyRate &&
          minimumGameCostNormal == other.minimumGameCostNormal &&
          minimumGameCostMulti == other.minimumGameCostMulti &&
          iconAsset == other.iconAsset &&
          status == other.status &&
          sessionStartTime == other.sessionStartTime &&
          isFixedDuration == other.isFixedDuration &&
          fixedDurationMinutes == other.fixedDurationMinutes &&
          overtimeStartMinutes == other.overtimeStartMinutes &&
          sessionTier == other.sessionTier;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parentCategory,
    stationType,
    normalHourlyRate,
    multiHourlyRate,
    minimumGameCostNormal,
    minimumGameCostMulti,
    iconAsset,
    status,
    sessionStartTime,
    isFixedDuration,
    fixedDurationMinutes,
    overtimeStartMinutes,
    sessionTier,
  );
}
