import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../core/app_messenger.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';

void showMessage(BuildContext context, String message) {
  if (AppMessenger.messengerKey.currentState != null) {
    AppMessenger.show(message);
    return;
  }
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message)));
}

void showApiError(BuildContext context, Object error) {
  showMessage(
    context,
    error is ApiException
        ? error.message
        : error.toString().replaceFirst('Exception: ', ''),
  );
}

Future<ImageSource?> showImageSourcePicker(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, ar: 'اختر مصدر الصورة', en: 'Choose photo source'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr(context, ar: 'معرض الصور', en: 'Photo library')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr(context, ar: 'التقاط صورة', en: 'Take a photo')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.prefixIcon = Icons.lock_outline_rounded,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool autofocus;
  final bool enabled;
  final IconData prefixIcon;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.prefixIcon),
        suffixIcon: IconButton(
          tooltip: _obscure
              ? tr(context, ar: 'إظهار كلمة المرور', en: 'Show password')
              : tr(context, ar: 'إخفاء كلمة المرور', en: 'Hide password'),
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded),
        ),
      ),
      validator: widget.validator,
    );
  }
}

Future<String?> showPasswordConfirmation(
  BuildContext context, {
  required String titleAr,
  required String titleEn,
  required String bodyAr,
  required String bodyEn,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PasswordConfirmationSheet(
      title: tr(context, ar: titleAr, en: titleEn),
      body: tr(context, ar: bodyAr, en: bodyEn),
    ),
  );
}

class _PasswordConfirmationSheet extends StatefulWidget {
  const _PasswordConfirmationSheet({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  State<_PasswordConfirmationSheet> createState() =>
      _PasswordConfirmationSheetState();
}

class _PasswordConfirmationSheetState
    extends State<_PasswordConfirmationSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        2,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: TazaColors.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Icon(Icons.shield_outlined, color: TazaColors.accent),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(widget.body),
            const SizedBox(height: 16),
            AppPasswordField(
              controller: _controller,
              label: tr(context,
                  ar: 'كلمة المرور الحالية', en: 'Current password'),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _confirm(),
              validator: (value) => value == null || value.isEmpty
                  ? tr(context,
                      ar: 'أدخل كلمة المرور للمتابعة',
                      en: 'Enter your password to continue')
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr(context, ar: 'إلغاء', en: 'Cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(tr(context, ar: 'تأكيد', en: 'Confirm')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
