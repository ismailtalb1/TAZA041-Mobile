import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
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
        child: state.notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyStateCard(
                    icon: Icons.notifications_none_rounded,
                    titleAr: 'لا توجد إشعارات',
                    titleEn: 'No notifications',
                    bodyAr: 'ستظهر هنا تحديثات الطلبات والعروض والدفع.',
                    bodyEn:
                        'Order, offer, and payment updates will appear here.',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = state.notifications[index];
                  return TazaCard(
                    color: item.isRead
                        ? null
                        : TazaColors.info.withValues(alpha: .10),
                    onTap: () async {
                      try {
                        await state.markNotificationRead(item.id);
                      } catch (error) {
                        if (context.mounted) showApiError(context, error);
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              TazaColors.accent.withValues(alpha: .15),
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
                                        fontWeight: item.isRead
                                            ? FontWeight.w700
                                            : FontWeight.w900,
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
                              Text(notificationTime(context, item),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
