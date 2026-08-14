import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/product_entity.dart';
import '../../../settings/data/services/localization_service.dart';

class BarcodeLabelTemplate extends StatelessWidget {
  final ProductEntity product;
  final String storeName;
  final String langCode;

  const BarcodeLabelTemplate({
    super.key,
    required this.product,
    required this.storeName,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = langCode == 'ar';
    final t = LocalizationService();
    final currency = isRtl
        ? t.translate('currency.symbol.ar', languageCode: langCode)
        : t.translate('currency.symbol.en', languageCode: langCode);
    final priceText = '${product.price.toStringAsFixed(2)} $currency';

    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (storeName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: product.barcode,
              width: 176,
              height: 40,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            product.notes,
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  priceText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
