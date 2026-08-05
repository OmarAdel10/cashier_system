import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
}
