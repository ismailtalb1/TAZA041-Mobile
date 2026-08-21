import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/catalog_search.dart';
import '../core/input_validation.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.args});

  final MenuRouteArgs args;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _search = TextEditingController();
  ProductCategory? _category;
  double _maxPrice = 1000;
  bool _availableOnly = false;
  bool _topRatedOnly = false;
  bool _offersOnly = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final state = AppStateScope.of(context);
    state.currentOrderType = widget.args.orderType;
    state.highlightedProductId = widget.args.highlightProductId;
    _initialized = true;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Product> _filtered(AppState state) {
    final query = _search.text.trim();
    final scoped = state.productsCatalog.where((item) {
      final matchesCategory = _offersOnly
          ? item.itemType == CatalogItemType.offer
          : (_category == null || item.category == _category);
      return matchesCategory &&
          item.price <= _maxPrice &&
          (!_availableOnly || item.isAvailable) &&
          (!_topRatedOnly || item.rating >= 4.5);
    }).toList();
    final result = CatalogSearch.rank(scoped, query)
        .map((match) => match.product)
        .toList(growable: false);
    if (query.isNotEmpty) return result;
    result.sort((a, b) {
      if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
      return a.nameAr.compareTo(b.nameAr);
    });
    return result;
  }

  String? _correction(AppState state, BuildContext context) {
    final query = _search.text.trim();
    if (query.length < 2) return null;
    final matches = CatalogSearch.rank(state.productsCatalog, query);
    return CatalogSearch.bestCorrection(
      matches,
      query,
      arabic: isArabic(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final products = _filtered(state);
    final correction = _correction(state, context);
    return TazaShell(
      titleAr: 'المنيو',
      titleEn: 'Menu',
      registered: state.isAuthenticated,
      showBack: true,
      actions: [
        _CartButton(onPressed: () => showCartSheet(context)),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await state.loadPublicData();
          } catch (error) {
            if (context.mounted) showApiError(context, error);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SectionHeader(
              titleAr: 'قائمة TAZA 041',
              titleEn: 'TAZA 041 menu',
              subtitleAr: 'ابحث وصفِّ النتائج ثم أضف العناصر إلى السلة.',
              subtitleEn: 'Search, filter, then add items to your cart.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              inputFormatters: CustomerInputValidation.limited(100),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
                hintText: tr(context,
                    ar: 'ابحث عن وجبة أو مشروب أو عرض',
                    en: 'Search meals, drinks, or offers'),
              ),
            ),
            if (correction != null) ...[
              const SizedBox(height: 5),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    _search.text = correction;
                    _search.selection =
                        TextSelection.collapsed(offset: correction.length);
                    setState(() {});
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                  label: Text(
                    '${tr(context, ar: 'هل تقصد؟', en: 'Did you mean?')} $correction',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TazaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(tr(context, ar: 'الكل', en: 'All')),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                        const SizedBox(width: 8),
                        ...ProductCategory.values.map((category) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(categoryLabel(context, category)),
                                selected: _category == category,
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${tr(context, ar: 'السعر الأقصى', en: 'Maximum price')}: ${formatCurrency(_maxPrice)}'),
                      ),
                      Switch.adaptive(
                        value: _availableOnly,
                        onChanged: (value) =>
                            setState(() => _availableOnly = value),
                      ),
                      Flexible(
                        child: Text(tr(context,
                            ar: 'المتاح فقط', en: 'Available only')),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maxPrice,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: formatCurrency(_maxPrice),
                    onChanged: (value) => setState(() => _maxPrice = value),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        selected: _topRatedOnly,
                        onSelected: (value) =>
                            setState(() => _topRatedOnly = value),
                        avatar:
                            const Icon(Icons.star_outline_rounded, size: 18),
                        label: Text(
                            tr(context, ar: 'الأعلى تقييماً', en: 'Top rated')),
                      ),
                      FilterChip(
                        selected: _offersOnly,
                        onSelected: (value) =>
                            setState(() => _offersOnly = value),
                        avatar:
                            const Icon(Icons.local_offer_outlined, size: 18),
                        label: Text(
                            tr(context, ar: 'العروض فقط', en: 'Offers only')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _OrderTypeSelector(state: state),
            const SizedBox(height: 20),
            if (products.isEmpty)
              const EmptyStateCard(
                icon: Icons.search_off_rounded,
                titleAr: 'لا توجد نتائج',
                titleEn: 'No results',
                bodyAr: 'غيّر البحث أو الفلاتر ثم حاول مجددًا.',
                bodyEn: 'Adjust the search or filters and try again.',
              )
            else
              ...ProductCategory.values.map((category) {
                final group = products
                    .where((item) => item.category == category)
                    .toList();
                if (group.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(categoryLabel(context, category),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 340,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: group.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final product = group[index];
                            final quantity = state.cartItems
                                .where((item) =>
                                    item.product.id == product.id &&
                                    item.product.itemType == product.itemType)
                                .fold(0, (sum, item) => sum + item.quantity);
                            return ProductTile(
                              product: product,
                              quantity: quantity,
                              highlighted:
                                  state.highlightedProductId == product.id,
                              onAdd: () {
                                if (!state.isAuthenticated) {
                                  showAuthRequiredSheet(context);
                                } else if (!product.isAvailable) {
                                  showMessage(
                                      context,
                                      tr(context,
                                          ar: 'هذا العنصر غير متاح حاليًا',
                                          en: 'This item is currently unavailable'));
                                } else {
                                  state.addToCart(product);
                                }
                              },
                              onRemove: () => state.decreaseFromCart(product),
                              unavailableReported:
                                  product.referenceId != null &&
                                      state.reportedUnavailableProductIds
                                          .contains(product.referenceId),
                              onReportUnavailable: !state.isAuthenticated ||
                                      product.itemType !=
                                          CatalogItemType.product ||
                                      product.referenceId == null
                                  ? null
                                  : () async {
                                      try {
                                        await state.reportUnavailable(product);
                                        if (context.mounted) {
                                          showMessage(
                                            context,
                                            tr(context,
                                                ar: 'تم إبلاغ مدير المخزون',
                                                en: 'Inventory manager notified'),
                                          );
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          showApiError(context, error);
                                        }
                                      }
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _OrderTypeSelector extends StatelessWidget {
  const _OrderTypeSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, ar: 'نوع الطلب الحالي', en: 'Current order type'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OrderType.values
                .map((type) => ChoiceChip(
                      label: Text(orderTypeLabel(context, type)),
                      selected: state.currentOrderType == type,
                      onSelected: (_) => state.setOrderType(type),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = AppStateScope.of(context).cartCount;
    return IconButton(
      tooltip: tr(context, ar: 'السلة', en: 'Cart'),
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

Future<void> showCartSheet(BuildContext context) {
  final state = AppStateScope.of(context);
  final notes = TextEditingController(text: state.orderNotes);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Directionality(
      textDirection: isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tr(context, ar: 'السلة', en: 'Cart'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text('${state.cartCount}'),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.cartItems.isEmpty)
                  Text(tr(context,
                      ar: 'السلة فارغة حاليًا', en: 'Your cart is empty'))
                else
                  ...state.cartItems.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(productName(context, item.product)),
                        subtitle: Text(
                            '${item.quantity} × ${formatCurrency(item.product.price)}'),
                        trailing: IconButton(
                          onPressed: () =>
                              state.removeFromCart(item.product.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      )),
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OrderType.values
                      .map((type) => ChoiceChip(
                            label: Text(orderTypeLabel(context, type)),
                            selected: state.currentOrderType == type,
                            onSelected: (_) => state.setOrderType(type),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  onChanged: (value) => state.orderNotes = value,
                  decoration: InputDecoration(
                    hintText: tr(context,
                        ar: 'ملاحظة للمطبخ: بدون مخلل، زيادة صوص...',
                        en: 'Kitchen note: no pickles, extra sauce...'),
                  ),
                ),
                Row(
                  children: [
                    Text(tr(context, ar: 'الإجمالي', en: 'Total'),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text(formatCurrency(state.cartSubtotal),
                        style: const TextStyle(
                            color: TazaColors.accent,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.cartItems.isEmpty
                        ? null
                        : () {
                            if (!CustomerInputValidation.isSafeText(notes.text,
                                min: 2, max: 500)) {
                              showMessage(
                                  context,
                                  tr(context,
                                      ar: 'تحقق من صيغة ملاحظة الطلب',
                                      en: 'Check the order note'));
                              return;
                            }
                            Navigator.pop(sheetContext);
                            final route = switch (state.currentOrderType) {
                              OrderType.ordinary => AppRoutes.payment,
                              OrderType.delivery => AppRoutes.delivery,
                              OrderType.reservation => AppRoutes.reservation,
                            };
                            Navigator.pushNamed(context, route);
                          },
                    child: Text(
                        tr(context, ar: 'متابعة الطلب', en: 'Continue order')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(notes.dispose);
}
