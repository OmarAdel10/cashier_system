import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/features/checkout/data/models/app_zone_model.dart';
import 'package:cashier_system/features/checkout/data/repositories/zone_repository.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_zone_repository.dart';

void main() {
  late Box<AppZoneModel> box;
  late IZoneRepository repository;

  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppZoneModelAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<AppZoneModel>('test_zones');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('test_zones');
  });

  group('getZones seeding', () {
    test('empty box + cafe seeds presets and persists them', () async {
      repository = ZoneRepository(businessType: BusinessType.cafe, box: box);

      final result = await repository.getZones();
      final zones = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );

      final names = zones.map((z) => z.name).toList();
      expect(names, contains('Main Dining'));
      expect(names, contains('Takeaway Queue'));
      expect(box.get('main-dining'), isNotNull);
      expect(box.get('takeaway-queue')!.kind, ZoneKind.takeaway);
    });

    test('box already has data does not re-seed', () async {
      await box.put('custom', const AppZoneModel(id: 'custom', name: 'Custom'));
      repository = ZoneRepository(businessType: BusinessType.cafe, box: box);

      final result = await repository.getZones();
      final zones = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );

      expect(zones.map((z) => z.name).toList(), ['Custom']);
    });

    test('retail gets no seeded zones', () async {
      repository = ZoneRepository(businessType: BusinessType.retail, box: box);

      final result = await repository.getZones();
      final zones = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );

      expect(zones, isEmpty);
    });
  });

  group('saveZone / deleteZone', () {
    test('save and delete round-trip', () async {
      repository = ZoneRepository(businessType: BusinessType.cafe, box: box);

      await repository.saveZone(const ZoneEntity(id: 'roof', name: 'Roof'));
      expect(box.get('roof'), isNotNull);

      await repository.deleteZone('roof');
      expect(box.get('roof'), isNull);
    });
  });
}
