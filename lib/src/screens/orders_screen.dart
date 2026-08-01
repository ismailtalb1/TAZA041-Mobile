import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class OrdersHistoryScreen extends StatelessWidget {
  const OrdersHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaShell(
      titleAr: 'الطلبات السابقة',
      titleEn: 'Previous orders',
      registered: true,
      showBack: true,
      body: RefreshIndicator(
        onRefresh: () => state.refreshCustomerData(),
        child: state.orders.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateCard(
                    icon: Icons.receipt_long_outlined,
                    titleAr: 'لا توجد طلبات بعد',
                    titleEn: 'No orders yet',
                    bodyAr: 'ابدأ طلبك الأول من المنيو.',
                    bodyEn: 'Start your first order from the menu.',
                    action: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.menu,
                        arguments:
                            const MenuRouteArgs(orderType: OrderType.ordinary),
                      ),
                      child:
                          Text(tr(context, ar: 'فتح المنيو', en: 'Open menu')),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _OrderCard(order: state.orders[index], state: state),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.state});

  final OrderRecord order;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(
              child: Text('#${order.id}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            StatusChip(status: order.status),
          ],
        ),
        subtitle: Text(
          '${orderTypeLabel(context, order.type)} • ${_dateLabel(order)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          const SizedBox(height: 10),
          _OrderTimeline(status: order.status),
          const SizedBox(height: 12),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(productName(context, item.product))),
                        Text(
                            '${item.quantity} × ${formatCurrency(item.product.price)}'),
                      ],
                    ),
                    if (item.canRate && item.product.referenceId != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: OutlinedButton.icon(
                          onPressed: () => _rateProduct(context, item),
                          icon: const Icon(Icons.star_outline_rounded),
                          label: Text(
                              tr(context, ar: 'تقييم الوجبة', en: 'Rate meal')),
                        ),
                      ),
                    ],
                  ],
                ),
              )),
          const Divider(),
          _line(context, tr(context, ar: 'طريقة الدفع', en: 'Payment'),
              paymentMethodLabel(context, order.paymentMethod)),
          if (order.deliveryAddress != null)
            _line(
                context,
                tr(context, ar: 'عنوان التوصيل', en: 'Delivery address'),
                order.deliveryAddress!),
          if (order.driver != null)
            _line(context, tr(context, ar: 'السائق', en: 'Driver'),
                driverName(context, order.driver!)),
          if (order.canRateDriver && order.deliveryId != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () => _rateDriver(context),
                icon: const Icon(Icons.delivery_dining_outlined),
                label: Text(tr(context,
                    ar: 'تقييم تجربة التوصيل', en: 'Rate delivery')),
              ),
            ),
          if (order.tableNumber != null)
            _line(context, tr(context, ar: 'الطاولة', en: 'Table'),
                '${order.isVipTable ? 'VIP' : tr(context, ar: 'عادية', en: 'Regular')} #${order.tableNumber}'),
          if (order.reservationTimeLabel != null)
            _line(context, tr(context, ar: 'الموعد', en: 'Time'),
                order.reservationTimeLabel!),
          const Divider(),
          _line(context, tr(context, ar: 'الإجمالي', en: 'Total'),
              formatCurrency(order.finalTotal),
              bold: true),
          if (order.canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancel(context),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(tr(context, ar: 'إلغاء الطلب', en: 'Cancel order')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(OrderRecord order) {
    final parsed = DateTime.tryParse(order.createdAtLabelAr);
    if (parsed == null) return order.createdAtLabelAr;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _line(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                  color: bold ? TazaColors.accent : null,
                )),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context,
            ar: 'إلغاء الطلب #${order.id}؟', en: 'Cancel order #${order.id}?')),
        content: Text(tr(context,
            ar: 'يمكن إلغاء الطلب المعلّق فقط، وسيبقى محفوظًا في السجل.',
            en: 'Only a pending order can be cancelled and remains in history.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, ar: 'تراجع', en: 'Back')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(context, ar: 'إلغاء الطلب', en: 'Cancel order')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await state.cancelOrder(order.id);
      if (context.mounted) {
        showMessage(
            context, tr(context, ar: 'تم إلغاء الطلب', en: 'Order cancelled'));
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }

  Future<void> _rateProduct(BuildContext context, CartItem item) async {
    final result = await _showRatingDialog(
      context,
      title: tr(context, ar: 'تقييم الوجبة', en: 'Rate meal'),
      hint: tr(context,
          ar: 'ما رأيك بالطعم أو التغليف؟',
          en: 'How was the taste or packaging?'),
    );
    if (result == null || !context.mounted) return;
    try {
      await state.rateProduct(
        orderId: order.id,
        productId: item.product.referenceId!,
        rating: result.rating,
        comment: result.comment,
      );
      if (context.mounted) {
        showMessage(context,
            tr(context, ar: 'شكراً على تقييم الوجبة', en: 'Thanks for rating'));
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }

  Future<void> _rateDriver(BuildContext context) async {
    final result = await _showRatingDialog(
      context,
      title: tr(context,
          ar: 'تقييم تجربة التوصيل', en: 'Rate delivery experience'),
      hint: tr(context, ar: 'ملاحظتك اختيارية', en: 'Optional feedback'),
    );
    if (result == null || !context.mounted) return;
    try {
      await state.rateDriver(
        deliveryId: order.deliveryId!,
        rating: result.rating,
        feedback: result.comment,
      );
      if (context.mounted) {
        showMessage(context,
            tr(context, ar: 'شكراً على تقييمك', en: 'Thanks for rating'));
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }
}

class _RatingResult {
  const _RatingResult(this.rating, this.comment);

  final int rating;
  final String comment;
}

Future<_RatingResult?> _showRatingDialog(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final comment = TextEditingController();
  var rating = 5;
  final result = await showDialog<_RatingResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: TazaColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(hintText: hint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr(context, ar: 'إلغاء', en: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _RatingResult(rating, comment.text),
            ),
            child: Text(tr(context, ar: 'إرسال', en: 'Send')),
          ),
        ],
      ),
    ),
  );
  comment.dispose();
  return result;
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final cancelled = status == OrderStatus.cancelled;
    final activeIndex = switch (status) {
      OrderStatus.pending => 0,
      OrderStatus.confirmed => 1,
      OrderStatus.inProgress => 2,
      OrderStatus.completed => 3,
      OrderStatus.cancelled => 0,
    };
    final labels = [
      tr(context, ar: 'استلام', en: 'Received'),
      tr(context, ar: 'تأكيد', en: 'Confirmed'),
      tr(context, ar: 'تجهيز', en: 'Preparing'),
      tr(context, ar: 'اكتمال', en: 'Done'),
    ];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = !cancelled && index <= activeIndex;
        return Expanded(
          child: Column(
            children: [
              Icon(
                cancelled && index == 0
                    ? Icons.cancel_rounded
                    : active
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                color: cancelled && index == 0
                    ? TazaColors.danger
                    : active
                        ? TazaColors.success
                        : Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 4),
              Text(labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        );
      }),
    );
  }
}
