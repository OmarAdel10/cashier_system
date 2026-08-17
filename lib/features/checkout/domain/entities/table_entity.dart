enum TableStatus { available, occupied, orderPending, served, paymentPending }

class TableEntity {
  final String id;
  final String name;
  final String zoneId;
  final int capacity;
  final bool isRoom;
  final int hourlyRatePiastres;
  final TableStatus status;
  final DateTime? tabOpenedAt;
  final int? activeRoundNumber;

  const TableEntity({
    required this.id,
    required this.name,
    this.zoneId = '',
    this.capacity = 1,
    this.isRoom = false,
    this.hourlyRatePiastres = 0,
    this.status = TableStatus.available,
    this.tabOpenedAt,
    this.activeRoundNumber,
  });

  int get elapsedMinutes {
    final start = tabOpenedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inMinutes;
  }

  int get elapsedSeconds {
    final start = tabOpenedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds;
  }

  int get chargedHours {
    final hours = (elapsedMinutes / 60).ceil();
    return hours < 1 ? 1 : hours;
  }

  int get roomChargePiastres => chargedHours * hourlyRatePiastres;

  bool get isRoomEnabled => isRoom;

  static const _unset = Object();

  TableEntity copyWith({
    String? id,
    String? name,
    String? zoneId,
    int? capacity,
    bool? isRoom,
    int? hourlyRatePiastres,
    TableStatus? status,
    Object? tabOpenedAt = _unset,
    Object? activeRoundNumber = _unset,
  }) {
    return TableEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      zoneId: zoneId ?? this.zoneId,
      capacity: capacity ?? this.capacity,
      isRoom: isRoom ?? this.isRoom,
      hourlyRatePiastres: hourlyRatePiastres ?? this.hourlyRatePiastres,
      status: status ?? this.status,
      tabOpenedAt: identical(tabOpenedAt, _unset)
          ? this.tabOpenedAt
          : tabOpenedAt as DateTime?,
      activeRoundNumber: identical(activeRoundNumber, _unset)
          ? this.activeRoundNumber
          : activeRoundNumber as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          zoneId == other.zoneId &&
          capacity == other.capacity &&
          isRoom == other.isRoom &&
          hourlyRatePiastres == other.hourlyRatePiastres &&
          status == other.status &&
          tabOpenedAt == other.tabOpenedAt &&
          activeRoundNumber == other.activeRoundNumber;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    zoneId,
    capacity,
    isRoom,
    hourlyRatePiastres,
    status,
    tabOpenedAt,
    activeRoundNumber,
  );
}
