import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'mock_data.dart';
import 'models.dart';
import 'router.dart';
import 'theme.dart';

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope(
      {super.key, required super.notifier, required super.child});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.notifier!;
  }
}

String tr(BuildContext context, {required String ar, required String en}) {
  return AppStateScope.of(context).language == AppLanguage.ar ? ar : en;
}

bool isArabic(BuildContext context) =>
    AppStateScope.of(context).language == AppLanguage.ar;

String productName(BuildContext context, Product product) =>
    isArabic(context) ? product.nameAr : product.nameEn;

String productDescription(BuildContext context, Product product) =>
    isArabic(context) ? product.descriptionAr : product.descriptionEn;

String driverName(BuildContext context, DriverProfile driver) =>
    isArabic(context) ? driver.nameAr : driver.nameEn;

String driverDescription(BuildContext context, DriverProfile driver) =>
    isArabic(context) ? driver.descriptionAr : driver.descriptionEn;

String notificationTitle(BuildContext context, NotificationItem item) =>
    isArabic(context) ? item.titleAr : item.titleEn;

String notificationMessage(BuildContext context, NotificationItem item) =>
    isArabic(context) ? item.messageAr : item.messageEn;

String notificationTime(BuildContext context, NotificationItem item) =>
    isArabic(context) ? item.timeLabelAr : item.timeLabelEn;

String orderTypeLabel(BuildContext context, OrderType type) {
  switch (type) {
    case OrderType.ordinary:
      return tr(context, ar: 'طلب عادي', en: 'Ordinary order');
    case OrderType.delivery:
      return tr(context, ar: 'طلب توصيل', en: 'Delivery order');
    case OrderType.reservation:
      return tr(context, ar: 'حجز طاولة', en: 'Table reservation');
  }
}

String orderStatusLabel(BuildContext context, OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return tr(context, ar: 'معلق', en: 'Pending');
    case OrderStatus.inProgress:
      return tr(context, ar: 'قيد التنفيذ', en: 'In progress');
    case OrderStatus.confirmed:
      return tr(context, ar: 'مؤكد', en: 'Confirmed');
    case OrderStatus.completed:
      return tr(context, ar: 'مكتمل', en: 'Completed');
    case OrderStatus.cancelled:
      return tr(context, ar: 'ملغي', en: 'Cancelled');
  }
}

String paymentMethodLabel(BuildContext context, PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return tr(context, ar: 'دفع نقدي', en: 'Cash');
    case PaymentMethod.syriatelCash:
      return 'Syriatel Cash';
    case PaymentMethod.shamCash:
      return 'Sham Cash';
    case PaymentMethod.loyaltyPoints:
      return tr(context, ar: 'نقاط الولاء', en: 'Loyalty points');
  }
}

Color statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return TazaColors.warning;
    case OrderStatus.inProgress:
      return TazaColors.info;
    case OrderStatus.confirmed:
    case OrderStatus.completed:
      return TazaColors.success;
    case OrderStatus.cancelled:
      return TazaColors.danger;
  }
}

String formatCurrency(num amount) => '${amount.toStringAsFixed(0)} SYP';

class ScreenBackground extends StatelessWidget {
  const ScreenBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final top = state.isDarkMode ? TazaColors.darkBg : TazaColors.lightBg;
    final bottom = state.isDarkMode ? TazaColors.darkBg2 : TazaColors.lightBg2;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            top,
            bottom,
            TazaColors.accent.withValues(alpha: state.isDarkMode ? .12 : .08),
          ],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class TazaShell extends StatelessWidget {
  const TazaShell({
    super.key,
    required this.titleAr,
    required this.titleEn,
    required this.body,
    this.registered = false,
    this.showBack = false,
    this.actions,
    this.bottomContent,
    this.padding = const EdgeInsets.all(20),
  });

  final String titleAr;
  final String titleEn;
  final Widget body;
  final bool registered;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottomContent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final adaptivePadding = screenWidth <= 360
        ? const EdgeInsets.all(12)
        : screenWidth <= 390
            ? const EdgeInsets.all(16)
            : padding;
    final state = AppStateScope.of(context);
    return Directionality(
      textDirection: isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: registered ? const TazaDrawer() : null,
        appBar: AppBar(
          toolbarHeight: 72,
          leading: showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => Navigator.maybePop(context),
                )
              : registered
                  ? Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    )
                  : null,
          titleSpacing: 4,
          title: _LogoTitle(compact: screenWidth < 410),
          actions: [
            if (registered && showBack)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ...?actions,
            IconButton(
              tooltip: state.isDarkMode
                  ? tr(context, ar: 'الوضع النهاري', en: 'Light mode')
                  : tr(context, ar: 'الوضع الليلي', en: 'Dark mode'),
              onPressed: state.toggleTheme,
              icon: Icon(state.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
            ),
            IconButton(
              tooltip: tr(context, ar: 'تغيير اللغة', en: 'Change language'),
              onPressed: state.toggleLanguage,
              icon: Text(
                state.language == AppLanguage.ar ? 'EN' : 'AR',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
        body: ScreenBackground(
          child: Padding(
            padding: adaptivePadding,
            child: body,
          ),
        ),
        bottomNavigationBar: registered
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bottomContent != null) bottomContent!,
                  const _MobileNavigation(),
                ],
              )
            : bottomContent,
      ),
    );
  }
}

