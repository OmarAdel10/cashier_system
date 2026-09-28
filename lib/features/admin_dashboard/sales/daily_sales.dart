// Copyright (c) 2026 Daftari POS. All rights reserved.

library;

/// Sale model from the api worker's GET /sales response.
class SaleModel {
  final String id;
  final int totalPiastres;
  final int createdAt;

  const SaleModel({
    required this.id,
    required this.totalPiastres,
    required this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
    id: json['id']! as String,
    totalPiastres: (json['total_piastres'] as num?)?.toInt() ?? 0,
    createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  );
}

/// One day-bucket of sales for the trend chart.
class DailySales {
  final DateTime day;
  final int totalPiastres;
  final int count;

  const DailySales({
    required this.day,
    required this.totalPiastres,
    required this.count,
  });
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Pure mapper: buckets [sales] into [days] day-buckets ending on [today],
/// zero-filled for days without sales (the chart's 7-point X axis).
List<DailySales> bucketByDay(List<SaleModel> sales, int days, DateTime today) {
  final byDay = <String, DailySales>{};
  for (final s in sales) {
    final d = DateTime.fromMillisecondsSinceEpoch(s.createdAt);
    final key = _dayKey(d);
    final existing = byDay[key];
    byDay[key] = DailySales(
      day: DateTime(d.year, d.month, d.day),
      totalPiastres: (existing?.totalPiastres ?? 0) + s.totalPiastres,
      count: (existing?.count ?? 0) + 1,
    );
  }
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final day = DateTime(today.year, today.month, today.day - i);
        return byDay[_dayKey(day)] ??
            DailySales(day: day, totalPiastres: 0, count: 0);
      }(),
  ];
}
