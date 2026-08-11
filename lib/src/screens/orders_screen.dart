import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../core/app_constants.dart';
import '../app_state.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen>
    with WidgetsBindingObserver {
  AppState? _state;
  Timer? _liveTimer;
  bool _refreshing = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppStateScope.of(context);
    _liveTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshOrdersLive(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) _refreshOrdersLive();
  }

  Future<void> _refreshOrdersLive() async {
    if (_refreshing ||
        _lifecycleState != AppLifecycleState.resumed ||
        _state == null) {
      return;
    }
    _refreshing = true;
    try {
      await _state!.refreshOrdersLive();
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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

String _liveOrderStatusLabel(BuildContext context, OrderRecord order) {
  if (order.customerStatusLabelAr.isNotEmpty ||
      order.customerStatusLabelEn.isNotEmpty) {
    return tr(
      context,
      ar: order.customerStatusLabelAr.isEmpty
          ? order.customerStatusLabelEn
          : order.customerStatusLabelAr,
      en: order.customerStatusLabelEn.isEmpty
          ? order.customerStatusLabelAr
          : order.customerStatusLabelEn,
    );
  }
  if (order.type == OrderType.delivery) {
    return switch (order.deliveryStatus) {
      'pending' => tr(context, ar: 'بانتظار سائق', en: 'Awaiting driver'),
      'assigned' => tr(context, ar: 'تم تعيين السائق', en: 'Driver assigned'),
      'picked_up' =>
        tr(context, ar: 'استلم السائق الطلب', en: 'Picked up by driver'),
      'in_delivery' => tr(context, ar: 'في الطريق', en: 'On the way'),
      'delivered' => tr(context, ar: 'تم التسليم', en: 'Delivered'),
      'cancelled' => tr(context, ar: 'ملغي', en: 'Cancelled'),
      _ => orderStatusLabel(context, order.status),
    };
  }
  if (order.type == OrderType.reservation) {
    return switch (order.reservationStatus) {
      'pending' =>
        tr(context, ar: 'بانتظار التأكيد', en: 'Awaiting confirmation'),
      'confirmed' => tr(context, ar: 'الحجز مؤكد', en: 'Reservation confirmed'),
      'seated' => tr(context, ar: 'الجلسة قائمة', en: 'Table seated'),
      'completed' =>
        tr(context, ar: 'اكتمل الحجز', en: 'Reservation completed'),
      'no_show' => tr(context, ar: 'لم يحضر', en: 'No show'),
      'cancelled' => tr(context, ar: 'ملغي', en: 'Cancelled'),
      _ => orderStatusLabel(context, order.status),
    };
  }
  return orderStatusLabel(context, order.status);
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
            StatusChip(
              status: order.status,
              label: _liveOrderStatusLabel(context, order),
            ),
          ],
        ),
        subtitle: Text(
          '${orderTypeLabel(context, order.type)} • ${_dateLabel(order)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          const SizedBox(height: 10),
          _OrderTimeline(order: order),
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
          if (order.deliveryRouteGeometry.length > 1) ...[
            const SizedBox(height: 10),
            _DeliveryRouteMap(order: order),
          ],
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _reorder(context),
              icon: const Icon(Icons.replay_rounded),
              label: Text(tr(context, ar: 'إعادة الطلب', en: 'Reorder')),
            ),
          ),
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

  Future<void> _reorder(BuildContext context) async {
    try {
      final type = await state.prepareReorder(order.id);
      if (!context.mounted) return;
      final route = switch (type) {
        OrderType.delivery => AppRoutes.delivery,
        OrderType.reservation => AppRoutes.reservation,
        OrderType.ordinary => AppRoutes.menu,
      };
      final arguments = type == OrderType.ordinary
          ? const MenuRouteArgs(orderType: OrderType.ordinary)
          : null;
      await Navigator.pushNamed(context, route, arguments: arguments);
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
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
      final refund = await state.cancelOrder(order.id);
      if (context.mounted) {
        showMessage(context, _cancellationMessage(context, refund));
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }

  String _cancellationMessage(
      BuildContext context, Map<String, dynamic> refund) {
    final restored = (refund['loyalty_points_restored'] as num?)?.toInt() ?? 0;
    final reversed = (refund['loyalty_points_reversed'] as num?)?.toInt() ?? 0;
    final money = (refund['money_refunded'] as num?)?.toDouble() ?? 0;
    if (restored > 0) {
      return tr(context,
          ar: 'تم إلغاء الطلب وإعادة $restored نقطة إلى رصيدك',
          en: 'Order cancelled and $restored points were returned');
    }
    if (money > 0) {
      final amount =
          money.toStringAsFixed(money.truncateToDouble() == money ? 0 : 2);
      final currency = '${refund['currency'] ?? ''}'.trim();
      return tr(context,
          ar: 'تم إلغاء الطلب وتسوية مبلغ $amount $currency',
          en: 'Order cancelled and $amount $currency was refunded');
    }
    if (refund['kind'] == 'test_payment') {
      return tr(context,
          ar: 'تم إلغاء الدفع الاختباري وعكس نقاط المكافأة',
          en: 'Test payment cancelled and reward points reversed');
    }
    if (refund['kind'] == 'uncollected_cash') {
      return tr(context,
          ar: 'تم إلغاء الطلب، ولم يتم تحصيل أي مبلغ نقدي',
          en: 'Order cancelled; no cash was collected');
    }
    if (reversed > 0) {
      return tr(context,
          ar: 'تم الإلغاء وعكس $reversed نقطة مكتسبة من الطلب',
          en: 'Order cancelled and $reversed earned points were reversed');
    }
    return tr(context,
        ar: 'تم إلغاء الطلب وتسوية الدفع بنجاح',
        en: 'Order cancelled and payment settled successfully');
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

class _DeliveryRouteMap extends StatelessWidget {
  const _DeliveryRouteMap({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final points = order.deliveryRouteGeometry
        .where((point) => point.length >= 2)
        .map((point) => LatLng(point[1], point[0]))
        .toList(growable: false);
    if (points.length < 2) return const SizedBox.shrink();
    final fallback = order.deliveryRouteIsFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(fallback ? Icons.warning_amber_rounded : Icons.route_rounded,
                color: fallback ? TazaColors.accent : TazaColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fallback
                    ? tr(context,
                        ar: 'تقدير احتياطي للمسار',
                        en: 'Fallback route estimate')
                    : tr(context,
                        ar: 'مسار التوصيل المعتمد',
                        en: 'Assigned delivery route'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (order.deliveryDurationMinutes != null)
              Text(
                  '${order.deliveryDurationMinutes} ${tr(context, ar: 'د', en: 'min')}'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 230,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 13,
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(28),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: ApiConfig.mapTileUrl,
                  userAgentPackageName: AppConstants.mapUserAgent,
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 5,
                      color: fallback ? TazaColors.accent : TazaColors.info,
                    ),
                  ],
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: points.first,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.restaurant_rounded,
                        color: TazaColors.danger, size: 32),
                  ),
                  Marker(
                    point: points.last,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin,
                        color: TazaColors.info, size: 36),
                  ),
                ]),
                const RichAttributionWidget(attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
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
  const _OrderTimeline({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final hasUnifiedTimeline = order.timelineSteps.isNotEmpty;
    final cancelled = hasUnifiedTimeline
        ? order.customerStatusCancelled
        : order.status == OrderStatus.cancelled;
    final activeIndex = hasUnifiedTimeline
        ? order.timelineIndex
        : switch (order.status) {
            OrderStatus.pending => 0,
            OrderStatus.confirmed => 1,
            OrderStatus.inProgress => 2,
            OrderStatus.completed => 3,
            OrderStatus.cancelled => 0,
          };
    final labels = hasUnifiedTimeline
        ? order.timelineSteps
            .map((step) => tr(context, ar: step.labelAr, en: step.labelEn))
            .toList(growable: false)
        : [
            tr(context, ar: 'استلام', en: 'Received'),
            tr(context, ar: 'تأكيد', en: 'Confirmed'),
            tr(context, ar: 'تجهيز', en: 'Preparing'),
            tr(context, ar: 'اكتمال', en: 'Done'),
          ];
    Widget cell(int index) {
      final active = !cancelled && index <= activeIndex;
      return Column(
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
          Text(
            labels[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      );
    }

    if (labels.length <= 4) {
      return Row(
        children: List.generate(
          labels.length,
          (index) => Expanded(child: cell(index)),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          labels.length,
          (index) => SizedBox(
            width: 96,
            child: cell(index),
          ),
        ),
      ),
    );
  }
}
