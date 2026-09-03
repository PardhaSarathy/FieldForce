import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/client.dart';
import '../../../shared/widgets/approval_timeline.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

final _orderProvider = FutureProvider.autoDispose.family<Order, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(businessRepositoryProvider).orderById(id);
});

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_orderProvider(orderId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Order Detail')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (order) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(order.orderNumber, style: AppTypography.h3),
                      ),
                      StatusBadge.approval(order.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  KeyValueRow(label: 'Customer', value: order.clientName),
                  KeyValueRow(label: 'Raised by', value: order.employeeName),
                  KeyValueRow(label: 'Order date', value: Fmt.date(order.date)),
                  if (order.expectedDelivery != null)
                    KeyValueRow(
                      label: 'Expected delivery',
                      value: Fmt.date(order.expectedDelivery!),
                    ),
                  KeyValueRow(label: 'Remarks', value: order.remarks),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            const SectionHeader(title: 'Products'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < order.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _OrderLineRow(item: order.items[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            const SectionHeader(title: 'Summary'),
            OrderTotals(order: order),
            const SizedBox(height: AppSpacing.cardGap),

            const SectionHeader(title: 'Approval history'),
            ApprovalTimeline(events: order.approvalHistory),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName, style: AppTypography.titleSm),
              ),
              Text(Fmt.moneyPrecise(item.total), style: AppTypography.numeric),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                '${item.quantity} × ${Fmt.money(item.rate)}',
                style: AppTypography.caption,
              ),
              if (item.freeQuantity > 0)
                Text(
                  '+${item.freeQuantity} FOC',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                  ),
                ),
              if (item.discountPercent > 0)
                Text(
                  '${item.discountPercent.toStringAsFixed(1)}% off',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              Text(
                'GST ${item.gstPercent.round()}%',
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The money breakdown. Shown identically in the order form and the detail
/// screen so the number a rep quotes a doctor is the number that gets approved.
class OrderTotals extends StatelessWidget {
  const OrderTotals({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          KeyValueRow(
            label: 'Subtotal',
            value: Fmt.moneyPrecise(order.subtotal),
            dense: true,
          ),
          KeyValueRow(
            label: 'Discount',
            valueWidget: Text(
              '− ${Fmt.moneyPrecise(order.totalDiscount)}',
              style: AppTypography.numeric.copyWith(color: AppColors.warning),
            ),
            dense: true,
          ),
          KeyValueRow(
            label: 'Taxable value',
            value: Fmt.moneyPrecise(order.totalTaxable),
            dense: true,
          ),
          KeyValueRow(
            label: 'GST',
            value: Fmt.moneyPrecise(order.totalGst),
            dense: true,
          ),
          const AppDivider(),
          Row(
            children: [
              Expanded(child: Text('Total', style: AppTypography.titleMd)),
              Text(
                Fmt.moneyPrecise(order.grandTotal),
                style: AppTypography.metricSm.copyWith(color: AppColors.brand),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================== new order ==

final _orderClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(clientRepositoryProvider).list(session);
});

final _orderProductsProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(businessRepositoryProvider).products(),
);

/// Order capture (§30). Multiple lines, each with its own discount, FOC and
/// GST. Totals recompute live from [OrderItem] so the arithmetic is never
/// duplicated in the widget layer.
class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  Client? _client;
  final List<OrderItem> _items = [];
  final _remarks = TextEditingController();
  DateTime? _expectedDelivery;
  bool _submitting = false;
  Order? _created;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  /// Draft order used for live totals. Building a real [Order] rather than
  /// summing by hand guarantees the preview matches what gets submitted.
  Order get _draft => Order(
    id: 'draft',
    orderNumber: 'DRAFT',
    employeeId: '',
    employeeName: '',
    clientId: _client?.id ?? '',
    clientName: _client?.name ?? '',
    date: DateTime.now(),
    status: ApprovalStatus.draft,
    items: _items,
  );

  bool get _canSubmit => _client != null && _items.isNotEmpty;

  Future<void> _addProduct() async {
    final products = await ref.read(_orderProductsProvider.future);
    if (!mounted) return;

    final available = products
        .where((p) => !_items.any((i) => i.productId == p.id))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every product is already on this order.'),
        ),
      );
      return;
    }

    final picked = await showModalBottomSheet<Product>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: Row(
                children: [Text('Add product', style: AppTypography.h3)],
              ),
            ),
            for (final product in available)
              ListTile(
                title: Text(product.name, style: AppTypography.titleMd),
                subtitle: Text(
                  '${product.packSize ?? ''} · ${Fmt.money(product.mrp)} · '
                  'GST ${product.gstPercent.round()}%',
                  style: AppTypography.caption,
                ),
                onTap: () => Navigator.of(context).pop(product),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (picked == null) return;
    setState(() {
      _items.add(
        OrderItem(
          productId: picked.id,
          productName: picked.name,
          rate: picked.mrp,
          quantity: 10,
          gstPercent: picked.gstPercent,
          packSize: picked.packSize,
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    final order = Order(
      id: const Uuid().v4(),
      orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch % 100000}',
      employeeId: session.employee.id,
      employeeName: session.employee.name,
      clientId: _client!.id,
      clientName: _client!.name,
      date: DateTime.now(),
      status: ApprovalStatus.submitted,
      items: List.of(_items),
      remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      expectedDelivery: _expectedDelivery,
      syncStatus: ref.read(isOnlineProvider)
          ? SyncStatus.synced
          : SyncStatus.savedLocally,
    );

    await ref.read(businessRepositoryProvider).createOrder(order);
    if (!mounted) return;

    ref.bumpRevision();
    setState(() {
      _submitting = false;
      _created = order;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_created != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SuccessState(
            title: 'Order submitted',
            message: '${_created!.orderNumber} has been sent for approval.',
            details: AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Customer', value: _created!.clientName),
                  KeyValueRow(
                    label: 'Products',
                    value: '${_created!.lineCount}',
                  ),
                  KeyValueRow(
                    label: 'Total',
                    value: Fmt.moneyPrecise(_created!.grandTotal),
                  ),
                ],
              ),
            ),
            primaryLabel: 'View order',
            onPrimary: () =>
                context.pushReplacement(Routes.orderDetail(_created!.id)),
            secondaryLabel: 'Back to orders',
            onSecondary: () => context.go(Routes.orders),
          ),
        ),
      );
    }

    final clientsAsync = ref.watch(_orderClientsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('New Order')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: _items.isEmpty
                ? 'Submit'
                : 'Submit ${Fmt.money(_draft.grandTotal)}',
            isLoading: _submitting,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          clientsAsync.when(
            loading: () => const Skeleton(height: 48),
            error: (_, _) => const SizedBox.shrink(),
            data: (clients) => DropdownField<Client>(
              label: 'Customer',
              required: true,
              hint: 'Select a client',
              items: clients,
              value: _client,
              itemLabel: (c) => '${c.name} · ${c.areaName}',
              onChanged: (v) => setState(() => _client = v),
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          SectionHeader(
            title: 'Products',
            actionLabel: '+ Add product',
            onAction: _addProduct,
          ),

          if (_items.isEmpty)
            AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.inventory_2_outlined,
                title: 'No products added',
                message: 'Add at least one product to raise this order.',
                actionLabel: 'Add product',
                onAction: _addProduct,
              ),
            )
          else
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: _OrderLineEditor(
                  item: _items[i],
                  onChanged: (updated) => setState(() => _items[i] = updated),
                  onRemove: () => setState(() => _items.removeAt(i)),
                ),
              ),

          if (_items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            OrderTotals(order: _draft),
          ],

          const SizedBox(height: AppSpacing.section),
          DateField(
            label: 'Expected delivery',
            value: _expectedDelivery,
            firstDate: DateTime.now(),
            onChanged: (d) => setState(() => _expectedDelivery = d),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Remarks',
            controller: _remarks,
            maxLines: 2,
            hint: 'Delivery instructions, urgency…',
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _OrderLineEditor extends StatelessWidget {
  const _OrderLineEditor({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final OrderItem item;
  final ValueChanged<OrderItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: AppTypography.titleMd),
                    const SizedBox(height: 2),
                    Text(
                      '${item.packSize ?? ''} · ${Fmt.money(item.rate)} each',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppColors.error,
                onPressed: onRemove,
                tooltip: 'Remove',
              ),
            ],
          ),
          const AppDivider(),

          Row(
            children: [
              SizedBox(
                width: 92,
                child: Text('Quantity', style: AppTypography.bodySm),
              ),
              QuantityField(
                value: item.quantity,
                onChanged: (q) => onChanged(item.copyWith(quantity: q)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 92,
                child: Text('Free (FOC)', style: AppTypography.bodySm),
              ),
              QuantityField(
                value: item.freeQuantity,
                min: 0,
                onChanged: (q) => onChanged(item.copyWith(freeQuantity: q)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 92,
                child: Text('Discount', style: AppTypography.bodySm),
              ),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final pct in [0.0, 5.0, 7.5, 10.0, 15.0])
                      ChoiceChip(
                        label: Text(
                          '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%',
                        ),
                        selected: item.discountPercent == pct,
                        onSelected: (_) =>
                            onChanged(item.copyWith(discountPercent: pct)),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const AppDivider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'GST ${item.gstPercent.round()}% · '
                  '${item.dispatchQuantity} units dispatched',
                  style: AppTypography.caption,
                ),
              ),
              Text(Fmt.moneyPrecise(item.total), style: AppTypography.numeric),
            ],
          ),
        ],
      ),
    );
  }
}
