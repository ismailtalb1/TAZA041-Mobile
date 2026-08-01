import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../router.dart';
import '../widgets.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showApiError(BuildContext context, Object error) {
  showMessage(
    context,
    error is ApiException
        ? error.message
        : error.toString().replaceFirst('Exception: ', ''),
  );
}

Future<void> showAuthRequiredSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context,
                  ar: 'لإكمال الطلب تحتاج إلى حساب',
                  en: 'You need an account to continue'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(tr(context,
                ar: 'يمكنك تصفح القائمة بحرية، لكن إضافة المنتجات والدفع يتطلبان تسجيل الدخول.',
                en: 'You may browse freely, but adding products and paying require sign in.')),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(context, AppRoutes.login);
                    },
                    child: Text(tr(context, ar: 'تسجيل الدخول', en: 'Log in')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(context, AppRoutes.register);
                    },
                    child: Text(tr(context, ar: 'إنشاء حساب', en: 'Register')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String categoryLabel(BuildContext context, ProductCategory category) =>
    switch (category) {
      ProductCategory.sandwich =>
        tr(context, ar: 'الساندويش', en: 'Sandwiches'),
      ProductCategory.meal => tr(context, ar: 'الوجبات', en: 'Meals'),
      ProductCategory.drink => tr(context, ar: 'المشروبات', en: 'Drinks'),
      ProductCategory.offer => tr(context, ar: 'العروض', en: 'Offers'),
    };

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    this.action,
  });

  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      child: Column(
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            tr(context, ar: titleAr, en: titleEn),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(tr(context, ar: bodyAr, en: bodyEn),
              textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
