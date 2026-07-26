import 'dart:convert';

import 'package:hive/hive.dart';

import 'audit_event.dart';

class AuditService {
  final Box<String> _box;

  AuditService({required Box<String> box}) : _box = box;

  Future<void> log(AuditEventType type, {
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
      entries.add(AuditEntry.fromJson(
        jsonDecode(_box.getAt(i)!) as Map<String, dynamic>,
      ));
    }
    return entries;
  }

  Future<void> _pruneOld() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    for (var i = _box.length - 1; i >= 0; i--) {
      final entry = AuditEntry.fromJson(
        jsonDecode(_box.getAt(i)!) as Map<String, dynamic>,
      );
      if (entry.timestamp.isBefore(cutoff)) {
        await _box.deleteAt(i);
      }
    }
  }
}
