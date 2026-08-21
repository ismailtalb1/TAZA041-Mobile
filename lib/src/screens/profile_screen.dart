import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../core/app_constants.dart';
import '../core/input_validation.dart';
import '../models.dart';
import '../router.dart';
import '../services/profile_image_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _imageService = ProfileImageService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _bio;
  final _newPassword = TextEditingController();
  final _newPasswordConfirmation = TextEditingController();
  DateTime? _birthday;
  bool _initialized = false;
  bool _editing = false;
  bool _showPasswordFields = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = AppStateScope.of(context).currentUser;
    _name = TextEditingController(text: user.fullName);
    _email = TextEditingController(text: user.email);
    _phone = TextEditingController(text: user.phone);
    _address = TextEditingController(text: user.city);
    _bio = TextEditingController(text: user.bio);
    _birthday = user.birthDate;
    _initialized = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _bio.dispose();
    _newPassword.dispose();
    _newPasswordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _pickAvatar() async {
    final source = await showImageSourcePicker(context);
    if (source == null || !mounted) return;
    final cropped = await _imageService.pickAndCrop(
      source: source,
      title: tr(context, ar: 'تعديل الصورة', en: 'Edit photo'),
    );
    if (cropped == null || !mounted) return;
    final password = await showPasswordConfirmation(
      context,
      titleAr: 'تأكيد تغيير الصورة',
      titleEn: 'Confirm photo change',
      bodyAr: 'أدخل كلمة المرور لحماية صورتك الشخصية من التغيير غير المصرح.',
      bodyEn: 'Enter your password to protect your profile photo.',
    );
    if (password == null || !mounted) return;
    try {
      await AppStateScope.of(context).updateAvatar(
        bytes: await cropped.readAsBytes(),
        filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        currentPassword: password,
      );
      if (mounted) {
        showMessage(
            context, tr(context, ar: 'تم تحديث الصورة', en: 'Photo updated'));
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  void _restoreUserValues() {
    final user = AppStateScope.of(context).currentUser;
    _name.text = user.fullName;
    _email.text = user.email;
    _phone.text = CustomerInputValidation.formatPhone(user.phone);
    _address.text = user.city;
    _bio.text = user.bio;
    _birthday = user.birthDate;
    _newPassword.clear();
    _newPasswordConfirmation.clear();
  }

  void _cancelEditing() {
    _restoreUserValues();
    setState(() {
      _editing = false;
      _showPasswordFields = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPassword.text.isNotEmpty &&
        _newPassword.text != _newPasswordConfirmation.text) {
      showMessage(
          context,
          tr(context,
              ar: 'تأكيد كلمة المرور الجديدة غير متطابق',
              en: 'New password confirmation does not match'));
      return;
    }
    final password = await showPasswordConfirmation(
      context,
      titleAr: 'تأكيد حفظ البيانات',
      titleEn: 'Confirm profile changes',
      bodyAr: 'أدخل كلمة المرور الحالية قبل تطبيق التعديلات على حسابك.',
      bodyEn: 'Enter your current password before applying account changes.',
    );
    if (password == null || !mounted) return;
    try {
      await AppStateScope.of(context).updateProfile(
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
        city: _address.text,
        bio: _bio.text,
        birthDate: _birthday,
        currentPassword: password,
        newPassword: _newPassword.text,
        newPasswordConfirmation: _newPasswordConfirmation.text,
      );
      if (!mounted) return;
      showMessage(
          context, tr(context, ar: 'تم حفظ التعديلات', en: 'Changes saved'));
      if (!AppStateScope.of(context).isAuthenticated) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.login, (_) => false);
        return;
      }
      _newPassword.clear();
      _newPasswordConfirmation.clear();
      setState(() {
        _editing = false;
        _showPasswordFields = false;
      });
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = state.currentUser;
    return TazaShell(
      titleAr: 'إعداد الحساب',
      titleEn: 'Profile settings',
      registered: true,
      showBack: true,
      body: ListView(
        children: [
          TazaCard(
            child: Column(
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: ClipOval(
                    child: user.avatarUrl?.isNotEmpty == true
                        ? Image.network(
                            user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Image.asset(AppAssets.logo, fit: BoxFit.cover),
                          )
                        : Image.asset(AppAssets.logo, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 10),
                Text(user.fullName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text(
                    '${tr(context, ar: 'نقاط الولاء', en: 'Loyalty points')}: ${user.loyaltyPoints}',
                    style: const TextStyle(color: TazaColors.accent)),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.crop_rounded),
                      label: Text(
                          tr(context, ar: 'تعديل الصورة', en: 'Edit photo')),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: TazaColors.success.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_outlined,
                                size: 18, color: TazaColors.success),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tr(context,
                                    ar: 'محمي بكلمة المرور',
                                    en: 'Password protected'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: TazaColors.success),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _LoyaltyProgramCard(user: user),
          const SizedBox(height: 14),
          TazaCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context,
                              ar: 'البيانات الشخصية', en: 'Personal details'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (!_editing)
                        TextButton.icon(
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(tr(context, ar: 'تعديل', en: 'Edit')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    enabled: _editing,
                    inputFormatters: CustomerInputValidation.limited(100),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline),
                      labelText:
                          tr(context, ar: 'الاسم الكامل', en: 'Full name'),
                    ),
                    validator: (value) =>
                        !CustomerInputValidation.isFullName(value)
                            ? tr(context,
                                ar: 'اكتب اسماً صحيحاً من الأحرف فقط',
                                en: 'Enter a valid name using letters only')
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    enabled: false,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email),
                      suffixIcon: const Icon(Icons.lock_outline),
                      labelText:
                          tr(context, ar: 'البريد الإلكتروني', en: 'Email'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    enabled: _editing,
                    keyboardType: TextInputType.number,
                    inputFormatters: CustomerInputValidation.phoneFormatters,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_android),
                      labelText: tr(context, ar: 'رقم الهاتف', en: 'Phone'),
                      hintText: '09 12 345 678',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      return text.isNotEmpty &&
                              !CustomerInputValidation.isPhone(text)
                          ? tr(context,
                              ar: 'الرقم 10 أرقام ويجب أن يبدأ بـ 09',
                              en: 'Phone must be 10 digits and start with 09')
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    enabled: _editing,
                    maxLength: 500,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      labelText: tr(context, ar: 'العنوان', en: 'Address'),
                    ),
                    validator: (value) =>
                        !CustomerInputValidation.isSafeText(value,
                                min: 3, max: 500)
                            ? tr(context,
                                ar: 'تحقق من صيغة العنوان',
                                en: 'Check the address format')
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bio,
                    enabled: _editing,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.notes_rounded),
                      labelText: tr(context, ar: 'نبذة شخصية', en: 'About me'),
                    ),
                    validator: (value) =>
                        !CustomerInputValidation.isSafeText(value,
                                min: 2, max: 500)
                            ? tr(context,
                                ar: 'تحقق من صيغة النبذة',
                                en: 'Check the bio format')
                            : null,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _editing ? _pickBirthday : null,
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(_birthday == null
                          ? tr(context, ar: 'تاريخ الميلاد', en: 'Birth date')
                          : _birthday!.toIso8601String().split('T').first),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _showPasswordFields,
                    onChanged: _editing
                        ? (value) => setState(() => _showPasswordFields = value)
                        : null,
                    title: Text(tr(context,
                        ar: 'تغيير كلمة المرور', en: 'Change password')),
                  ),
                  if (_showPasswordFields) ...[
                    AppPasswordField(
                      controller: _newPassword,
                      prefixIcon: Icons.password_outlined,
                      label: tr(context,
                          ar: 'كلمة المرور الجديدة', en: 'New password'),
                      validator: (value) => value != null &&
                              value.isNotEmpty &&
                              !CustomerInputValidation.isStrongPassword(value)
                              ? tr(context,
                                  ar: 'استخدم 8 أحرف على الأقل تتضمن حروفاً وأرقاماً',
                                  en: 'Use at least 8 characters with letters and numbers')
                              : null,
                    ),
                    const SizedBox(height: 12),
                    AppPasswordField(
                      controller: _newPasswordConfirmation,
                      prefixIcon: Icons.verified_user_outlined,
                      label: tr(context,
                          ar: 'تأكيد كلمة المرور الجديدة',
                          en: 'Confirm new password'),
                    ),
                  ],
                  if (_editing) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isBusy ? null : _cancelEditing,
                            child: Text(tr(context, ar: 'إلغاء', en: 'Cancel')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: state.isBusy ? null : _save,
                            icon: const Icon(Icons.lock_outline_rounded),
                            label: Text(
                                tr(context, ar: 'حفظ آمن', en: 'Secure save')),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 18, color: TazaColors.success),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            tr(context,
                                ar: 'الحقول مقفلة. اضغط تعديل ثم أكّد كلمة المرور عند الحفظ.',
                                en: 'Fields are locked. Tap edit and confirm your password when saving.'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _SavedAddressesCard(),
        ],
      ),
    );
  }
}

