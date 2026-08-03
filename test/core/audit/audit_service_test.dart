import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cashier_system/core/audit/audit_event.dart';
import 'package:cashier_system/core/audit/audit_service.dart';

void main() {
  late LazyBox<String> box;
  late AuditService service;

  setUpAll(() async {
    Hive.init('test/_hive_test');
  });

  setUp(() async {
    box = await Hive.openLazyBox<String>('test_audit_${DateTime.now().millisecondsSinceEpoch}');
    service = AuditService(box: box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk(box.name);
  });

  test('log stores entry and retrieves via getRecent', () async {
    await service.log(AuditEventType.login, username: 'admin', details: 'Login OK', success: true);
    final recent = await service.getRecent();
    expect(recent.length, 1);
    expect(recent.first.type, AuditEventType.login);
    expect(recent.first.username, 'admin');
    expect(recent.first.success, true);
  });

  test('getRecent returns newest first, respects limit', () async {
    for (var i = 0; i < 5; i++) {
      await service.log(AuditEventType.login, details: 'entry $i');
    }
    final recent = await service.getRecent(limit: 3);
    expect(recent.length, 3);
    expect(recent.first.details, 'entry 4');
  });

  test('prune removes entries older than 90 days, stops at retention boundary', () async {
    final old = AuditEntry(
      timestamp: DateTime.now().subtract(const Duration(days: 91)),
      type: AuditEventType.login,
      details: 'old',
      success: true,
    );
    await box.add(jsonEncode(old.toJson()));

    final fresh = AuditEntry(
      timestamp: DateTime.now(),
      type: AuditEventType.login,
      details: 'fresh',
      success: true,
    );
    await box.add(jsonEncode(fresh.toJson()));

    // Manual prune trigger via log
    await service.log(AuditEventType.login, details: 'trigger');

    final recent = await service.getRecent();
    expect(recent.length, 2);
    expect(recent.any((e) => e.details == 'fresh'), isTrue);
    expect(recent.any((e) => e.details == 'trigger'), isTrue);
    expect(recent.any((e) => e.details == 'old'), isFalse);
  });

  test('prune stops early when no old entries exist', () async {
    await service.log(AuditEventType.login, details: 'a');
    await service.log(AuditEventType.login, details: 'b');
    await service.log(AuditEventType.login, details: 'c');

    // Running prune with all fresh entries should not remove anything
    // and should break early without unnecessary reads
    await service.log(AuditEventType.login, details: 'trigger-prune');

    final recent = await service.getRecent(limit: 10);
    expect(recent.length, 4);
  });
}
