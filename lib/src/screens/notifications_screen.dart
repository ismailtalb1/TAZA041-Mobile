import 'package:flutter/material.dart';

import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

enum _NotificationFilter { all, unread, orders, catalog, ideas }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = state.notifications
        .where((item) => switch (_filter) {
              _NotificationFilter.all => true,
              _NotificationFilter.unread => !item.isRead,
              _NotificationFilter.orders => item.isOrderUpdate,
              _NotificationFilter.catalog => item.isCatalogUpdate,
              _NotificationFilter.ideas => item.isMealSuggestionUpdate,
            })
        .toList(growable: false);

    return TazaShell(
      titleAr: 'الإشعارات',
      titleEn: 'Notifications',
      registered: true,
      showBack: true,
      actions: [
        IconButton(
          tooltip: tr(context, ar: 'قراءة الكل', en: 'Mark all as read'),
          onPressed: state.unreadNotifications == 0
              ? null
              : () async {
                  try {
                    await state.markAllNotificationsRead();
                  } catch (error) {
                    if (context.mounted) showApiError(context, error);
                  }
                },
          icon: const Icon(Icons.done_all_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => state.refreshCustomerData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _NotificationFilter.values
                    .map((filter) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                            label: Text(_filterLabel(context, filter)),
                          ),
                        ))
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              EmptyStateCard(
                icon: Icons.notifications_none_rounded,
                titleAr: _filter == _NotificationFilter.all
                    ? 'لا توجد إشعارات'
                    : 'لا توجد نتائج ضمن هذا الفلتر',
                titleEn: _filter == _NotificationFilter.all
                    ? 'No notifications'
                    : 'No notifications in this filter',
                bodyAr: 'ستظهر هنا تحديثات الطلبات والعروض والدفع.',
                bodyEn: 'Order, offer, and payment updates will appear here.',
              )
            else
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationCard(
                      item: item,
                      onTap: () => _openNotification(context, item),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _filterLabel(BuildContext context, _NotificationFilter filter) =>
      switch (filter) {
        _NotificationFilter.all => tr(context, ar: 'الكل', en: 'All'),
        _NotificationFilter.unread =>
          tr(context, ar: 'غير المقروء', en: 'Unread'),
        _NotificationFilter.orders => tr(context, ar: 'الطلبات', en: 'Orders'),
        _NotificationFilter.catalog =>
          tr(context, ar: 'العروض والمنيو', en: 'Offers & menu'),
        _NotificationFilter.ideas =>
          tr(context, ar: 'أفكار الوجبات', en: 'Meal ideas'),
      };

  Future<void> _openNotification(
      BuildContext context, NotificationItem item) async {
    final state = AppStateScope.of(context);
    try {
      await state.markNotificationRead(item.id);
      if (!context.mounted) return;
      if (item.isOrderUpdate || item.linkedOrderId != null) {
        await Navigator.pushNamed(context, AppRoutes.orders);
      } else if (item.isMealSuggestionUpdate ||
          item.linkedSuggestionId != null) {
        await Navigator.pushNamed(
          context,
          AppRoutes.aiSuggestion,
          arguments: MealConversationRouteArgs(
            openIdeas: true,
            suggestionId: item.linkedSuggestionId,
          ),
        );
      } else if (item.isCatalogUpdate || item.linkedCatalogId != null) {
        await Navigator.pushNamed(
          context,
          AppRoutes.menu,
          arguments: MenuRouteArgs(
            orderType: OrderType.ordinary,
            highlightProductId: item.linkedCatalogId,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      color: item.isRead ? null : TazaColors.info.withValues(alpha: .10),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: TazaColors.accent.withValues(alpha: .15),
            child: Icon(item.icon, color: TazaColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notificationTitle(context, item),
                        style: TextStyle(
                          fontWeight:
                              item.isRead ? FontWeight.w700 : FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!item.isRead)
                      const Icon(Icons.circle,
                          size: 10, color: TazaColors.info),
                  ],
                ),
                const SizedBox(height: 5),
                Text(notificationMessage(context, item)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(notificationTime(context, item),
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    if (item.isOrderUpdate ||
                        item.isCatalogUpdate ||
                        item.isMealSuggestionUpdate)
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
