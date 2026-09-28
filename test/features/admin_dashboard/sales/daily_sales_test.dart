// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/admin_dashboard/sales/daily_sales.dart';

void main() {
  final today = DateTime(2026, 9, 27);

  test('buckets sales into 7 zero-filled day-buckets', () {
    final buckets = bucketByDay(
      [
        SaleModel(
          id: '1',
          totalPiastres: 5000,
          createdAt: DateTime(2026, 9, 25, 10).millisecondsSinceEpoch,
        ),
        SaleModel(
          id: '2',
          totalPiastres: 3000,
          createdAt: DateTime(2026, 9, 25, 18).millisecondsSinceEpoch,
        ),
        SaleModel(
          id: '3',
          totalPiastres: 12000,
          createdAt: DateTime(2026, 9, 26, 12).millisecondsSinceEpoch,
        ),
      ],
      7,
      today,
    );
    expect(buckets, hasLength(7));
    expect(buckets[0]!.day, DateTime(2026, 9, 21)); // 6 days ago
    expect(buckets[0]!.totalPiastres, 0); // zero-filled
    expect(buckets[4]!.day, DateTime(2026, 9, 25));
    expect(buckets[4]!.totalPiastres, 8000); // 5000 + 3000 same day
    expect(buckets[4]!.count, 2);
    expect(buckets[5]!.totalPiastres, 12000);
    expect(buckets[6]!.day, DateTime(2026, 9, 27)); // today
    expect(buckets[6]!.totalPiastres, 0);
  });

  test('handles sales outside the window (ignored) and empty input', () {
    final buckets = bucketByDay(
      [
        SaleModel(
          id: '1',
          totalPiastres: 999,
          createdAt: DateTime(2026, 8, 1).millisecondsSinceEpoch,
        ),
      ],
      7,
      today,
    );
    expect(buckets.every((b) => b.totalPiastres == 0), isTrue);
    expect(bucketByDay(const [], 7, today), hasLength(7));
  });

  test('month boundaries roll correctly', () {
    final endOfMonth = DateTime(2026, 10, 1);
    final buckets = bucketByDay(
      [
        SaleModel(
          id: '1',
          totalPiastres: 100,
          createdAt: DateTime(2026, 9, 30, 23).millisecondsSinceEpoch,
        ),
      ],
      3,
      endOfMonth,
    );
    expect(buckets[0]!.day, DateTime(2026, 9, 29));
    expect(buckets[1]!.day, DateTime(2026, 9, 30));
    expect(buckets[1]!.totalPiastres, 100);
    expect(buckets[2]!.day, DateTime(2026, 10, 1));
  });

  test('SaleModel.fromJson is lenient on numerics and strict on the id', () {
    final sale = SaleModel.fromJson({'id': '9'});
    expect(sale.totalPiastres, 0); // missing total_piastres → 0
    expect(sale.createdAt, 0); // missing created_at → 0
    // Strict id: a non-String id throws (the widget's catch absorbs it
    // into the empty state).
    expect(() => SaleModel.fromJson({'id': 42}), throwsA(isA<TypeError>()));
  });
}
