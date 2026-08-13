import 'dart:convert';

import 'package:hive/hive.dart';

import 'audit_event.dart';

class AuditService {
  final LazyBox<String> _box;
  DateTime? _lastPrune;

  AuditService({required LazyBox<String> box}) : _box = box;

  Future<void> log(
    AuditEventType type, {
    String? username,
    required String details,
    bool success = true,
  }) async {
    final entry = AuditEntry(
      timestamp: DateTime.now(),
      type: type,
      username: username,
      details: details,
      success: success,
    );
    await _box.add(jsonEncode(entry.toJson()));
    await _pruneOld();
  }

  Future<List<AuditEntry>> getRecent({int limit = 100}) async {
    final entries = <AuditEntry>[];
    for (var i = _box.length - 1; i >= 0 && entries.length < limit; i--) {
      final entryJson = (await _box.getAt(i))!;
      entries.add(
        AuditEntry.fromJson(jsonDecode(entryJson) as Map<String, dynamic>),
      );
    }
    return entries;
  }

  Future<void> _pruneOld() async {
    final now = DateTime.now();
    if (_lastPrune != null && now.difference(_lastPrune!).inMinutes < 1) return;
    _lastPrune = now;
    final cutoff = now.subtract(const Duration(days: 90));
    final toDelete = <int>[];
    for (var i = 0; i < _box.length; i++) {
      final entryJson = (await _box.getAt(i))!;
      final entry = AuditEntry.fromJson(
        jsonDecode(entryJson) as Map<String, dynamic>,
      );
      if (entry.timestamp.isBefore(cutoff)) {
        toDelete.add(i);
      } else {
        break;
      }
    }
    for (final i in toDelete.reversed) {
      await _box.deleteAt(i);
    }
  }
}
