enum StationType { playstation, table }

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
    return normalHourlyRate;
  }

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
    DateTime? sessionStartTime,
    bool? isFixedDuration,
    int? fixedDurationMinutes,
    int? overtimeStartMinutes,
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
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      isFixedDuration: isFixedDuration ?? this.isFixedDuration,
      fixedDurationMinutes: fixedDurationMinutes ?? this.fixedDurationMinutes,
      overtimeStartMinutes: overtimeStartMinutes ?? this.overtimeStartMinutes,
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
          overtimeStartMinutes == other.overtimeStartMinutes;

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
  );
}