class _LoyaltyProgramCard extends StatelessWidget {
  const _LoyaltyProgramCard({required this.user});

  final AppUser user;

  static const _fallbackTiers = <Map<String, dynamic>>[
    {
      'key': 'bronze',
      'name_ar': 'برونزي',
      'name_en': 'Bronze',
      'icon': '🥉',
      'minimum_points': 0,
      'earning_multiplier': 1.0,
    },
    {
      'key': 'silver',
      'name_ar': 'فضي',
      'name_en': 'Silver',
      'icon': '🥈',
      'minimum_points': 400,
      'earning_multiplier': 1.2,
    },
    {
      'key': 'gold',
      'name_ar': 'ذهبي',
      'name_en': 'Gold',
      'icon': '🥇',
      'minimum_points': 700,
      'earning_multiplier': 1.5,
    },
    {
      'key': 'platinum',
      'name_ar': 'بلاتينيوم',
      'name_en': 'Platinum',
      'icon': '💎',
      'minimum_points': 1000,
      'earning_multiplier': 2.0,
    },
  ];

  double _decimal(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

  int _whole(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String _multiplier(dynamic value) {
    final number = _decimal(value, 1);
    return number == number.roundToDouble()
        ? number.toStringAsFixed(1)
        : number.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final tiers =
        user.loyaltyTiers.isEmpty ? _fallbackTiers : user.loyaltyTiers;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final current = tiers.cast<Map<String, dynamic>>().firstWhere(
          (tier) => '${tier['key']}' == user.loyaltyTier,
          orElse: () => tiers.first,
        );
    final currentName = isArabic
        ? '${current['name_ar'] ?? 'برونزي'}'
        : '${current['name_en'] ?? 'Bronze'}';
    final progress = (user.loyaltyProgress / 100).clamp(0.0, 1.0);

    return TazaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: TazaColors.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.workspace_premium_outlined,
                      color: TazaColors.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, ar: 'برنامج الولاء', en: 'Loyalty program'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(context,
                          ar: 'اجمع النقاط وتقدّم لمضاعفة مكافآت كل طلب.',
                          en: 'Earn points and level up to multiply every order reward.'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: onSurface.withValues(alpha: .65),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: TazaColors.accent.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: TazaColors.accent.withValues(alpha: .2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${current['icon'] ?? '⭐'}',
                          style: const TextStyle(fontSize: 25)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            Text(
                              tr(context,
                                  ar: '${user.loyaltyPoints} نقطة',
                                  en: '${user.loyaltyPoints} points'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: onSurface.withValues(alpha: .65)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_multiplier(user.loyaltyMultiplier)}×',
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: TazaColors.accent,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progress,
                      backgroundColor: onSurface.withValues(alpha: .08),
                      color: TazaColors.accent,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      user.pointsToNextTier == null
                          ? tr(context,
                              ar: 'وصلت إلى أعلى مستوى',
                              en: 'You reached the highest tier')
                          : tr(context,
                              ar: 'متبقي ${user.pointsToNextTier} نقطة للمستوى التالي',
                              en: '${user.pointsToNextTier} points to the next tier'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: onSurface.withValues(alpha: .65),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 30) / 4
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiers.map((tier) {
                  final active = '${tier['key']}' == user.loyaltyTier;
                  final name = isArabic
                      ? '${tier['name_ar'] ?? tier['key']}'
                      : '${tier['name_en'] ?? tier['key']}';
                  return SizedBox(
                    width: itemWidth,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: active
                            ? TazaColors.accent.withValues(alpha: .13)
                            : onSurface.withValues(alpha: .035),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? TazaColors.accent.withValues(alpha: .48)
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${tier['icon'] ?? '⭐'}',
                                  style: const TextStyle(fontSize: 19)),
                              const Spacer(),
                              Text(
                                '${_multiplier(tier['earning_multiplier'])}×',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: active
                                      ? TazaColors.accent
                                      : onSurface.withValues(alpha: .82),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          Text(
                            tr(context,
                                ar: 'من ${_whole(tier['minimum_points'])} نقطة',
                                en: 'From ${_whole(tier['minimum_points'])} points'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: onSurface.withValues(alpha: .58),
                                      fontSize: 10.5,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 17, color: TazaColors.accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tr(context,
                      ar: 'كل 10 ل.س = نقطة أساسية، ويُطبّق معامل مستواك تلقائياً عند الدفع.',
                      en: 'Every 10 SYP = one base point; your tier multiplier is applied automatically at payment.'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: .65),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedAddressesCard extends StatelessWidget {
  const _SavedAddressesCard();

  Future<void> _deleteAddress(
      BuildContext context, SavedAddress address) async {
    final password = await showPasswordConfirmation(
      context,
      titleAr: 'حذف العنوان المحفوظ',
      titleEn: 'Delete saved address',
      bodyAr: 'أدخل كلمة المرور قبل حذف هذا الموقع من حسابك وكل أجهزتك.',
      bodyEn:
          'Enter your password before deleting this location from your account and devices.',
    );
    if (password == null || !context.mounted) return;
    try {
      await AppStateScope.of(context).clearAddress(
        address.type,
        currentPassword: password,
      );
      if (context.mounted) {
        showMessage(
            context, tr(context, ar: 'تم حذف العنوان', en: 'Address deleted'));
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }

  Future<void> _syncLegacyAddresses(BuildContext context) async {
    final password = await showPasswordConfirmation(
      context,
      titleAr: 'مزامنة العناوين',
      titleEn: 'Sync addresses',
      bodyAr:
          'وجدنا عناوين محفوظة على هذا الجهاز. أدخل كلمة المرور لربطها بحسابك وإظهارها في الويب وكل أجهزتك.',
      bodyEn:
          'We found addresses saved on this device. Enter your password to link them to your account, the web, and your other devices.',
    );
    if (password == null || !context.mounted) return;
    try {
      await AppStateScope.of(context)
          .syncPendingSavedAddresses(currentPassword: password);
      if (context.mounted) {
        showMessage(
          context,
          tr(context,
              ar: 'تم ربط العناوين بحسابك',
              en: 'Addresses are now linked to your account'),
        );
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, ar: 'العناوين المحفوظة', en: 'Saved addresses'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(tr(context,
              ar: 'تتزامن عناوين البيت والعمل والعنوان الإضافي مع الويب وكل أجهزتك.',
              en: 'Home, work, and your extra address sync with the web and all your devices.')),
          if (state.hasPendingSavedAddressMigration) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: TazaColors.info.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: TazaColors.info.withValues(alpha: .25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        color: TazaColors.info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tr(context,
                          ar: 'لديك عناوين قديمة على هذا الجهاز لم تُرفع إلى حسابك بعد.',
                          en: 'This device has older addresses that have not been uploaded to your account yet.')),
                    ),
                    TextButton(
                      onPressed: () => _syncLegacyAddresses(context),
                      child: Text(tr(context, ar: 'مزامنة', en: 'Sync')),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...state.savedAddresses.map((address) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: .34),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: address.isPinned
                          ? TazaColors.success.withValues(alpha: .3)
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: TazaColors.accent.withValues(alpha: .12),
                      child: Icon(_savedAddressIcon(address.type),
                          color: TazaColors.accent),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(_savedAddressLabel(context, address.type),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (address.isPinned
                                    ? TazaColors.success
                                    : TazaColors.info)
                                .withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            address.isPinned
                                ? tr(context, ar: 'جاهز', en: 'Ready')
                                : tr(context, ar: 'فارغ', en: 'Empty'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: address.isPinned
                                  ? TazaColors.success
                                  : TazaColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(address.isPinned
                          ? address.displayAddress
                          : tr(context,
                              ar: 'أضف وصفاً وثبّت الموقع على الخريطة',
                              en: 'Add a description and pin it on the map')),
                    ),
                    trailing: address.isPinned
                        ? IconButton(
                            tooltip: tr(context, ar: 'حذف', en: 'Delete'),
                            onPressed: () => _deleteAddress(context, address),
                            icon: const Icon(Icons.delete_outline_rounded),
                          )
                        : const Icon(Icons.add_location_alt_outlined),
                    onTap: () => _showSavedAddressEditor(context, address),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

Future<void> _showSavedAddressEditor(
    BuildContext context, SavedAddress address) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SavedAddressEditor(address: address),
  );
}

class _SavedAddressEditor extends StatefulWidget {
  const _SavedAddressEditor({required this.address});

  final SavedAddress address;

  @override
  State<_SavedAddressEditor> createState() => _SavedAddressEditorState();
}

class _SavedAddressEditorState extends State<_SavedAddressEditor> {
  final _mapController = MapController();
  late final TextEditingController _address;
  late final TextEditingController _details;
  LatLng? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.address.address);
    _details = TextEditingController(text: widget.address.details);
    if (widget.address.isPinned) {
      _selected = LatLng(widget.address.latitude!, widget.address.longitude!);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ApiException('فعّل خدمة الموقع ثم حاول مجددًا.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException('لم يتم منح التطبيق إذن الوصول إلى الموقع.');
      }
      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _selected = point);
      _mapController.move(point, 16);
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _save() async {
    final value = _address.text.trim();
    if (!CustomerInputValidation.isSafeText(value,
        required: true, min: 3, max: 500)) {
      showMessage(
          context,
          tr(context,
              ar: 'اكتب وصف عنوان صحيحاً', en: 'Enter a valid address'));
      return;
    }
    if (!CustomerInputValidation.isSafeText(_details.text,
        min: 2, max: 500)) {
      showMessage(
          context,
          tr(context,
              ar: 'تحقق من صيغة تفاصيل العنوان',
              en: 'Check the address details'));
      return;
    }
    if (_selected == null) {
      showMessage(
          context,
          tr(context,
              ar: 'ثبّت الموقع على الخريطة قبل الحفظ',
              en: 'Pin the location on the map before saving'));
      return;
    }
    final state = AppStateScope.of(context);
    setState(() => _saving = true);
    try {
      await state.quoteDelivery(
        latitude: _selected!.latitude,
        longitude: _selected!.longitude,
      );
      if (!mounted) return;
      final password = await showPasswordConfirmation(
        context,
        titleAr: 'تأكيد حفظ الموقع',
        titleEn: 'Confirm saved location',
        bodyAr:
            'تم التحقق من نطاق التوصيل. أدخل كلمة المرور لحفظ الإحداثيات بأمان.',
        bodyEn:
            'Delivery range is verified. Enter your password to save these coordinates securely.',
      );
      if (password == null || !mounted) return;
      await state.saveAddress(
          SavedAddress(
            type: widget.address.type,
            address: value,
            details: _details.text.trim(),
            latitude: _selected?.latitude,
            longitude: _selected?.longitude,
          ),
          currentPassword: password);
      if (mounted) {
        showMessage(
            context,
            tr(context,
                ar: 'تم حفظ الموقع ومزامنته', en: 'Location saved and synced'));
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final center = LatLng(
      state.restaurant.latitude ?? 35.5317,
      state.restaurant.longitude ?? 35.7901,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_savedAddressLabel(context, widget.address.type),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLength: 500,
              decoration: InputDecoration(
                labelText:
                    tr(context, ar: 'وصف العنوان', en: 'Address description'),
                prefixIcon: const Icon(Icons.home_work_outlined),
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: tr(context,
                    ar: 'تفاصيل إضافية (اختياري)',
                    en: 'Additional details (optional)'),
                hintText: tr(context,
                    ar: 'الطابق، رقم الباب، أقرب نقطة دالة',
                    en: 'Floor, door number, nearest landmark'),
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selected ?? center,
                    initialZoom: 13,
                    onTap: (_, point) => setState(() => _selected = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: ApiConfig.mapTileUrl,
                      userAgentPackageName: AppConstants.mapUserAgent,
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: center,
                        width: 42,
                        height: 42,
                        child: const Icon(Icons.restaurant_rounded,
                            color: TazaColors.accent, size: 34),
                      ),
                      if (_selected != null)
                        Marker(
                          point: _selected!,
                          width: 46,
                          height: 46,
                          child: const Icon(Icons.location_pin,
                              color: TazaColors.info, size: 42),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _useMyLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(
                        tr(context, ar: 'موقعي الحالي', en: 'My location')),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: tr(context, ar: 'مسح الموقع', en: 'Clear pin'),
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.location_off_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(tr(context, ar: 'حفظ العنوان', en: 'Save address')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _savedAddressLabel(BuildContext context, SavedAddressType type) =>
    switch (type) {
      SavedAddressType.home => tr(context, ar: 'البيت', en: 'Home'),
      SavedAddressType.work => tr(context, ar: 'العمل', en: 'Work'),
      SavedAddressType.other => tr(context, ar: 'عنوان آخر', en: 'Other'),
    };

IconData _savedAddressIcon(SavedAddressType type) => switch (type) {
      SavedAddressType.home => Icons.home_rounded,
      SavedAddressType.work => Icons.work_rounded,
      SavedAddressType.other => Icons.place_rounded,
    };