class _LogoTitle extends StatelessWidget {
  const _LogoTitle({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        final state = AppStateScope.of(context);
        Navigator.pushNamedAndRemoveUntil(
          context,
          state.isAuthenticated ? AppRoutes.homeUser : AppRoutes.guestHome,
          (route) => false,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/taza041-logo.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('TAZA 041', maxLines: 1),
                  Text(
                    tr(context, ar: 'تجربة العميل', en: 'Customer Experience'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .65),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class UtilityBar extends StatelessWidget {
  const UtilityBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: .92),
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: state.toggleTheme,
              icon: Icon(state.isDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded),
              label: Text(state.isDarkMode
                  ? tr(context, ar: 'وضع ليلي', en: 'Dark mode')
                  : tr(context, ar: 'وضع نهاري', en: 'Day mode')),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: state.toggleLanguage,
              icon: const Icon(Icons.language_rounded),
              label: Text(
                  state.language == AppLanguage.ar ? 'AR / EN' : 'EN / AR'),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderBox extends StatelessWidget {
  const PlaceholderBox({
    super.key,
    required this.labelAr,
    required this.labelEn,
    this.height = 160,
    this.compact = false,
  });

  final String labelAr;
  final String labelEn;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isLogo =
        labelAr.contains('لوجو') || labelEn.toLowerCase().contains('logo');
    return Container(
      height: compact ? null : height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 14 : 24),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .55),
        border: Border.all(
            color: Theme.of(context).dividerColor, style: BorderStyle.solid),
      ),
      clipBehavior: Clip.antiAlias,
      child: isLogo
          ? Image.asset('assets/images/taza041-logo.jpg', fit: BoxFit.cover)
          : Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: .13,
                  child: Image.asset('assets/images/taza041-logo.jpg',
                      fit: BoxFit.cover),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TazaColors.accent.withValues(alpha: .16),
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: .78),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      tr(context, ar: labelAr, en: labelEn),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .72),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {super.key,
      required this.titleAr,
      required this.titleEn,
      this.subtitleAr,
      this.subtitleEn,
      this.trailing});

  final String titleAr;
  final String titleEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, ar: titleAr, en: titleEn),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitleAr != null && subtitleEn != null) ...[
                const SizedBox(height: 6),
                Text(
                  tr(context, ar: subtitleAr!, en: subtitleEn!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .65),
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class TazaCard extends StatelessWidget {
  const TazaCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.onTap,
      this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color ?? Theme.of(context).cardColor.withValues(alpha: .92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class HeroMessageCard extends StatelessWidget {
  const HeroMessageCard({
    super.key,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    this.primary,
    this.secondary,
    this.visual,
  });

  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final Widget? primary;
  final Widget? secondary;
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, ar: titleAr, en: titleEn),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            tr(context, ar: bodyAr, en: bodyEn),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .72),
                ),
          ),
          if (visual != null) ...[
            const SizedBox(height: 18),
            visual!,
          ],
          if (primary != null || secondary != null) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, children: [
              if (primary != null) primary!,
              if (secondary != null) secondary!
            ]),
          ],
        ],
      ),
    );
  }
}

