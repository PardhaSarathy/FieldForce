import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/theme/app_colors.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/business.dart';

/// Order money maths (§30, §86). These are the numbers a rep quotes a doctor
/// and a manager approves — a rounding or ordering mistake here is a
/// commercial problem, not a display bug.
void main() {
  OrderItem item({
    double rate = 100,
    int quantity = 10,
    double discount = 0,
    double gst = 12,
    int free = 0,
  }) {
    return OrderItem(
      productId: 'p-1',
      productName: 'Test Product',
      rate: rate,
      quantity: quantity,
      discountPercent: discount,
      gstPercent: gst,
      freeQuantity: free,
    );
  }

  Order orderWith(List<OrderItem> items) => Order(
        id: 'o-1',
        orderNumber: 'ORD-1',
        employeeId: 'e-1',
        employeeName: 'Test',
        clientId: 'c-1',
        clientName: 'Test Clinic',
        date: DateTime(2026, 8, 26),
        status: ApprovalStatus.draft,
        items: items,
      );

  group('OrderItem', () {
    test('gross is rate times quantity', () {
      expect(item(rate: 650, quantity: 10).gross, 6500);
    });

    test('applies discount before GST, not after', () {
      final line = item(rate: 100, quantity: 10, discount: 10, gst: 12);

      expect(line.gross, 1000);
      expect(line.discountAmount, 100);
      expect(line.taxable, 900);
      // GST is charged on 900, not on 1000.
      expect(line.gstAmount, closeTo(108, 0.001));
      expect(line.total, closeTo(1008, 0.001));
    });

    test('free-of-cost units never enter the gross', () {
      final withFree = item(rate: 100, quantity: 10, free: 2);
      final without = item(rate: 100, quantity: 10);

      expect(withFree.gross, without.gross);
      expect(withFree.total, without.total);
      // But they are still dispatched.
      expect(withFree.dispatchQuantity, 12);
      expect(without.dispatchQuantity, 10);
    });

    test('handles a zero discount cleanly', () {
      final line = item(rate: 195, quantity: 20, gst: 12);
      expect(line.discountAmount, 0);
      expect(line.taxable, line.gross);
      expect(line.total, closeTo(3900 * 1.12, 0.001));
    });

    test('handles a full discount without producing negative tax', () {
      final line = item(rate: 100, quantity: 5, discount: 100);
      expect(line.taxable, 0);
      expect(line.gstAmount, 0);
      expect(line.total, 0);
    });

    test('respects a per-product GST rate', () {
      final five = item(rate: 400, quantity: 10, gst: 5);
      final twelve = item(rate: 400, quantity: 10, gst: 12);

      expect(five.gstAmount, closeTo(200, 0.001));
      expect(twelve.gstAmount, closeTo(480, 0.001));
    });

    test('copyWith preserves untouched fields', () {
      final original = item(rate: 650, quantity: 10, discount: 5, gst: 12);
      final updated = original.copyWith(quantity: 20);

      expect(updated.quantity, 20);
      expect(updated.rate, 650);
      expect(updated.discountPercent, 5);
      expect(updated.gstPercent, 12);
      expect(updated.productId, original.productId);
    });
  });

  group('Order totals', () {
    test('sum across lines with different GST rates', () {
      final order = orderWith([
        item(rate: 650, quantity: 10, discount: 5, gst: 12),
        item(rate: 400, quantity: 4, gst: 5),
      ]);

      // Line 1: 6500 gross, 325 discount, 6175 taxable, 741 GST → 6916
      // Line 2: 1600 gross, 0 discount, 1600 taxable, 80 GST → 1680
      expect(order.subtotal, closeTo(8100, 0.001));
      expect(order.totalDiscount, closeTo(325, 0.001));
      expect(order.totalTaxable, closeTo(7775, 0.001));
      expect(order.totalGst, closeTo(821, 0.001));
      expect(order.grandTotal, closeTo(8596, 0.001));
    });

    test('grand total equals taxable plus GST', () {
      final order = orderWith([
        item(rate: 285, quantity: 7, discount: 7.5),
        item(rate: 160, quantity: 15, discount: 10),
        item(rate: 195, quantity: 3),
      ]);

      expect(
        order.grandTotal,
        closeTo(order.totalTaxable + order.totalGst, 0.001),
      );
    });

    test('subtotal minus discount equals taxable', () {
      final order = orderWith([
        item(rate: 650, quantity: 12, discount: 15),
        item(rate: 400, quantity: 8, discount: 5),
      ]);

      expect(
        order.totalTaxable,
        closeTo(order.subtotal - order.totalDiscount, 0.001),
      );
    });

    test('an empty order totals zero rather than throwing', () {
      final order = orderWith([]);

      expect(order.subtotal, 0);
      expect(order.grandTotal, 0);
      expect(order.lineCount, 0);
      expect(order.totalUnits, 0);
    });

    test('total units counts dispatched, including FOC', () {
      final order = orderWith([
        item(quantity: 10, free: 2),
        item(quantity: 5, free: 1),
      ]);

      expect(order.totalUnits, 18);
    });
  });

  group('Target achievement', () {
    test('computes achievement percentage', () {
      final target = Target(
        id: 't-1',
        employeeId: 'e-1',
        employeeName: 'Test',
        month: DateTime(2026, 8),
        targetAmount: 600000,
        achievedAmount: 450000,
      );

      expect(target.achievementPercent, closeTo(75, 0.001));
      expect(target.gap, closeTo(150000, 0.001));
      expect(target.tier, GameTier.ahead);
    });

    test('over-achievement is preserved, not clamped at 100', () {
      final target = Target(
        id: 't-2',
        employeeId: 'e-1',
        employeeName: 'Test',
        month: DateTime(2026, 8),
        targetAmount: 500000,
        achievedAmount: 625000,
      );

      expect(target.achievementPercent, closeTo(125, 0.001));
      // Gap cannot go negative — you cannot owe negative sales.
      expect(target.gap, 0);
      expect(target.tier, GameTier.met);
    });

    test('a zero target yields zero achievement rather than dividing by zero', () {
      final target = Target(
        id: 't-3',
        employeeId: 'e-1',
        employeeName: 'Test',
        month: DateTime(2026, 8),
        targetAmount: 0,
        achievedAmount: 100000,
      );

      expect(target.achievementPercent, 0);
      expect(target.achievementPercent.isNaN, isFalse);
      expect(target.achievementPercent.isInfinite, isFalse);
    });
  });
}
