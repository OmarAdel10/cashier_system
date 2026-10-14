// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/backend/workers/api_client.dart';
import 'daily_sales.dart';

/// The 7-day sales trend (spec §2.4.2: area chart with gradient, EGP
/// tooltips, click → the analytics deep-dive is Phase 2).
class SalesChartView extends StatefulWidget {
  final Future<String?> Function() tokenProvider;
  final ApiClient? api;
  const SalesChartView({super.key, required this.tokenProvider, this.api});

  @override
  State<SalesChartView> createState() => _SalesChartViewState();
}

class _SalesChartViewState extends State<SalesChartView> {
  List<DailySales>? _buckets;
  bool _loading = true;
  String _errorAr = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // No leading setState: _load runs during initState and _loading is
    // already true — a synchronous setState here throws
    // 'setState during build' and kills the load (forever-spinner).
    final api = widget.api ?? ApiClient();
    try {
      // The token fetch is inside the try too: a throwing provider (e.g.
      // secure storage) must hit the same empty state, never a
      // forever-spinner.
      final token = await widget.tokenProvider();
      if (token == null) {
        // No session → the empty state (an infinite spinner would hang
        // pumpAndSettle in tests and never resolve for the user).
        if (mounted) {
          setState(() {
            _loading = false;
            _buckets = const [];
          });
        }
        return;
      }
      final now = DateTime.now();
      // The api's listSales filters with a strict `created_at > since`, so
      // the boundary sits one millisecond BEFORE the first bucketed day —
      // a sale at exactly midnight of day-6 stays inside the range (T27).
      final since =
          DateTime(now.year, now.month, now.day - 6).millisecondsSinceEpoch - 1;
      final res = await api.get(
        '/sales',
        idToken: token,
        query: {'since': '$since'},
      );
      final body = res.fold((_) => null, (b) => b);
      // Validate the structured `ok` flag — a 403/500 body must not render
      // as "no sales" (T25).
      if (body?['ok'] != true) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorAr = 'فشل تحميل المبيعات. حاول مجددًا.';
          });
        }
        return;
      }
      final salesJson = _salesOf(body);
      if (salesJson == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorAr = 'فشل تحميل المبيعات. حاول مجددًا.';
          });
        }
        return;
      }
      final buckets = bucketByDay(
        salesJson.map(SaleModel.fromJson).toList(),
        7,
        DateTime(now.year, now.month, now.day),
      );
      if (mounted) {
        setState(() {
          _buckets = buckets;
          _loading = false;
        });
      }
    } on Exception {
      // Classified failures (transport / malformed data) only; a
      // programming Error is not swallowed here.
      if (mounted) {
        setState(() {
          _loading = false;
          _errorAr = 'فشل تحميل المبيعات. حاول مجددًا.';
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _errorAr = '';
    });
    _load();
  }

  /// `data.sales` as an eagerly converted list of objects, or null when an
  /// element is malformed. A wrong outer shape stays empty data (as before);
  /// unlike `cast`, which is lazy and throws a TypeError (an Error, not an
  /// Exception) only once iterated — hanging the chart on its spinner — this
  /// conversion is total, so a malformed element is a surfaced error.
  List<Map<String, dynamic>>? _salesOf(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is! Map<String, dynamic>) return const [];
    final sales = data['sales'];
    if (sales is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final element in sales) {
      if (element is Map<String, dynamic>) {
        out.add(element);
      } else {
        return null;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAr.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorAr, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _retry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    final buckets = _buckets;
    if (buckets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (buckets.every((b) => b.totalPiastres == 0)) {
      return const Center(
        child: Text(
          'لا توجد مبيعات في آخر 7 أيام',
          textAlign: TextAlign.center,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مبيعات آخر 7 أيام',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          SizedBox(height: 320, child: LineChart(_chartData(buckets))),
        ],
      ),
    );
  }

  /// The memoized chart data — [build] can run on every parent rebuild, but
  /// the LineChartData only changes when a fresh bucket list is loaded (T27).
  LineChartData? _chartDataCache;
  List<DailySales>? _chartDataCacheKey;

  LineChartData _chartData(List<DailySales> buckets) {
    final cached = _chartDataCache;
    if (cached != null && identical(_chartDataCacheKey, buckets)) {
      return cached;
    }
    final data = _buildChartData(buckets);
    _chartDataCache = data;
    _chartDataCacheKey = buckets;
    return data;
  }

  LineChartData _buildChartData(List<DailySales> buckets) {
    final primary = const Color(0xFF007ACC);
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _yInterval(buckets),
        getDrawingHorizontalLine: (v) => const FlLine(
          color: Color(0x33E8E0D8),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
              final d = buckets[i].day;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${d.day}/${d.month}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: _yInterval(buckets),
            getTitlesWidget: (value, meta) => Text(
              (value / 100).toStringAsFixed(0),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1C1917),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < buckets.length; i++)
              FlSpot(i.toDouble(), buckets[i].totalPiastres.toDouble()),
          ],
          isCurved: true,
          barWidth: 2,
          color: primary,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primary.withValues(alpha: 0.4),
                primary.withValues(alpha: 0.05),
              ],
            ),
          ),
        ),
      ],
      minY: 0,
      maxY: _maxY(buckets),
    );
  }

  double _maxY(List<DailySales> buckets) {
    final max = buckets.fold<int>(
      0,
      (m, b) => b.totalPiastres > m ? b.totalPiastres : m,
    );
    return max * 1.2 + 100;
  }

  double _yInterval(List<DailySales> buckets) {
    final max = _maxY(buckets);
    return max <= 0 ? 1 : max / 4;
  }
}
