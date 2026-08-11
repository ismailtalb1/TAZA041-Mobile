import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../core/app_constants.dart';
import '../router.dart';
import '../services/profile_image_service.dart';
import '../widgets.dart';
import 'screen_common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await AppStateScope.of(context).signIn(
        identifier: _identifier.text,
        password: _password.text,
      );
      if (!mounted) return;
      showMessage(
          context,
          tr(context,
              ar: 'تم تسجيل الدخول بنجاح', en: 'Signed in successfully'));
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.homeUser, (_) => false);
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaShell(
      titleAr: 'تسجيل الدخول',
      titleEn: 'Login',
      showBack: true,
      body: ListView(
        children: [
          TazaCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset(AppAssets.logo,
                      width: 112, height: 112, fit: BoxFit.cover),
                  const SizedBox(height: 16),
                  Text(
                    tr(context, ar: 'مرحبًا بعودتك', en: 'Welcome back'),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context,
                        ar: 'سجّل دخولك لمتابعة طلباتك ونقاط الولاء.',
                        en: 'Sign in to track your orders and loyalty points.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _identifier,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.telephoneNumber
                    ],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      hintText: tr(context,
                          ar: 'البريد الإلكتروني أو رقم الهاتف',
                          en: 'Email or phone number'),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? tr(context,
                            ar: 'هذا الحقل مطلوب', en: 'This field is required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    controller: _password,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    label: tr(context, ar: 'كلمة المرور', en: 'Password'),
                    validator: (value) => value == null || value.isEmpty
                        ? tr(context,
                            ar: 'كلمة المرور مطلوبة',
                            en: 'Password is required')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(
                          context, AppRoutes.forgotPassword),
                      child: Text(tr(context,
                          ar: 'نسيت كلمة المرور؟', en: 'Forgot password?')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.isBusy ? null : _submit,
                      child: state.isBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr(context, ar: 'تسجيل الدخول', en: 'Log in')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.register),
                    child: Text(tr(context,
                        ar: 'ليس لديك حساب؟ إنشاء حساب',
                        en: 'No account yet? Create one')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _imageService = ProfileImageService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  DateTime? _birthday;
  CroppedFile? _avatar;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _chooseBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _chooseAvatar() async {
    final source = await showImageSourcePicker(context);
    if (source == null || !mounted) return;
    final picked = await _imageService.pickAndCrop(
      source: source,
      title: tr(context, ar: 'تعديل الصورة', en: 'Edit photo'),
    );
    if (picked != null && mounted) setState(() => _avatar = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_email.text.trim().isEmpty && _phone.text.trim().isEmpty) {
      showMessage(
          context,
          tr(context,
              ar: 'أدخل البريد الإلكتروني أو رقم الهاتف على الأقل',
              en: 'Enter at least an email or a phone number'));
      return;
    }
    final state = AppStateScope.of(context);
    try {
      await state.register(
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
        address: _address.text,
        birthDate: _birthday,
        password: _password.text,
        passwordConfirmation: _confirmation.text,
      );
      if (_avatar != null) {
        await state.updateAvatar(
          bytes: await _avatar!.readAsBytes(),
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          currentPassword: _password.text,
        );
      }
      if (!mounted) return;
      showMessage(
          context,
          tr(context,
              ar: 'تم إنشاء الحساب بنجاح', en: 'Account created successfully'));
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.homeUser, (_) => false);
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaShell(
      titleAr: 'إنشاء حساب',
      titleEn: 'Create account',
      showBack: true,
      body: ListView(
        children: [
          TazaCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    tr(context,
                        ar: 'انضم إلينا وابدأ تجربتك',
                        en: 'Join us and start your experience'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _chooseAvatar,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: _avatar == null
                          ? const Icon(Icons.add_a_photo_outlined, size: 30)
                          : const Icon(Icons.check_circle_rounded,
                              size: 36, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(tr(context,
                      ar: 'الصورة الشخصية اختيارية (حتى 5MB)',
                      en: 'Profile image is optional (up to 5MB)')),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      hintText:
                          tr(context, ar: 'الاسم الكامل', en: 'Full name'),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? tr(context, ar: 'الاسم مطلوب', en: 'Name is required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      hintText: tr(context,
                          ar: 'البريد الإلكتروني (اختياري مع الهاتف)',
                          en: 'Email (optional with phone)'),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isNotEmpty && !text.contains('@')) {
                        return tr(context,
                            ar: 'البريد الإلكتروني غير صحيح',
                            en: 'Invalid email address');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      hintText: tr(context,
                          ar: 'رقم الهاتف (اختياري مع البريد)',
                          en: 'Phone number (optional with email)'),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isNotEmpty && text.length < 7) {
                        return tr(context,
                            ar: 'رقم الهاتف غير صحيح',
                            en: 'Invalid phone number');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    maxLength: 500,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      hintText: tr(context,
                          ar: 'العنوان (اختياري)', en: 'Address (optional)'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _chooseBirthday,
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(_birthday == null
                          ? tr(context,
                              ar: 'تاريخ الميلاد (اختياري)',
                              en: 'Birth date (optional)')
                          : _birthday!.toIso8601String().split('T').first),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    controller: _password,
                    label: tr(context, ar: 'كلمة المرور', en: 'Password'),
                    validator: (value) => (value?.length ?? 0) < 6
                        ? tr(context,
                            ar: 'كلمة المرور 6 أحرف على الأقل',
                            en: 'Password must be at least 6 characters')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    controller: _confirmation,
                    prefixIcon: Icons.verified_user_outlined,
                    label: tr(context,
                        ar: 'تأكيد كلمة المرور', en: 'Confirm password'),
                    validator: (value) => value != _password.text
                        ? tr(context,
                            ar: 'كلمتا المرور غير متطابقتين',
                            en: 'Passwords do not match')
                        : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.isBusy ? null : _submit,
                      child: state.isBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr(context,
                              ar: 'إنشاء الحساب', en: 'Create account')),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.login),
                    child: Text(tr(context,
                        ar: 'لديك حساب؟ تسجيل الدخول',
                        en: 'Already have an account? Log in')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifier = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_identifier.text.trim().isEmpty) {
      showMessage(context,
          tr(context, ar: 'أدخل البريد أو الهاتف', en: 'Enter email or phone'));
      return;
    }
    setState(() => _sending = true);
    try {
      await AppStateScope.of(context).requestPasswordReset(_identifier.text);
      if (!mounted) return;
      showMessage(
          context,
          tr(context,
              ar: 'إذا كانت البيانات مرتبطة بحساب فستصلك تعليمات الاستعادة.',
              en: 'If the details match an account, recovery instructions will arrive.'));
      Navigator.pushNamed(context, AppRoutes.resetPassword,
          arguments: _identifier.text.trim());
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TazaShell(
      titleAr: 'استعادة الحساب',
      titleEn: 'Account recovery',
      showBack: true,
      body: ListView(
        children: [
          TazaCard(
            child: Column(
              children: [
                const Icon(Icons.lock_reset_rounded, size: 64),
                const SizedBox(height: 14),
                Text(
                  tr(context,
                      ar: 'سنساعدك على استعادة حسابك',
                      en: 'We will help you recover your account'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _identifier,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    hintText: tr(context,
                        ar: 'البريد الإلكتروني أو رقم الهاتف',
                        en: 'Email or phone number'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    child: Text(tr(context,
                        ar: 'إرسال التعليمات', en: 'Send instructions')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (_identifier.text.isEmpty && argument is String) {
      _identifier.text = argument;
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AppStateScope.of(context).resetPassword(
        identifier: _identifier.text,
        code: _code.text,
        password: _password.text,
        confirmation: _confirmation.text,
      );
      if (!mounted) return;
      showMessage(
          context,
          tr(context,
              ar: 'تم تغيير كلمة المرور بنجاح',
              en: 'Password changed successfully'));
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TazaShell(
      titleAr: 'إعادة تعيين كلمة المرور',
      titleEn: 'Reset password',
      showBack: true,
      body: ListView(
        children: [
          TazaCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _identifier,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      hintText: tr(context,
                          ar: 'البريد الإلكتروني أو رقم الهاتف',
                          en: 'Email or phone number'),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.pin_outlined),
                      hintText: tr(context,
                          ar: 'رمز التحقق (6 أرقام)',
                          en: 'Verification code (6 digits)'),
                    ),
                    validator: (value) =>
                        !RegExp(r'^\d{6}$').hasMatch(value ?? '')
                            ? tr(context,
                                ar: 'أدخل رمزًا صحيحًا',
                                en: 'Enter a valid code')
                            : null,
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    controller: _password,
                    label: tr(context,
                        ar: 'كلمة المرور الجديدة', en: 'New password'),
                    validator: (value) => (value?.length ?? 0) < 6
                        ? tr(context,
                            ar: '6 أحرف على الأقل', en: 'At least 6 characters')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    controller: _confirmation,
                    prefixIcon: Icons.verified_user_outlined,
                    label: tr(context,
                        ar: 'تأكيد كلمة المرور', en: 'Confirm password'),
                    validator: (value) => value != _password.text
                        ? tr(context,
                            ar: 'كلمتا المرور غير متطابقتين',
                            en: 'Passwords do not match')
                        : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(tr(context, ar: 'حفظ', en: 'Save')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? tr(context, ar: 'هذا الحقل مطلوب', en: 'This field is required')
      : null;
}