class OrderTypeActionCard extends StatelessWidget {
  const OrderTypeActionCard(
      {super.key,
      required this.icon,
      required this.titleAr,
      required this.titleEn,
      required this.bodyAr,
      required this.bodyEn,
      required this.onTap});

  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width * .72).clamp(220.0, 280.0),
      child: TazaCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: TazaColors.accent.withValues(alpha: .18),
                child: Icon(icon, color: TazaColors.accent)),
            const SizedBox(height: 18),
            Text(tr(context, ar: titleAr, en: titleEn),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              tr(context, ar: bodyAr, en: bodyEn),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .65)),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.onOpenMenu,
    this.highlighted = false,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onOpenMenu;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width * .76).clamp(250.0, 300.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              highlighted ? TazaColors.accent : Theme.of(context).dividerColor,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: TazaCard(
        padding: const EdgeInsets.all(14),
        onTap: onOpenMenu,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TazaImage(
              imageUrl: product.imageUrl,
              labelAr: product.placeholderLabel ?? 'صورة المنتج',
              labelEn: product.placeholderLabel ?? 'Product image',
              height: 120,
            ),
            const SizedBox(height: 12),
            Text(productName(context, product),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              productDescription(context, product),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .65)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: TazaColors.warning, size: 18),
                const SizedBox(width: 4),
                Text(
                    '${product.rating.toStringAsFixed(1)} (${product.ratingCount})'),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.oldPrice != null)
                      Text(
                        formatCurrency(product.oldPrice!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .5),
                            ),
                      ),
                    Text(formatCurrency(product.price),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: TazaColors.accent)),
                  ],
                ),
                const Spacer(),
                if (quantity > 0)
                  Row(
                    children: [
                      IconButton(
                          onPressed: onRemove,
                          icon:
                              const Icon(Icons.remove_circle_outline_rounded)),
                      Text('$quantity',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      IconButton(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_circle_rounded,
                              color: TazaColors.accent)),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: product.isAvailable ? onAdd : null,
                    icon: Icon(product.isAvailable
                        ? Icons.add_rounded
                        : Icons.block_rounded),
                    label: Text(product.isAvailable
                        ? tr(context, ar: 'أضف', en: 'Add')
                        : tr(context, ar: 'غير متاح', en: 'Unavailable')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CartSummaryCard extends StatelessWidget {
  const CartSummaryCard({
    super.key,
    required this.onCheckout,
    this.extraLines = const <Widget>[],
  });

  final VoidCallback onCheckout;
  final List<Widget> extraLines;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TazaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(tr(context, ar: 'السلة', en: 'Cart'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  CircleAvatar(
                      radius: 16,
                      backgroundColor: TazaColors.accent.withValues(alpha: .2),
                      child: Text('${state.cartCount}',
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 12),
              if (state.cartItems.isEmpty)
                Text(tr(context,
                    ar: 'لا توجد منتجات في السلة بعد.',
                    en: 'No products in the cart yet.'))
              else
                Column(
                  children: state.cartItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                  child:
                                      Text(productName(context, item.product))),
                              Text('x${item.quantity}'),
                              const SizedBox(width: 12),
                              Text(formatCurrency(item.subtotal)),
                              IconButton(
                                onPressed: () =>
                                    state.removeFromCart(item.product.id),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ...extraLines,
              const Divider(),
              Row(
                children: [
                  Text(tr(context, ar: 'الإجمالي', en: 'Total'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(formatCurrency(state.orderGrandTotal),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: TazaColors.accent)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.cartItems.isEmpty ? null : onCheckout,
                  child: Text(
                      tr(context, ar: 'متابعة الطلب', en: 'Continue order')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: .16),
      ),
      child: Text(
        orderStatusLabel(context, status),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class TazaDrawer extends StatelessWidget {
  const TazaDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = [
      (
        icon: Icons.notifications_none_rounded,
        labelAr: 'الإشعارات',
        labelEn: 'Notifications',
        route: AppRoutes.notifications
      ),
      (
        icon: Icons.person_outline_rounded,
        labelAr: 'إعداد الحساب الشخصي',
        labelEn: 'Profile settings',
        route: AppRoutes.profile
      ),
      (
        icon: Icons.receipt_long_rounded,
        labelAr: 'الطلبات السابقة',
        labelEn: 'Previous orders',
        route: AppRoutes.orders
      ),
      (
        icon: Icons.smart_toy_outlined,
        labelAr: 'اقتراح وجبة',
        labelEn: 'Suggest a meal',
        route: AppRoutes.aiSuggestion
      ),
    ];

    return Drawer(
      child: ScreenBackground(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [TazaColors.accent, TazaColors.accent2]),
              ),
              currentAccountPicture: const CircleAvatar(
                child: Text('T', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              accountName: Text(state.currentUser.fullName),
              accountEmail: Text(
                '${tr(context, ar: 'نقاط الولاء', en: 'Loyalty points')}: ${state.currentUser.loyaltyPoints}',
              ),
            ),
            ...items.map(
              (item) => ListTile(
                leading: Icon(item.icon),
                title: Text(tr(context, ar: item.labelAr, en: item.labelEn)),
                onTap: () {
                  Navigator.pop(context);
                  if (ModalRoute.of(context)?.settings.name != item.route) {
                    Navigator.pushNamed(context, item.route);
                  }
                },
              ),
            ),
            const Spacer(),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: TazaColors.danger),
              title: Text(tr(context, ar: 'تسجيل الخروج', en: 'Logout')),
              onTap: () async {
                await state.logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.guestHome, (_) => false);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation();

  @override
  Widget build(BuildContext context) {
    final current = ModalRoute.of(context)?.settings.name ?? AppRoutes.homeUser;
    final selectedIndex = switch (current) {
      AppRoutes.menu => 1,
      AppRoutes.orders => 2,
      AppRoutes.profile => 3,
      _ => 0,
    };
    return NavigationBar(
      selectedIndex: selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (index) {
        final route = switch (index) {
          1 => AppRoutes.menu,
          2 => AppRoutes.orders,
          3 => AppRoutes.profile,
          _ => AppRoutes.homeUser,
        };
        if (route == current) return;
        if (route == AppRoutes.homeUser) {
          Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
        } else if (route == AppRoutes.menu) {
          Navigator.pushNamed(
            context,
            route,
            arguments: const MenuRouteArgs(orderType: OrderType.ordinary),
          );
        } else {
          Navigator.pushNamed(context, route);
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: tr(context, ar: 'الرئيسية', en: 'Home'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.restaurant_menu_outlined),
          selectedIcon: const Icon(Icons.restaurant_menu_rounded),
          label: tr(context, ar: 'المنيو', en: 'Menu'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long_rounded),
          label: tr(context, ar: 'الطلبات', en: 'Orders'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded),
          label: tr(context, ar: 'الحساب', en: 'Profile'),
        ),
      ],
    );
  }
}

class AboutPreviewCard extends StatelessWidget {
  const AboutPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TazaImage(
            imageUrl: _restaurantHeroUrl(state.restaurantImages),
            labelAr: 'عن المطعم',
            labelEn: 'About restaurant',
            height: 160,
          ),
          const SizedBox(height: 14),
          Text(
              tr(
                context,
                ar: state.restaurant
                    .content('story_title_ar', 'TAZA 041 أقرب إليك'),
                en: state.restaurant
                    .content('story_title_en', 'TAZA 041 closer to you'),
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              ar: state.restaurant.content(
                'story_paragraph_one_ar',
                state.restaurant.about.isNotEmpty
                    ? state.restaurant.about
                    : 'مطعم حديث يقدم وجبات سريعة وعصرية بجودة عالية مع خدمة توصيل سريعة تناسب طلاب الجامعة وسكان المدينة.',
              ),
              en: state.restaurant.content(
                'story_paragraph_one_en',
                state.restaurant.about.isNotEmpty
                    ? state.restaurant.about
                    : 'A modern restaurant serving high-quality fast meals with delivery designed for students and city residents.',
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .65)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                  text: state.restaurant.address.isNotEmpty
                      ? state.restaurant.address
                      : tr(context,
                          ar: restaurantAddressAr, en: restaurantAddressEn)),
              _InfoPill(
                  text: tr(context,
                      ar: restaurantHoursAr, en: restaurantHoursEn)),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.about),
            child: Text(tr(context, ar: 'اعرف المزيد', en: 'Learn more')),
          ),
        ],
      ),
    );
  }
}

class TazaImage extends StatelessWidget {
  const TazaImage({
    super.key,
    required this.imageUrl,
    required this.labelAr,
    required this.labelEn,
    this.height = 160,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final String labelAr;
  final String labelEn;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: url.isEmpty
            ? PlaceholderBox(labelAr: labelAr, labelEn: labelEn, height: height)
            : CachedNetworkImage(
                imageUrl: url,
                fit: fit,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => PlaceholderBox(
                    labelAr: labelAr, labelEn: labelEn, height: height),
              ),
      ),
    );
  }
}

String? _restaurantHeroUrl(Map<String, dynamic> groups) {
  for (final value in groups.values) {
    if (value is List && value.isNotEmpty && value.first is Map) {
      final item = Map<String, dynamic>.from(value.first as Map);
      return (item['url'] ?? item['image_url'])?.toString();
    }
  }
  return null;
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .55),
      ),
      child: Text(text),
    );
  }
}
