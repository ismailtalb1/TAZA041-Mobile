import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns every persisted application preference.
///
/// Keeping keys and migration access here prevents UI and business logic from
/// depending directly on a storage plugin and makes future migrations local.
class AppStorage {
  AppStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _languageKey = 'taza_language';
  static const _themeKey = 'taza_theme_dark';
  static const _cartKey = 'taza_cart';
  static const _pendingOrderKey = 'taza_pending_order_id';
  static const _pendingOrderFingerprintKey = 'taza_pending_order_fingerprint';
  static const _savedAddressesKey = 'taza_saved_addresses';
  static const _savedAddressesOwnerKey = 'taza_saved_addresses_owner';
  static const _publicCacheKey = 'taza_public_snapshot_v1';

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _preferences;
  Future<void>? _initialization;

  bool get isInitialized => _preferences != null;

  Future<void> initialize() => _initialization ??= _loadPreferences();

  Future<void> _loadPreferences() async {
    _preferences = await SharedPreferences.getInstance();
  }

  SharedPreferences get _prefs {
    final preferences = _preferences;
    if (preferences == null) {
      throw StateError('AppStorage.initialize must complete before reading.');
    }
    return preferences;
  }

  String get languageCode => _prefs.getString(_languageKey) ?? 'ar';
  bool get isDarkMode => _prefs.getBool(_themeKey) ?? true;
  String? get pendingOrderId => _prefs.getString(_pendingOrderKey);
  String? get pendingOrderFingerprint =>
      _prefs.getString(_pendingOrderFingerprintKey);
  String? get publicSnapshot => _prefs.getString(_publicCacheKey);
  String? get cartSnapshot => _prefs.getString(_cartKey);
  String? get legacySavedAddresses => _prefs.getString(_savedAddressesKey);
  int? get savedAddressesOwner => _prefs.getInt(_savedAddressesOwnerKey);

  Future<void> writeLanguage(String value) async {
    await initialize();
    await _prefs.setString(_languageKey, value);
  }

  Future<void> writeTheme(bool value) async {
    await initialize();
    await _prefs.setBool(_themeKey, value);
  }

  Future<void> writePublicSnapshot(String value) async {
    await initialize();
    await _prefs.setString(_publicCacheKey, value);
  }

  Future<void> clearPublicSnapshot() async {
    await initialize();
    await _prefs.remove(_publicCacheKey);
  }

  Future<void> writeCartSnapshot(String value) async {
    await initialize();
    await _prefs.setString(_cartKey, value);
  }

  Future<void> clearCartSnapshot() async {
    await initialize();
    await _prefs.remove(_cartKey);
  }

  Future<void> savePendingOrder({
    required String id,
    required String fingerprint,
  }) async {
    await initialize();
    await Future.wait([
      _prefs.setString(_pendingOrderKey, id),
      _prefs.setString(_pendingOrderFingerprintKey, fingerprint),
    ]);
  }

  Future<void> clearPendingOrder() async {
    await initialize();
    await Future.wait([
      _prefs.remove(_pendingOrderKey),
      _prefs.remove(_pendingOrderFingerprintKey),
    ]);
  }

  Future<String?> readSavedAddresses() =>
      _secureStorage.read(key: _savedAddressesKey);

  Future<void> writeSavedAddresses(String value) =>
      _secureStorage.write(key: _savedAddressesKey, value: value);

  Future<void> clearSavedAddresses() =>
      _secureStorage.delete(key: _savedAddressesKey);

  Future<void> writeSavedAddressesOwner(int customerId) async {
    await initialize();
    await _prefs.setInt(_savedAddressesOwnerKey, customerId);
  }

  Future<void> clearSavedAddressesOwner() async {
    await initialize();
    await _prefs.remove(_savedAddressesOwnerKey);
  }

  Future<void> clearLegacySavedAddresses() async {
    await initialize();
    await _prefs.remove(_savedAddressesKey);
  }
}
