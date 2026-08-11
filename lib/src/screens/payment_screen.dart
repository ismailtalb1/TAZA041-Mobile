import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../core/app_messenger.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _method = PaymentMethod.cash;

  Future<void> _pay() async {
    final state = AppStateScope.of(context);
    if (_method == PaymentMethod.loyaltyPoints &&
        state.currentUser.loyaltyPoints <
            state.requiredLoyaltyPoints(state.orderGrandTotal)) {
      showMessage(
          context,
          tr(context,
              ar: 'رصيد نقاطك غير كافٍ لإتمام الطلب',
              en: 'Your loyalty balance is not enough'));
      return;
    }
    try {
      await state.completeOrder(_method);
      if (!mounted) return;
      final successMessage = tr(context,
          ar: 'تم إنشاء الطلب وتأكيد طريقة الدفع بنجاح',
          en: 'Order and payment method confirmed successfully');
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.orders, (_) => false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppMessenger.show(successMessage);
      });
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final needed = state.requiredLoyaltyPoints(state.orderGrandTotal);
    if (state.cartItems.isEmpty) {
      return TazaShell(
        titleAr: 'الدفع',
        titleEn: 'Payment',
        registered: state.isAuthenticated,
        showBack: true,
        body: ListView(
          children: [
            EmptyStateCard(
              icon: Icons.remove_shopping_cart_outlined,
              titleAr: 'السلة فارغة',
              titleEn: 'Your cart is empty',
              bodyAr: 'أضف عناصر من المنيو قبل المتابعة للدفع.',
              bodyEn: 'Add items from the menu before payment.',
              action: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.menu,
                    arguments:
                        const MenuRouteArgs(orderType: OrderType.ordinary)),
                child: Text(tr(context, ar: 'فتح المنيو', en: 'Open menu')),
              ),
            ),
          ],
        ),
      );
    }
    return TazaShell(
      titleAr: 'الدفع',
      titleEn: 'Payment',
      registered: state.isAuthenticated,
      showBack: true,
      body: ListView(
        children: [
          const SectionHeader(
            titleAr: 'ملخص الطلب',
            titleEn: 'Order summary',
            subtitleAr: 'راجع العناصر والإجمالي قبل التأكيد.',
            subtitleEn: 'Review items and total before confirmation.',
          ),
          const SizedBox(height: 12),
          TazaCard(
            child: Column(
              children: [
                ...state.cartItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(productName(context, item.product))),
                          Text('${item.quantity} × '),
                          Text(formatCurrency(item.product.price)),
                        ],
                      ),
                    )),
                const Divider(),
                _line(context, tr(context, ar: 'نوع الطلب', en: 'Order type'),
                    orderTypeLabel(context, state.currentOrderType)),
                _line(context, tr(context, ar: 'العناصر', en: 'Items'),
                    formatCurrency(state.cartSubtotal)),
                if (state.deliveryCost > 0)
                  _line(context, tr(context, ar: 'التوصيل', en: 'Delivery'),
                      formatCurrency(state.deliveryCost)),
                if (state.reservationExtra > 0)
                  _line(context, tr(context, ar: 'الحجز', en: 'Reservation'),
                      formatCurrency(state.reservationExtra)),
                const Divider(),
                _line(
                    context,
                    tr(context, ar: 'الإجمالي النهائي', en: 'Grand total'),
                    formatCurrency(state.orderGrandTotal),
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(tr(context, ar: 'اختر وسيلة الدفع', en: 'Choose payment method'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: constraints.maxWidth < 330 ? 1 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth < 330 ? 1.25 : .68,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PaymentCard(
                    selected: _method == PaymentMethod.cash,
                    image: AppAssets.paymentCash,
                    title: tr(context, ar: 'الدفع النقدي', en: 'Cash payment'),
                    subtitle: tr(context,
                        ar: 'عند الاستلام أو في المطعم',
                        en: 'On delivery or at the restaurant'),
                    onTap: () => setState(() => _method = PaymentMethod.cash),
                  ),
                  _PaymentCard(
                    selected: _method == PaymentMethod.loyaltyPoints,
                    image: AppAssets.paymentLoyalty,
                    title: tr(context, ar: 'نقاط الولاء', en: 'Loyalty points'),
                    subtitle: tr(context,
                        ar: 'الرصيد ${state.currentUser.loyaltyPoints} / المطلوب $needed',
                        en: 'Balance ${state.currentUser.loyaltyPoints} / required $needed'),
                    onTap: () =>
                        setState(() => _method = PaymentMethod.loyaltyPoints),
                  ),
                  _PaymentCard(
                    selected: false,
                    enabled: false,
                    image: AppAssets.paymentSyriatel,
                    title: 'Syriatel Cash',
                    subtitle: tr(context,
                        ar: 'غير متاح حاليًا من الخادم',
                        en: 'Currently unavailable from the server'),
                    onTap: () {},
                  ),
                  _PaymentCard(
                    selected: false,
                    enabled: false,
                    image: AppAssets.paymentSham,
                    title: 'Sham Cash',
                    subtitle: tr(context,
                        ar: 'غير متاح حاليًا من الخادم',
                        en: 'Currently unavailable from the server'),
                    onTap: () {},
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TazaCard(
            color: (_method == PaymentMethod.cash
                    ? TazaColors.info
                    : state.currentUser.loyaltyPoints >= needed
                        ? TazaColors.success
                        : TazaColors.danger)
                .withValues(alpha: .11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _method == PaymentMethod.cash
                      ? Icons.info_outline_rounded
                      : Icons.loyalty_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _method == PaymentMethod.cash
                        ? tr(context,
                            ar:
                                'تُضاف نقاط الولاء بعد اكتمال الطلب وتأكيد الدفع النقدي.',
                            en:
                                'Loyalty points are added after order completion and cash confirmation.')
                        : state.currentUser.loyaltyPoints >= needed
                            ? tr(context,
                                ar: 'رصيدك كافٍ لإتمام الدفع بالنقاط.',
                                en:
                                    'Your balance is sufficient for points payment.')
                            : tr(context,
                                ar: 'رصيدك لا يكفي للدفع بالنقاط.',
                                en: 'Your balance is insufficient for points payment.'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isBusy ? null : _pay,
              icon: state.isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(tr(context,
                  ar: 'تأكيد الطلب والدفع', en: 'Confirm order and payment')),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                color: bold ? TazaColors.accent : null,
              )),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.selected,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final bool enabled;
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? TazaColors.accent
        : theme.colorScheme.outlineVariant.withValues(alpha: .65);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$title. $subtitle',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : .58,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: selected
                ? TazaColors.accent.withValues(alpha: .1)
                : theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: TazaColors.accent.withValues(alpha: .13),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            enabled
                                ? tr(context, ar: 'متاح', en: 'Available')
                                : tr(context, ar: 'قريباً', en: 'Coming soon'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: enabled
                                  ? TazaColors.success
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : enabled
                                    ? Icons.radio_button_unchecked_rounded
                                    : Icons.lock_clock_outlined,
                            key: ValueKey('$selected-$enabled'),
                            size: 21,
                            color: selected
                                ? TazaColors.accent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: .06),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          image,
                          fit: BoxFit.contain,
                          cacheWidth: 256,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            theme.textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
