import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final offers = state.productsCatalog
        .where((item) => item.category == ProductCategory.offer)
        .toList();
    final featured = state.productsCatalog
        .where((item) => item.category != ProductCategory.offer)
        .take(6)
        .toList();
    return TazaShell(
      titleAr: 'الرئيسية',
      titleEn: 'Home',
      startActions: [
        IconButton(
          tooltip: tr(context, ar: 'تسجيل الدخول', en: 'Log in'),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          icon: const Icon(Icons.login_rounded),
        ),
        IconButton(
          tooltip: tr(context, ar: 'إنشاء حساب', en: 'Register'),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
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
            HeroMessageCard(
              titleAr:
                  '${state.restaurant.content('hero_title_ar', 'نكهة قريبة،')} ${state.restaurant.content('hero_title_accent_ar', 'وتجربة صُنعت لتبقى.')}',
              titleEn:
                  '${state.restaurant.content('hero_title_en', 'Familiar flavor,')} ${state.restaurant.content('hero_title_accent_en', 'crafted to stay with you.')}',
              bodyAr: state.restaurant.content('hero_description_ar',
                  'تصفح الوجبات المميزة والعروض اليومية، واختر نوع الطلب المناسب، ثم سجّل الدخول عندما تصبح جاهزًا للمتابعة.'),
              bodyEn: state.restaurant.content('hero_description_en',
                  'Browse featured meals and daily offers, choose the right order type, then sign in when you are ready to continue.'),
              visual: TazaImage(
                imageUrl: state.restaurant.logoUrl,
                labelAr: 'TAZA 041',
                labelEn: 'TAZA 041',
                height: 190,
              ),
              primary: ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.menu,
                  arguments: const MenuRouteArgs(orderType: OrderType.ordinary),
                ),
                child: Text(
                    tr(context, ar: 'استعرض الوجبات', en: 'Explore meals')),
              ),
              secondary: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.about),
                child:
                    Text(tr(context, ar: 'عن المطعم', en: 'About restaurant')),
              ),
            ),
            const SizedBox(height: 16),
            const _JourneyStep(
              number: '01',
              titleAr: 'اختر الوجبات',
              titleEn: 'Choose meals',
              bodyAr: 'تصفح المنتجات والعروض المميزة.',
              bodyEn: 'Browse featured products and offers.',
            ),
            const SizedBox(height: 10),
            const _JourneyStep(
              number: '02',
              titleAr: 'حدد نوع الطلب',
              titleEn: 'Pick order type',
              bodyAr: 'عادي أو توصيل أو حجز طاولة.',
              bodyEn: 'Pickup, delivery, or reservation.',
            ),
            const SizedBox(height: 10),
            const _JourneyStep(
              number: '03',
              titleAr: 'سجّل الدخول للمتابعة',
              titleEn: 'Sign in to continue',
              bodyAr: 'الحساب مطلوب فقط عند إكمال الطلب.',
              bodyEn: 'An account is required only at checkout.',
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              titleAr: 'أنواع الطلب',
              titleEn: 'Order types',
              subtitleAr: 'اختر المسار المناسب لك بعد تسجيل الدخول.',
              subtitleEn: 'Choose your preferred flow after signing in.',
            ),
            const SizedBox(height: 12),
            OrderTypeActionCard(
              icon: Icons.lunch_dining_rounded,
              titleAr: 'طلب عادي',
              titleEn: 'Ordinary order',
              bodyAr: 'استلام سريع من المطعم ثم الدفع.',
              bodyEn: 'Quick restaurant pickup, then payment.',
              onTap: () => showAuthRequiredSheet(context),
            ),
            const SizedBox(height: 10),
            OrderTypeActionCard(
              icon: Icons.delivery_dining_rounded,
              titleAr: 'طلب توصيل',
              titleEn: 'Delivery order',
              bodyAr: 'حدد موقعك واعرف أجور التوصيل قبل الدفع.',
              bodyEn: 'Set your location and review the fee before payment.',
              accentColor: TazaColors.info,
              onTap: () => showAuthRequiredSheet(context),
            ),
            const SizedBox(height: 10),
            OrderTypeActionCard(
              icon: Icons.table_restaurant_rounded,
              titleAr: 'حجز طاولة',
              titleEn: 'Table reservation',
              bodyAr: 'اختر الطاولة والوقت وعدد المقاعد بسهولة.',
              bodyEn: 'Choose a table, time, and seat count with ease.',
              accentColor: Color(0xFFAD83ED),
              onTap: () => showAuthRequiredSheet(context),
            ),
            const SizedBox(height: 24),
            _ProductSection(
              titleAr: 'العروض اليومية',
              titleEn: 'Daily offers',
              products: offers,
              onAdd: (_) => showAuthRequiredSheet(context),
            ),
            const SizedBox(height: 24),
            _ProductSection(
              titleAr: 'منتجات مميزة',
              titleEn: 'Featured products',
              products: featured,
              onAdd: (_) => showAuthRequiredSheet(context),
            ),
            const SizedBox(height: 24),
            const AboutPreviewCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class RegisteredHomeScreen extends StatelessWidget {
  const RegisteredHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final offers = state.productsCatalog
        .where((item) => item.category == ProductCategory.offer)
        .toList();
    final featured = state.productsCatalog
        .where((item) => item.category != ProductCategory.offer)
        .take(6)
        .toList();
    return TazaShell(
      titleAr: 'الرئيسية',
      titleEn: 'Home',
      registered: true,
      body: RefreshIndicator(
        onRefresh: () => state.refreshCustomerData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            TazaCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: TazaColors.accent.withValues(alpha: .18),
                    child: Text(
                      state.currentUser.fullName.isEmpty
                          ? 'T'
                          : state.currentUser.fullName.characters.first,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tr(context, ar: 'مرحبًا بعودتك', en: 'Welcome back')}, ${state.currentUser.fullName}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tr(context, ar: 'نقاط الولاء', en: 'Loyalty points')}: ${state.currentUser.loyaltyPoints}',
                          style: const TextStyle(color: TazaColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionHeader(
              titleAr: 'ابدأ طلبك',
              titleEn: 'Start your order',
              subtitleAr: 'اختر نوع الطلب ثم انتقل إلى المنيو.',
              subtitleEn: 'Choose an order type, then continue to the menu.',
            ),
            const SizedBox(height: 12),
            _orderCard(
                context, state, OrderType.ordinary, Icons.lunch_dining_rounded),
            const SizedBox(height: 10),
            _orderCard(context, state, OrderType.delivery,
                Icons.delivery_dining_rounded),
            const SizedBox(height: 10),
            _orderCard(context, state, OrderType.reservation,
                Icons.table_restaurant_rounded),
            const SizedBox(height: 24),
            _ProductSection(
              titleAr: 'العروض اليومية',
              titleEn: 'Daily offers',
              products: offers,
              onAdd: (product) {
                state.openMenu(
                    orderType: state.currentOrderType, highlightId: product.id);
                Navigator.pushNamed(context, AppRoutes.menu,
                    arguments: MenuRouteArgs(
                      orderType: state.currentOrderType,
                      highlightProductId: product.id,
                    ));
              },
            ),
            const SizedBox(height: 24),
            _ProductSection(
              titleAr: 'منتجات مميزة',
              titleEn: 'Featured products',
              products: featured,
              onAdd: (product) {
                state.openMenu(
                    orderType: state.currentOrderType, highlightId: product.id);
                Navigator.pushNamed(context, AppRoutes.menu,
                    arguments: MenuRouteArgs(
                      orderType: state.currentOrderType,
                      highlightProductId: product.id,
                    ));
              },
            ),
            const SizedBox(height: 24),
            const AboutPreviewCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(
      BuildContext context, AppState state, OrderType type, IconData icon) {
    final labels = switch (type) {
      OrderType.ordinary => ('طلب عادي', 'Ordinary order'),
      OrderType.delivery => ('طلب توصيل', 'Delivery order'),
      OrderType.reservation => ('حجز طاولة', 'Table reservation'),
    };
    final bodies = switch (type) {
      OrderType.ordinary => (
          'استلام من المطعم والدفع مباشرة.',
          'Pickup and direct payment.'
        ),
      OrderType.delivery => (
          'موقع دقيق وأجور محسوبة.',
          'Precise location and calculated fee.'
        ),
      OrderType.reservation => (
          'طاولة متاحة ووقت مناسب.',
          'Available table and suitable time.'
        ),
    };
    return OrderTypeActionCard(
      icon: icon,
      titleAr: labels.$1,
      titleEn: labels.$2,
      bodyAr: bodies.$1,
      bodyEn: bodies.$2,
      accentColor: switch (type) {
        OrderType.ordinary => TazaColors.accent,
        OrderType.delivery => TazaColors.info,
        OrderType.reservation => const Color(0xFFAD83ED),
      },
      onTap: () {
        state.openMenu(orderType: type);
        Navigator.pushNamed(context, AppRoutes.menu,
            arguments: MenuRouteArgs(orderType: type));
      },
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final restaurant = state.restaurant;
    return TazaShell(
      titleAr: 'عن المطعم',
      titleEn: 'About restaurant',
      registered: state.isAuthenticated,
      showBack: true,
      body: ListView(
        children: [
          HeroMessageCard(
            titleAr: restaurant.content('hero_title_ar', restaurant.name),
            titleEn: restaurant.content('hero_title_en', restaurant.name),
            bodyAr: restaurant.content(
              'hero_description_ar',
              restaurant.about.isNotEmpty
                  ? restaurant.about
                  : 'مطعم حديث يقدم وجبات سريعة وعصرية بجودة عالية وخدمة منظمة.',
            ),
            bodyEn: restaurant.content(
              'hero_description_en',
              restaurant.about.isNotEmpty
                  ? restaurant.about
                  : 'A modern restaurant serving high-quality fast meals through an organized experience.',
            ),
            visual: TazaImage(
              imageUrl: restaurant.logoUrl,
              labelAr: 'TAZA 041',
              labelEn: 'TAZA 041',
              height: 210,
            ),
          ),
          const SizedBox(height: 18),
          TazaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    context,
                    ar: restaurant.content('story_title_ar', 'حكايتنا'),
                    en: restaurant.content('story_title_en', 'Our story'),
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(tr(
                  context,
                  ar: restaurant.content('story_paragraph_one_ar',
                      'نهتم بالمكوّن، بطريقة التحضير، وبالوقت الذي يصل فيه الطلب إليك.'),
                  en: restaurant.content('story_paragraph_one_en',
                      'We care about ingredients, preparation, and the moment your order reaches you.'),
                )),
                const SizedBox(height: 8),
                Text(tr(
                  context,
                  ar: restaurant.content('story_paragraph_two_ar',
                      'تجربتنا الرقمية واضحة وسريعة وبدون خطوات مربكة.'),
                  en: restaurant.content('story_paragraph_two_en',
                      'Our digital experience is clear, quick, and free of confusing steps.'),
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 1; index <= 3; index++) ...[
            _WebsiteValueCard(restaurant: restaurant, index: index),
            const SizedBox(height: 10),
          ],
          TazaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    context,
                    ar: restaurant.content('visit_title_ar', 'زيارتك تسعدنا'),
                    en: restaurant.content(
                        'visit_title_en', 'We would love your visit'),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(tr(
                  context,
                  ar: restaurant.content(
                      'visit_description_ar', restaurant.address),
                  en: restaurant.content(
                      'visit_description_en', restaurant.address),
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TazaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(
                  icon: Icons.location_on_outlined,
                  label: tr(context, ar: 'العنوان', en: 'Address'),
                  value:
                      restaurant.address.isNotEmpty ? restaurant.address : '—',
                ),
                _InfoLine(
                  icon: Icons.phone_outlined,
                  label: tr(context, ar: 'الهاتف', en: 'Phone'),
                  value: restaurant.phone.isNotEmpty ? restaurant.phone : '—',
                ),
                _InfoLine(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: restaurant.email.isNotEmpty ? restaurant.email : '—',
                ),
                _InfoLine(
                  icon: restaurant.isOpen
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  label: tr(context, ar: 'الحالة', en: 'Status'),
                  value: restaurant.isOpen
                      ? tr(context, ar: 'مفتوح الآن', en: 'Open now')
                      : tr(context, ar: 'مغلق الآن', en: 'Closed now'),
                ),
                if (restaurant.workingHours.isNotEmpty) ...[
                  const Divider(height: 26),
                  Text(
                    tr(context, ar: 'ساعات العمل', en: 'Opening hours'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  _WorkingHoursList(restaurant: restaurant),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebsiteValueCard extends StatelessWidget {
  const _WebsiteValueCard({required this.restaurant, required this.index});

  final RestaurantProfile restaurant;
  final int index;

  String get _key => switch (index) { 1 => 'one', 2 => 'two', _ => 'three' };

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: Color(0x2216C784),
          child: Icon(Icons.auto_awesome_rounded, color: TazaColors.success),
        ),
        title: Text(
          tr(
            context,
            ar: restaurant.content(
                'value_${_key}_title_ar', 'اهتمام في كل تفصيل'),
            en: restaurant.content(
                'value_${_key}_title_en', 'Care in every detail'),
          ),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(tr(
          context,
          ar: restaurant.content(
              'value_${_key}_description_ar', 'جودة وخدمة وتجربة قريبة منك.'),
          en: restaurant.content('value_${_key}_description_en',
              'Quality, service, and an experience close to you.'),
        )),
      ),
    );
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.titleAr,
    required this.titleEn,
    required this.products,
    required this.onAdd,
  });

  final String titleAr;
  final String titleEn;
  final List<Product> products;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(titleAr: titleAr, titleEn: titleEn),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const EmptyStateCard(
            icon: Icons.restaurant_menu_rounded,
            titleAr: 'لا توجد عناصر حاليًا',
            titleEn: 'No items available',
            bodyAr: 'اسحب للأسفل لتحديث القائمة.',
            bodyEn: 'Pull down to refresh the catalog.',
          )
        else
          SizedBox(
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductTile(
                  product: product,
                  quantity: 0,
                  onAdd: () => onAdd(product),
                  onRemove: () {},
                );
              },
            ),
          ),
      ],
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.number,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
  });

  final String number;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: TazaColors.accent.withValues(alpha: .16),
            child: Text(number,
                style: const TextStyle(
                    color: TazaColors.accent, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, ar: titleAr, en: titleEn),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(tr(context, ar: bodyAr, en: bodyEn)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TazaColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkingHoursList extends StatelessWidget {
  const _WorkingHoursList({required this.restaurant});

  final RestaurantProfile restaurant;

  static const _days = <(String, String, String)>[
    ('saturday', 'السبت', 'Saturday'),
    ('sunday', 'الأحد', 'Sunday'),
    ('monday', 'الاثنين', 'Monday'),
    ('tuesday', 'الثلاثاء', 'Tuesday'),
    ('wednesday', 'الأربعاء', 'Wednesday'),
    ('thursday', 'الخميس', 'Thursday'),
    ('friday', 'الجمعة', 'Friday'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _days.map((day) {
        final hours = restaurant.hoursFor(day.$1);
        final open = hours['open'] == true || hours['open'] == 1;
        final value = open
            ? '${_formatTime(context, '${hours['from'] ?? ''}')} – '
                '${_formatTime(context, '${hours['to'] ?? ''}')}'
            : tr(context, ar: 'مغلق', en: 'Closed');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isArabic(context) ? day.$2 : day.$3,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(value),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  String _formatTime(BuildContext context, String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value.isEmpty ? '—' : value;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;
    final suffix = hour < 12
        ? tr(context, ar: 'ص', en: 'AM')
        : tr(context, ar: 'م', en: 'PM');
    return '${hour % 12 == 0 ? 12 : hour % 12}:'
        '${minute.toString().padLeft(2, '0')} $suffix';
  }
}
