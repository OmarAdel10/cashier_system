import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../features/checkout/domain/entities/zone_entity.dart';
import 'business_type.dart';

class BusinessTypeRegistry {
  const BusinessTypeRegistry._();

  static const metadata = <BusinessType, ({IconData icon, String labelKey})>{
    BusinessType.retail: (
      icon: PhosphorIcons.storefront,
      labelKey: 'businessType.retail',
    ),
    BusinessType.supermarket: (
      icon: PhosphorIcons.shoppingCart,
      labelKey: 'businessType.supermarket',
    ),
    BusinessType.cafe: (
      icon: PhosphorIcons.coffee,
      labelKey: 'businessType.cafe',
    ),
    BusinessType.restaurant: (
      icon: PhosphorIcons.forkKnife,
      labelKey: 'businessType.restaurant',
    ),
    BusinessType.playstation: (
      icon: PhosphorIcons.gameController,
      labelKey: 'businessType.playstation',
    ),
  };

  static const defaultCategories = <BusinessType, List<String>>{
    BusinessType.cafe: [
      'hot drinks',
      'cold drinks',
      'soda',
      'juices',
      'desserts',
    ],
    BusinessType.restaurant: [
      'appetizers',
      'chicken',
      'beef',
      'burgers',
      'pizza',
      'sandwiches',
    ],
  };

  /// First-run zone presets for table billing modes. Admins manage zones
  /// afterwards; the box is seeded only while empty (mirrors categories).
  static const defaultZones = <BusinessType, List<ZoneEntity>>{
    BusinessType.cafe: [
      ZoneEntity(id: 'main-dining', name: 'Main Dining'),
      ZoneEntity(id: 'terrace', name: 'Terrace'),
      ZoneEntity(id: 'vip', name: 'VIP'),
      ZoneEntity(
        id: 'takeaway-queue',
        name: 'Takeaway Queue',
        kind: ZoneKind.takeaway,
      ),
    ],
    BusinessType.restaurant: [
      ZoneEntity(id: 'main-dining', name: 'Main Dining'),
      ZoneEntity(id: 'terrace', name: 'Terrace'),
      ZoneEntity(id: 'vip', name: 'VIP'),
      ZoneEntity(
        id: 'takeaway-queue',
        name: 'Takeaway Queue',
        kind: ZoneKind.takeaway,
      ),
    ],
  };
}
