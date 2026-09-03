import '../../core/theme/app_colors.dart';
import '../enums/app_enums.dart';
import 'activity.dart';

/// A single product line on an order.
///
/// All money maths lives here rather than in the order form widget, so the
/// arithmetic is unit-testable and identical wherever an order is shown (§86).
///
/// Calculation order, which matters:
///   1. gross      = rate × quantity          (FOC units are free, excluded)
///   2. discount   = gross × discountPercent
///   3. taxable    = gross − discount
///   4. gst        = taxable × gstPercent
///   5. total      = taxable + gst
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.rate,
    required this.quantity,
    this.discountPercent = 0,
    this.gstPercent = 12,
    this.freeQuantity = 0,
    this.packSize,
  });

  final String productId;
  final String productName;
  final double rate;
  final int quantity;
  final double discountPercent;
  final double gstPercent;

  /// Free-of-cost units. Shipped but not charged, so they never enter the
  /// gross — a common source of billing errors if handled in the UI.
  final int freeQuantity;

  final String? packSize;

  double get gross => rate * quantity;
  double get discountAmount => gross * (discountPercent / 100);
  double get taxable => gross - discountAmount;
  double get gstAmount => taxable * (gstPercent / 100);
  double get total => taxable + gstAmount;

  /// Units actually dispatched.
  int get dispatchQuantity => quantity + freeQuantity;

  OrderItem copyWith({
    int? quantity,
    double? rate,
    double? discountPercent,
    double? gstPercent,
    int? freeQuantity,
  }) {
    return OrderItem(
      productId: productId,
      productName: productName,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
      discountPercent: discountPercent ?? this.discountPercent,
      gstPercent: gstPercent ?? this.gstPercent,
      freeQuantity: freeQuantity ?? this.freeQuantity,
      packSize: packSize,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.employeeId,
    required this.employeeName,
    required this.clientId,
    required this.clientName,
    required this.date,
    required this.status,
    this.items = const [],
    this.remarks,
    this.approvalHistory = const [],
    this.syncStatus = SyncStatus.synced,
    this.expectedDelivery,
  });

  final String id;
  final String orderNumber;
  final String employeeId;
  final String employeeName;
  final String clientId;
  final String clientName;
  final DateTime date;
  final ApprovalStatus status;
  final List<OrderItem> items;
  final String? remarks;
  final List<ApprovalEvent> approvalHistory;
  final SyncStatus syncStatus;
  final DateTime? expectedDelivery;

  double get subtotal => items.fold(0, (sum, i) => sum + i.gross);
  double get totalDiscount => items.fold(0, (sum, i) => sum + i.discountAmount);
  double get totalTaxable => items.fold(0, (sum, i) => sum + i.taxable);
  double get totalGst => items.fold(0, (sum, i) => sum + i.gstAmount);
  double get grandTotal => items.fold(0, (sum, i) => sum + i.total);

  int get lineCount => items.length;
  int get totalUnits => items.fold(0, (sum, i) => sum + i.dispatchQuantity);

  Order copyWith({
    ApprovalStatus? status,
    List<OrderItem>? items,
    List<ApprovalEvent>? approvalHistory,
    String? remarks,
    SyncStatus? syncStatus,
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      employeeId: employeeId,
      employeeName: employeeName,
      clientId: clientId,
      clientName: clientName,
      date: date,
      status: status ?? this.status,
      items: items ?? this.items,
      remarks: remarks ?? this.remarks,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      syncStatus: syncStatus ?? this.syncStatus,
      expectedDelivery: expectedDelivery,
    );
  }
}

/// Monthly sales figure for an employee (§28).
class SalesRecord {
  const SalesRecord({
    required this.month,
    required this.employeeId,
    required this.amount,
    this.primaryAmount = 0,
    this.secondaryAmount = 0,
    this.unitsSold = 0,
    this.productBreakup = const [],
  });

  final DateTime month;
  final String employeeId;
  final double amount;

  /// Company → stockist.
  final double primaryAmount;

  /// Stockist → retailer. The number that reflects real demand.
  final double secondaryAmount;

  final int unitsSold;
  final List<ProductSales> productBreakup;
}

class ProductSales {
  const ProductSales({
    required this.productId,
    required this.productName,
    required this.amount,
    this.units = 0,
    this.sharePercent = 0,
  });

  final String productId;
  final String productName;
  final double amount;
  final int units;
  final double sharePercent;
}

/// A sales target for one employee in one period (§29).
class Target {
  const Target({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.targetAmount,
    this.achievedAmount = 0,
    this.areaId,
    this.areaName,
    this.visitTarget = 0,
    this.visitsAchieved = 0,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime month;
  final double targetAmount;
  final double achievedAmount;
  final String? areaId;
  final String? areaName;
  final int visitTarget;
  final int visitsAchieved;

  double get gap => (targetAmount - achievedAmount).clamp(0, double.infinity);

  /// Achievement can exceed 100 — over-performance must stay visible.
  double get achievementPercent =>
      targetAmount <= 0 ? 0 : (achievedAmount / targetAmount) * 100;

  /// Where this target sits on the ladder. The same rungs Home uses, so a rep
  /// who is "Ahead" on Home is "Ahead" in Business rather than "warning".
  GameTier get tier => GameTier.of(achievementPercent);
}

/// A time-series point for the simple charts used in Business and Reports.
class ChartPoint {
  const ChartPoint({required this.label, required this.value, this.secondary});

  final String label;
  final double value;

  /// Optional comparison series (target vs actual, primary vs secondary).
  final double? secondary;
}
