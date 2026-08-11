import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../core/app_scope.dart';
import '../core/localization.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';

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
          ? Image.asset(AppAssets.logo, fit: BoxFit.cover)
          : Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: .13,
                  child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
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
      elevation: .5,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color ?? Theme.of(context).cardColor.withValues(alpha: .92),
      shadowColor: Colors.black.withValues(alpha: .14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
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
    this.onReportUnavailable,
    this.unavailableReported = false,
    this.highlighted = false,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onReportUnavailable;
  final bool unavailableReported;
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
                  product.isAvailable
                      ? ElevatedButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(tr(context, ar: 'أضف', en: 'Add')),
                        )
                      : onReportUnavailable == null
                          ? ElevatedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.block_rounded),
                              label: Text(tr(context,
                                  ar: 'غير متاح', en: 'Unavailable')),
                            )
                          : OutlinedButton.icon(
                              onPressed: unavailableReported
                                  ? null
                                  : onReportUnavailable,
                              icon: Icon(unavailableReported
                                  ? Icons.done_rounded
                                  : Icons.campaign_outlined),
                              label: Text(unavailableReported
                                  ? tr(context,
                                      ar: 'تم الإبلاغ', en: 'Reported')
                                  : tr(context,
                                      ar: 'إبلاغ المخزون',
                                      en: 'Notify inventory')),
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
  const StatusChip({super.key, required this.status, this.label});

  final OrderStatus status;
  final String? label;

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
        label ?? orderStatusLabel(context, status),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
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
              if (state.restaurant.address.isNotEmpty)
                _InfoPill(text: state.restaurant.address),
              if (state.restaurant
                  .todayHoursLabel(
                    closedLabel:
                        tr(context, ar: 'مغلق اليوم', en: 'Closed today'),
                  )
                  .isNotEmpty)
                _InfoPill(
                  text: state.restaurant.todayHoursLabel(
                    closedLabel:
                        tr(context, ar: 'مغلق اليوم', en: 'Closed today'),
                  ),
                ),
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
