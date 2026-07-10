class PriceHelper {
  PriceHelper._();

  static int fromDouble(double price) {
    return (price * 100).round();
  }

  static String format(int piastres, {String languageCode = 'en'}) {
    final abs = piastres.abs();
    final pounds = abs ~/ 100;
    final fraction = abs % 100;
    final sign = piastres < 0 ? '-' : '';
    final value = '$sign$pounds.${fraction.toString().padLeft(2, '0')}';
    if (languageCode == 'ar') return '$value ج.م';
    return 'EGP $value';
  }
}
