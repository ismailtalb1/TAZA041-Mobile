import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'app_scope.dart';

String tr(BuildContext context, {required String ar, required String en}) =>
    AppStateScope.of(context).language == AppLanguage.ar ? ar : en;

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

String orderTypeLabel(BuildContext context, OrderType type) => switch (type) {
      OrderType.ordinary => tr(context, ar: 'طلب عادي', en: 'Ordinary order'),
      OrderType.delivery => tr(context, ar: 'طلب توصيل', en: 'Delivery order'),
      OrderType.reservation =>
        tr(context, ar: 'حجز طاولة', en: 'Table reservation'),
    };

String orderStatusLabel(BuildContext context, OrderStatus status) =>
    switch (status) {
      OrderStatus.pending => tr(context, ar: 'معلق', en: 'Pending'),
      OrderStatus.inProgress =>
        tr(context, ar: 'قيد التنفيذ', en: 'In progress'),
      OrderStatus.confirmed => tr(context, ar: 'مؤكد', en: 'Confirmed'),
      OrderStatus.completed => tr(context, ar: 'مكتمل', en: 'Completed'),
      OrderStatus.cancelled => tr(context, ar: 'ملغي', en: 'Cancelled'),
    };

String paymentMethodLabel(BuildContext context, PaymentMethod method) =>
    switch (method) {
      PaymentMethod.cash => tr(context, ar: 'دفع نقدي', en: 'Cash'),
      PaymentMethod.syriatelCash => 'Syriatel Cash',
      PaymentMethod.shamCash => 'Sham Cash',
      PaymentMethod.loyaltyPoints =>
        tr(context, ar: 'نقاط الولاء', en: 'Loyalty points'),
    };

Color statusColor(OrderStatus status) => switch (status) {
      OrderStatus.pending => TazaColors.warning,
      OrderStatus.inProgress => TazaColors.info,
      OrderStatus.confirmed || OrderStatus.completed => TazaColors.success,
      OrderStatus.cancelled => TazaColors.danger,
    };

String formatCurrency(num amount) => '${amount.toStringAsFixed(0)} SYP';
