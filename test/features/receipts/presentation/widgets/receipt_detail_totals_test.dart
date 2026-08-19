import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/receipt_detail_totals.dart';

import '../../../../helpers/default_receipt.dart';

Widget _wrap(ReceiptEntity receipt) {
  return MaterialApp(
    home: Scaffold(
      body: ReceiptDetailTotals(receipt: receipt, langCode: 'en'),
    ),
  );
}

void main() {
  group('ReceiptDetailTotals', () {
    testWidgets('shows payment type when amountPaid is null', (tester) async {
      final receipt = defaultReceipt(totalPiastres: 1000);
      expect(receipt.amountPaidPiastres, isNull);

      await tester.pumpWidget(_wrap(receipt));

      expect(find.text('Payment Type'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Paid'), findsNothing);
      expect(find.text('Change'), findsNothing);
    });

    testWidgets('shows paid and change when amountPaid is set', (tester) async {
      final receipt = defaultReceipt(
        totalPiastres: 1000,
      ).copyWith(amountPaidPiastres: 2000, paymentType: 'visa');

      await tester.pumpWidget(_wrap(receipt));

      expect(find.text('Payment Type'), findsOneWidget);
      expect(find.text('Visa'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('hides change when amountPaid equals total', (tester) async {
      final receipt = defaultReceipt(
        totalPiastres: 1000,
      ).copyWith(amountPaidPiastres: 1000);

      await tester.pumpWidget(_wrap(receipt));

      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Change'), findsNothing);
    });
  });
}
