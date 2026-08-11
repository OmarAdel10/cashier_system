import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/core/business/business_type_registry.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';

void main() {
  group('ZoneEntity', () {
    test('creates with all fields', () {
      const zone = ZoneEntity(id: 'main-dining', name: 'Main Dining');
      expect(zone.id, 'main-dining');
      expect(zone.name, 'Main Dining');
      expect(zone.kind, ZoneKind.dineIn);
    });

    test('takeaway kind is selectable', () {
      const zone = ZoneEntity(
        id: 'takeaway-queue',
        name: 'Takeaway Queue',
        kind: ZoneKind.takeaway,
      );
      expect(zone.kind, ZoneKind.takeaway);
    });

    test('copyWith updates fields', () {
      const zone = ZoneEntity(id: 'main-dining', name: 'Main Dining');
      final updated = zone.copyWith(kind: ZoneKind.takeaway);
      expect(updated.kind, ZoneKind.takeaway);
      expect(updated.id, zone.id);
      expect(updated.name, zone.name);
    });

    test('equality and hashCode', () {
      const a = ZoneEntity(id: 'vip', name: 'VIP');
      const b = ZoneEntity(id: 'vip', name: 'VIP');
      const c = ZoneEntity(id: 'vip', name: 'VIP', kind: ZoneKind.takeaway);
      expect(a == b, true);
      expect(a.hashCode == b.hashCode, true);
      expect(a == c, false);
    });
  });

  group('BusinessTypeRegistry.defaultZones', () {
    test('table billing types have seeded zones', () {
      for (final type in BusinessType.values) {
        final zones = BusinessTypeRegistry.defaultZones[type] ?? const [];
        if (type.isTableBilling) {
          expect(zones, isNotEmpty);
          expect(zones.map((z) => z.kind).toSet(), contains(ZoneKind.dineIn));
        } else {
          expect(zones, isEmpty);
        }
      }
    });

    test('seeded zones include main dining and takeaway queue', () {
      final zones = BusinessTypeRegistry.defaultZones[BusinessType.cafe]!;
      expect(zones.any((z) => z.name == 'Main Dining'), isTrue);
      expect(
        zones.any(
          (z) => z.name == 'Takeaway Queue' && z.kind == ZoneKind.takeaway,
        ),
        isTrue,
      );
    });
  });
}
