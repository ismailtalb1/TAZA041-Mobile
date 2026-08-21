import 'package:flutter/material.dart';

import 'core/app_constants.dart';
import 'core/app_scope.dart';
import 'core/localization.dart';
import 'models.dart';
import 'router.dart';
import 'theme.dart';

export 'core/app_scope.dart';
export 'core/localization.dart';
export 'ui/content_widgets.dart';

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
    this.startActions,
    this.actions,
    this.bottomContent,
    this.padding = const EdgeInsets.all(20),
  });

  final String titleAr;
  final String titleEn;
  final Widget body;
  final bool registered;
  final bool showBack;
  final List<Widget>? startActions;
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
        appBar: _TazaAppBar(
          registered: registered,
          showBack: showBack,
          startActions: startActions,
          actions: actions,
          subtitle: tr(context, ar: titleAr, en: titleEn),
        ),
        body: ScreenBackground(
          child: Padding(
            padding: adaptivePadding,
            child: Column(
              children: [
                if (state.usingFallback ||
                    (!state.isOnline && state.lastError != null)) ...[
                  const _ConnectionBanner(),
                  const SizedBox(height: 10),
                ],
                Expanded(child: body),
              ],
            ),
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

class _TazaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TazaAppBar({
    required this.registered,
    required this.showBack,
    required this.subtitle,
    this.startActions,
    this.actions,
  });

  final bool registered;
  final bool showBack;
  final String subtitle;
  final List<Widget>? startActions;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final leadingControls = <Widget>[
      if (registered || showBack)
        _ShellLeading(registered: registered, showBack: showBack),
      ...?startActions,
    ];
    final trailingControls = <Widget>[
      ...?actions,
      IconButton(
        key: const ValueKey('taza-theme-button'),
        tooltip: state.isDarkMode
            ? tr(context, ar: 'الوضع النهاري', en: 'Light mode')
            : tr(context, ar: 'الوضع الليلي', en: 'Dark mode'),
        onPressed: state.toggleTheme,
        icon: Icon(state.isDarkMode
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined),
      ),
      IconButton(
        key: const ValueKey('taza-language-button'),
        tooltip: tr(context, ar: 'تغيير اللغة', en: 'Change language'),
        onPressed: state.toggleLanguage,
        icon: Text(
          state.language == AppLanguage.ar ? 'EN' : 'AR',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.surface.withValues(alpha: .88),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 72,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: leadingControls,
                    ),
                  ),
                  _LogoTitle(
                    compact:
                        leadingControls.length + trailingControls.length >= 3 &&
                            constraints.maxWidth < 430,
                    subtitle: subtitle,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: trailingControls,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellLeading extends StatelessWidget {
  const _ShellLeading({required this.registered, required this.showBack});

  final bool registered;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (scaffoldContext) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (registered)
            IconButton(
              key: const ValueKey('taza-menu-button'),
              tooltip: tr(context, ar: 'القائمة', en: 'Menu'),
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
            ),
          if (showBack)
            IconButton(
              key: const ValueKey('taza-back-button'),
              tooltip: tr(context, ar: 'رجوع', en: 'Back'),
              icon: Icon(isArabic(context)
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.maybePop(context),
            ),
        ],
      ),
    );
  }
}

class _LogoTitle extends StatelessWidget {
  const _LogoTitle({required this.compact, required this.subtitle});

  final bool compact;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('taza-logo-title'),
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
                AppAssets.logo,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Text(
              'TAZA 041',
              maxLines: 1,
              semanticsLabel: 'TAZA 041 · $subtitle',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: TazaColors.warning.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: TazaColors.warning.withValues(alpha: .28),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 19, color: TazaColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context,
                        ar: 'الاتصال غير مستقر؛ تُعرض آخر بيانات متاحة.',
                        en: 'Connection is unstable; showing the latest available data.'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (state.lastError?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      state.lastError!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .58),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: tr(context, ar: 'إعادة المحاولة', en: 'Retry'),
              visualDensity: VisualDensity.compact,
              onPressed: () async => state.loadPublicData(silent: true),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
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
        labelAr: 'محادثات الوجبة',
        labelEn: 'Meal conversations',
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
                leading: item.route == AppRoutes.notifications
                    ? Badge(
                        isLabelVisible: state.unreadNotifications > 0,
                        label: Text(state.unreadNotifications > 99
                            ? '99+'
                            : '${state.unreadNotifications}'),
                        child: Icon(item.icon),
                      )
                    : Icon(item.icon),
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
