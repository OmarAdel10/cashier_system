class PriceHelper {
  PriceHelper._();

  static int fromDouble(double price) {
    return (price * 100).round();
  }

  static String format(int piastres) {
    final abs = piastres.abs();
    final pounds = abs ~/ 100;
    final fraction = abs % 100;
    final sign = piastres < 0 ? '-' : '';
    return 'EGP $sign$pounds.${fraction.toString().padLeft(2, '0')}';
  }
}
