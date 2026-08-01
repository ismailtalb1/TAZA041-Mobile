import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _bio;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPasswordConfirmation = TextEditingController();
  DateTime? _birthday;
  bool _initialized = false;
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
    _currentPassword.dispose();
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
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    try {
      await AppStateScope.of(context).updateAvatar(
        bytes: await image.readAsBytes(),
        filename: image.name,
      );
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
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
    try {
      await AppStateScope.of(context).updateProfile(
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
        city: _address.text,
        bio: _bio.text,
        birthDate: _birthday,
        currentPassword: _currentPassword.text,
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
      _currentPassword.clear();
      _newPassword.clear();
      _newPasswordConfirmation.clear();
      setState(() => _showPasswordFields = false);
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
                            errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/taza041-logo.jpg',
                                fit: BoxFit.cover),
                          )
                        : Image.asset('assets/images/taza041-logo.jpg',
                            fit: BoxFit.cover),
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.photo_camera_back_outlined),
                  label:
                      Text(tr(context, ar: 'تغيير الصورة', en: 'Change photo')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TazaCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline),
                      labelText:
                          tr(context, ar: 'الاسم الكامل', en: 'Full name'),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? tr(context, ar: 'الاسم مطلوب', en: 'Name is required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
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
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_android),
                      labelText: tr(context, ar: 'رقم الهاتف', en: 'Phone'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    maxLength: 500,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      labelText: tr(context, ar: 'العنوان', en: 'Address'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bio,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.notes_rounded),
                      labelText: tr(context, ar: 'نبذة شخصية', en: 'About me'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickBirthday,
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
                    onChanged: (value) =>
                        setState(() => _showPasswordFields = value),
                    title: Text(tr(context,
                        ar: 'تغيير كلمة المرور', en: 'Change password')),
                  ),
                  if (_showPasswordFields) ...[
                    TextField(
                      controller: _currentPassword,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        labelText: tr(context,
                            ar: 'كلمة المرور الحالية', en: 'Current password'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPassword,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.password_outlined),
                        labelText: tr(context,
                            ar: 'كلمة المرور الجديدة', en: 'New password'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordConfirmation,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        labelText: tr(context,
                            ar: 'تأكيد كلمة المرور الجديدة',
                            en: 'Confirm new password'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.isBusy ? null : _save,
                      child: Text(
                          tr(context, ar: 'حفظ التعديلات', en: 'Save changes')),
                    ),
                  ),
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

class _SavedAddressesCard extends StatelessWidget {
  const _SavedAddressesCard();

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
              ar: 'احفظ البيت والعمل وعنواناً إضافياً لاختياره بسرعة عند التوصيل.',
              en: 'Save home, work, and one extra address for faster delivery.')),
          const SizedBox(height: 10),
          ...state.savedAddresses.map((address) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_savedAddressIcon(address.type),
                    color: TazaColors.accent),
                title: Text(_savedAddressLabel(context, address.type),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(address.hasAddress
                    ? address.address
                    : tr(context, ar: 'غير محفوظ بعد', en: 'Not saved yet')),
                trailing: Icon(address.isPinned
                    ? Icons.location_on_rounded
                    : Icons.edit_location_alt_outlined),
                onTap: () => _showSavedAddressEditor(context, address),
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
  LatLng? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.address.address);
    if (widget.address.isPinned) {
      _selected = LatLng(widget.address.latitude!, widget.address.longitude!);
    }
  }

  @override
  void dispose() {
    _address.dispose();
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
    if (value.isEmpty) {
      showMessage(
          context,
          tr(context,
              ar: 'اكتب وصف العنوان أولاً', en: 'Enter an address first'));
      return;
    }
    final state = AppStateScope.of(context);
    setState(() => _saving = true);
    try {
      if (_selected != null) {
        await state.quoteDelivery(
          latitude: _selected!.latitude,
          longitude: _selected!.longitude,
        );
      }
      await state.saveAddress(SavedAddress(
        type: widget.address.type,
        address: value,
        latitude: _selected?.latitude,
        longitude: _selected?.longitude,
      ));
      if (mounted) Navigator.pop(context);
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
                      userAgentPackageName: 'com.taza041.customer',
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
