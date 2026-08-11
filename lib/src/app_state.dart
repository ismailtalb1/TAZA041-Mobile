import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'core/app_storage.dart';
import 'models.dart';
import 'sync_coordinator.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? apiClient, AppStorage? storage})
      : api = apiClient ?? ApiClient(),
        _storage = storage ?? AppStorage() {
    _sync = SyncCoordinator(onSync: _syncLiveData);
  }

  final ApiClient api;
  final AppStorage _storage;
  late final SyncCoordinator _sync;
  final StreamController<NotificationItem> _notificationEvents =
      StreamController<NotificationItem>.broadcast();

  AppLanguage language = AppLanguage.ar;
  bool isDarkMode = true;
  bool isAuthenticated = false;
  bool isInitializing = true;
  bool isBusy = false;
  bool isOnline = false;
  bool usingFallback = false;
  String? lastError;

  AppUser currentUser = AppUser(
    fullName: 'Guest',
    email: '',
    phone: '',
    loyaltyPoints: 0,
  );
  RestaurantProfile restaurant = const RestaurantProfile();
  Map<String, dynamic> pricing = const {};
  Map<String, dynamic> restaurantImages = const {};

  final List<NotificationItem> notifications = [];
  final List<OrderRecord> orders = [];
  final Map<String, CartItem> _cart = <String, CartItem>{};
  final List<Product> productsCatalog = [];
  final List<ReservationTable> reservationTables = [];
  final List<SavedAddress> savedAddresses = SavedAddressType.values
      .map((type) => SavedAddress(type: type))
      .toList(growable: false);

  OrderType currentOrderType = OrderType.ordinary;
  String? highlightedProductId;
  String orderNotes = '';

  DriverProfile? selectedDriver;
  String? selectedDeliveryAddressAr;
  String? selectedDeliveryAddressEn;
  int? selectedDeliveryDistanceMeters;
  double? selectedDeliveryLatitude;
  double? selectedDeliveryLongitude;
  double deliveryCost = 0;
  List<List<double>> selectedDeliveryRouteGeometry = const [];
  int? selectedDeliveryDurationMinutes;
  bool selectedDeliveryRouteIsFallback = false;

  int? selectedTableNumber;
  bool selectedTableIsVip = false;
  String? selectedReservationTime;
  int selectedSeatsCount = 2;
  int reservationDurationMinutes = 60;
  String reservationNotes = '';
  double reservationExtra = 0;
  int? aiConversationId;
  String? _pendingOrderId;
  bool _ordersRefreshInFlight = false;
  bool _notificationsRefreshInFlight = false;
  bool _savedAddressesRefreshInFlight = false;
  bool _notificationBaselineReady = false;
  int _busyOperations = 0;
  String? _publicRevision;
  final Set<int> reportedUnavailableProductIds = {};
  bool hasPendingSavedAddressMigration = false;

  List<CartItem> get cartItems => _cart.values.toList(growable: false);
  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartSubtotal =>
      _cart.values.fold(0, (sum, item) => sum + item.subtotal);
  double get extrasTotal => deliveryCost + reservationExtra;
  double get orderGrandTotal => cartSubtotal + extrasTotal;
  int get unreadNotifications =>
      notifications.where((item) => !item.isRead).length;
  Stream<NotificationItem> get notificationEvents => _notificationEvents.stream;

  Future<void> initialize() async {
    try {
      await _storage.initialize();
      language =
          _storage.languageCode == 'en' ? AppLanguage.en : AppLanguage.ar;
      isDarkMode = _storage.isDarkMode;
      _pendingOrderId = _storage.pendingOrderId;
      await _restoreSavedAddresses();
      await _restorePublicCache();
      await api.restoreToken();
      await loadPublicData(silent: true);
      _restoreCart();
      if (api.hasToken) {
        try {
          await refreshCustomerData(
            silent: true,
            announceNotifications: false,
          );
          isAuthenticated = true;
        } on ApiException catch (error) {
          if (error.isUnauthorized) await _clearSession();
        }
      }
    } catch (error) {
      isOnline = false;
      usingFallback = true;
      lastError = error is ApiException
          ? error.message
          : 'تعذر تهيئة بعض بيانات التطبيق. يمكنك المحاولة مجددًا.';
    } finally {
      isInitializing = false;
      _sync.start();
      notifyListeners();
    }
  }

  void setForeground(bool value) => _sync.setForeground(value);

  Future<void> _syncLiveData() async {
    await refreshPublicDataLive();
    if (!isAuthenticated) return;
    await Future.wait([
      refreshOrdersLive(),
      refreshNotificationsLive(),
      refreshSavedAddressesLive(),
    ]);
  }

  Future<void> refreshPublicDataLive() async {
    try {
      final data = _map(await api.get('/public/live-data', query: {
        if (_publicRevision != null) 'since': _publicRevision,
      }));
      _publicRevision = data['revision']?.toString() ?? _publicRevision;
      if (data['changed'] != true) return;
      restaurant = RestaurantProfile.fromJson(_map(data['restaurant']));
      restaurantImages = _map(data['images']);
      pricing = _map(data['pricing']);
      _replaceCatalog(data['products'], data['offers']);
      await _storage.writePublicSnapshot(jsonEncode(data));
      isOnline = true;
      usingFallback = false;
      lastError = null;
      notifyListeners();
    } on ApiException catch (error) {
      isOnline = false;
      lastError = error.message;
    }
  }

  void _replaceCatalog(dynamic productList, dynamic offerList,
      {bool reconcileCart = true}) {
    final catalog = <Product>[
      if (productList is List)
        ...productList.whereType<Map>().map(
              (item) =>
                  Product.fromProductJson(Map<String, dynamic>.from(item)),
            ),
      if (offerList is List)
        ...offerList.whereType<Map>().map(
              (item) => Product.fromOfferJson(Map<String, dynamic>.from(item)),
            ),
    ];
    productsCatalog
      ..clear()
      ..addAll(catalog);
    if (reconcileCart) _reconcileCartWithCatalog();
  }

  void _reconcileCartWithCatalog() {
    final previous = cartItems.toList(growable: false);
    _cart.clear();
    for (final item in previous) {
      final current = productsCatalog
          .where((product) =>
              product.id == item.product.id &&
              product.itemType == item.product.itemType &&
              product.isAvailable)
          .firstOrNull;
      if (current == null) continue;
      final quantity = item.quantity.clamp(1, current.maxQuantity);
      _cart['${current.itemType.name}:${current.id}'] = CartItem(
        product: current,
        quantity: quantity,
        note: item.note,
      );
    }
    _saveCart();
  }

  Future<void> _restorePublicCache() async {
    final raw = _storage.publicSnapshot;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = _map(jsonDecode(raw));
      restaurant = RestaurantProfile.fromJson(_map(data['restaurant']));
      restaurantImages = _map(data['images']);
      pricing = _map(data['pricing']);
      _replaceCatalog(data['products'], data['offers'], reconcileCart: false);
      _publicRevision = data['revision']?.toString();
      usingFallback = true;
    } catch (_) {
      await _storage.clearPublicSnapshot();
    }
  }

  Future<void> loadPublicData({bool silent = false}) async {
    if (!silent) _setBusy(true);
    try {
      final responses = await Future.wait<dynamic>([
        api.get('/public/restaurant'),
        api.get('/public/restaurant/images'),
        api.get('/public/products'),
        api.get('/public/offers'),
        api.get('/public/pricing'),
      ]);
      final restaurantData = _map(responses[0]);
      restaurant =
          RestaurantProfile.fromJson(_map(restaurantData['restaurant']));
      restaurantImages = _map(_map(responses[1])['images']);
      pricing = _map(responses[4]);

      final catalog = <Product>[];
      final rawProducts = <Map<String, dynamic>>[];
      final grouped = _map(_map(responses[2])['grouped']);
      for (final group in grouped.values) {
        final products = _map(group)['products'];
        if (products is List) {
          final items = products
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
          rawProducts.addAll(items);
          catalog.addAll(items.map(Product.fromProductJson));
        }
      }
      final rawOffers = _map(responses[3])['offers'];
      if (rawOffers is List) {
        catalog.addAll(rawOffers.whereType<Map>().map(
              (item) => Product.fromOfferJson(Map<String, dynamic>.from(item)),
            ));
      }
      productsCatalog
        ..clear()
        ..addAll(catalog);
      await _storage.writePublicSnapshot(
        jsonEncode({
          'restaurant': restaurantData['restaurant'],
          'images': restaurantImages,
          'products': rawProducts,
          'offers': rawOffers is List ? rawOffers : const [],
          'pricing': pricing,
        }),
      );
      isOnline = true;
      usingFallback = false;
      lastError = null;
    } on ApiException catch (error) {
      isOnline = false;
      usingFallback = true;
      lastError = error.message;
      if (!silent) rethrow;
    } finally {
      if (!silent) _setBusy(false);
    }
  }

  void toggleLanguage() {
    language = language == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar;
    unawaited(_storage.writeLanguage(language.code));
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    unawaited(_storage.writeTheme(isDarkMode));
    notifyListeners();
  }

  Future<void> signIn(
      {required String identifier, required String password}) async {
    _setBusy(true);
    try {
      final data = _map(await api.post('/customer/auth/login', body: {
        'identifier': identifier.trim(),
        'password': password,
      }));
      await _applyAuthentication(data);
      await refreshCustomerData(
        silent: true,
        announceNotifications: false,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> register({
    required String fullName,
    String? email,
    String? phone,
    String? address,
    DateTime? birthDate,
    required String password,
    required String passwordConfirmation,
  }) async {
    _setBusy(true);
    try {
      final body = <String, dynamic>{
        'name': fullName.trim(),
        if (email?.trim().isNotEmpty ?? false) 'email': email!.trim(),
        if (phone?.trim().isNotEmpty ?? false) 'phone': phone!.trim(),
        if (address?.trim().isNotEmpty ?? false) 'address': address!.trim(),
        if (birthDate != null) 'date_of_birth': _dateOnly(birthDate),
        'password': password,
        'password_confirmation': passwordConfirmation,
      };
      final data = _map(await api.post('/customer/auth/register', body: body));
      await _applyAuthentication(data);
      await refreshCustomerData(
        silent: true,
        announceNotifications: false,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> requestPasswordReset(String identifier) => api.post(
        '/customer/auth/forgot-password',
        body: {'identifier': identifier.trim()},
      );

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String confirmation,
  }) =>
      api.post('/customer/auth/reset-password', body: {
        'identifier': identifier.trim(),
        'code': code.trim(),
        'password': password,
        'password_confirmation': confirmation,
      });

  Future<void> _applyAuthentication(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('لم يُرجع الخادم جلسة دخول صالحة.');
    }
    await api.saveToken(token);
    currentUser = AppUser.fromJson(
      _map(data['customer']),
      loyalty: _mapOrNull(data['loyalty']),
    );
    isAuthenticated = true;
    lastError = null;
    notifyListeners();
  }

  Future<void> refreshCustomerData({
    bool silent = false,
    bool announceNotifications = true,
  }) async {
    if (!api.hasToken) return;
    if (!silent) _setBusy(true);
    try {
      final responses = await Future.wait<dynamic>([
        api.get('/customer/profile'),
        api.get('/customer/notifications'),
        api.get('/customer/orders'),
        api.get('/customer/saved-addresses'),
      ]);
      final profile = _map(responses[0]);
      currentUser = AppUser.fromJson(
        _map(profile['customer']),
        loyalty: _mapOrNull(profile['loyalty']),
      );
      await _mergeSavedAddressesSnapshot(_map(responses[3])['addresses']);
      _replaceNotifications(
        _map(responses[1])['notifications'],
        announceNew: announceNotifications,
      );
      final orderList = _map(responses[2])['orders'];
      orders
        ..clear()
        ..addAll(
          orderList is List
              ? orderList.whereType<Map>().map(
                    (item) =>
                        OrderRecord.fromJson(Map<String, dynamic>.from(item)),
                  )
              : const <OrderRecord>[],
        );
      isAuthenticated = true;
      isOnline = true;
      lastError = null;
    } on ApiException catch (error) {
      lastError = error.message;
      if (error.isUnauthorized) await _clearSession();
      rethrow;
    } finally {
      if (!silent) _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> refreshOrdersLive() async {
    if (!api.hasToken || _ordersRefreshInFlight) return;
    _ordersRefreshInFlight = true;
    try {
      final data = _map(await api.get('/customer/orders'));
      final rawOrders = data['orders'];
      final nextOrders = rawOrders is List
          ? rawOrders
              .whereType<Map>()
              .map((item) =>
                  OrderRecord.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <OrderRecord>[];
      if (_orderStateFingerprint(nextOrders) ==
          _orderStateFingerprint(orders)) {
        return;
      }
      orders
        ..clear()
        ..addAll(nextOrders);
      isOnline = true;
      lastError = null;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized) await _clearSession();
    } finally {
      _ordersRefreshInFlight = false;
    }
  }

  Future<void> refreshNotificationsLive() async {
    if (!api.hasToken || _notificationsRefreshInFlight) return;
    _notificationsRefreshInFlight = true;
    try {
      final data = _map(await api.get('/customer/notifications'));
      final raw = data['notifications'];
      final next = raw is List
          ? raw
              .whereType<Map>()
              .map((item) =>
                  NotificationItem.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <NotificationItem>[];
      if (_notificationFingerprint(next) ==
          _notificationFingerprint(notifications)) {
        return;
      }
      _replaceNotifications(next);
      isOnline = true;
      lastError = null;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized) await _clearSession();
    } finally {
      _notificationsRefreshInFlight = false;
    }
  }

  Future<void> refreshSavedAddressesLive() async {
    if (!api.hasToken || _savedAddressesRefreshInFlight) return;
    _savedAddressesRefreshInFlight = true;
    try {
      final before = _savedAddressFingerprint(savedAddresses);
      final data = _map(await api.get('/customer/saved-addresses'));
      await _mergeSavedAddressesSnapshot(data['addresses']);
      if (before != _savedAddressFingerprint(savedAddresses)) {
        notifyListeners();
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) await _clearSession();
    } finally {
      _savedAddressesRefreshInFlight = false;
    }
  }

  String _notificationFingerprint(List<NotificationItem> source) =>
      jsonEncode(source.map((item) => [item.id, item.isRead]).toList());

  void _replaceNotifications(dynamic raw, {bool announceNew = true}) {
    final next = raw is List<NotificationItem>
        ? raw
        : raw is List
            ? raw
                .whereType<Map>()
                .map((item) =>
                    NotificationItem.fromJson(Map<String, dynamic>.from(item)))
                .toList(growable: false)
            : const <NotificationItem>[];
    final knownIds = notifications.map((item) => item.id).toSet();
    final shouldAnnounce = announceNew && _notificationBaselineReady;
    notifications
      ..clear()
      ..addAll(next);
    _notificationBaselineReady = true;

    if (!shouldAnnounce || _notificationEvents.isClosed) return;
    for (final item in next
        .where((item) => !item.isRead && !knownIds.contains(item.id))
        .take(1)) {
      _notificationEvents.add(item);
    }
  }

  String _orderStateFingerprint(List<OrderRecord> source) => jsonEncode(
        source
            .map((order) => [
                  order.id,
                  order.status.name,
                  order.deliveryStatus,
                  order.reservationStatus,
                  order.driver?.id,
                  order.canRateDriver,
                ])
            .toList(growable: false),
      );

  String _savedAddressFingerprint(List<SavedAddress> source) =>
      jsonEncode(source.map((item) => item.toJson()).toList(growable: false));

  Future<void> logout() async {
    try {
      if (api.hasToken) await api.post('/customer/auth/logout');
    } catch (_) {
      // The local session must still be cleared if the token expired offline.
    }
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    await api.clearToken();
    isAuthenticated = false;
    currentUser =
        AppUser(fullName: 'Guest', email: '', phone: '', loyaltyPoints: 0);
    notifications.clear();
    _notificationBaselineReady = false;
    orders.clear();
    for (var index = 0; index < savedAddresses.length; index++) {
      savedAddresses[index] =
          SavedAddress(type: SavedAddressType.values[index]);
    }
    hasPendingSavedAddressMigration = false;
    await _storage.clearSavedAddresses();
    await _storage.clearSavedAddressesOwner();
    _cart.clear();
    await _saveCart();
    await _clearPendingOrder();
    resetOrderFlow(notify: false);
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    required String phone,
    DateTime? birthDate,
    String? bio,
    String? city,
    String? imageLabel,
    required String currentPassword,
    String? newPassword,
    String? newPasswordConfirmation,
  }) async {
    _setBusy(true);
    try {
      final data = _map(await api.put('/customer/profile', body: {
        'name': fullName.trim(),
        'phone': phone.trim(),
        'address': city?.trim() ?? '',
        'bio': bio?.trim() ?? '',
        'date_of_birth': birthDate == null ? null : _dateOnly(birthDate),
        'current_password': currentPassword,
        if (newPassword?.isNotEmpty ?? false) 'new_password': newPassword,
        if (newPassword?.isNotEmpty ?? false)
          'new_password_confirmation': newPasswordConfirmation,
      }));
      currentUser = AppUser.fromJson(
        _map(data['customer']),
        loyalty: {
          'points': currentUser.loyaltyPoints,
          'tier': currentUser.loyaltyTier
        },
      );
      if (newPassword?.isNotEmpty ?? false) {
        await api.clearToken();
        isAuthenticated = false;
      }
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> updateAvatar({
    required List<int> bytes,
    required String filename,
    required String currentPassword,
  }) async {
    final data = _map(await api.uploadImage(
      '/customer/avatar',
      bytes: bytes,
      filename: filename,
      currentPassword: currentPassword,
    ));
    currentUser.avatarUrl = ApiConfig.assetUrl(
      (data['avatar_url'] ?? data['avatar'])?.toString(),
    );
    notifyListeners();
  }

  void addToCart(Product product) {
    if (!product.isAvailable || product.referenceId == null) return;
    final key = '${product.itemType.name}:${product.id}';
    final item = _cart[key];
    if (item != null) {
      if (item.quantity < product.maxQuantity) item.quantity += 1;
    } else {
      _cart[key] = CartItem(product: product, quantity: 1);
    }
    _saveCart();
    notifyListeners();
  }

  void decreaseFromCart(Product product) {
    final key = '${product.itemType.name}:${product.id}';
    final item = _cart[key];
    if (item == null) return;
    item.quantity -= 1;
    if (item.quantity <= 0) _cart.remove(key);
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((_, item) => item.product.id == productId);
    _saveCart();
    notifyListeners();
  }

  void setOrderType(OrderType type) {
    currentOrderType = type;
    notifyListeners();
  }

  void openMenu({required OrderType orderType, String? highlightId}) {
    currentOrderType = orderType;
    highlightedProductId = highlightId;
    notifyListeners();
  }

  Future<Map<String, dynamic>> quoteDelivery({
    required double latitude,
    required double longitude,
  }) async {
    final data = _map(await api.get('/public/delivery/quote', query: {
      'latitude': latitude,
      'longitude': longitude,
    }));
    if (data['is_within_range'] != true) {
      throw const ApiException('الموقع المحدد خارج نطاق التوصيل الحالي.');
    }
    return data;
  }

  void confirmDeliveryLocation({
    required String addressAr,
    required String addressEn,
    required int distanceMeters,
    double? latitude,
    double? longitude,
    double? quotedCost,
    List<List<double>> routeGeometry = const [],
    int? durationMinutes,
    bool routeIsFallback = false,
  }) {
    selectedDeliveryAddressAr = addressAr;
    selectedDeliveryAddressEn = addressEn;
    selectedDeliveryDistanceMeters = distanceMeters;
    selectedDeliveryLatitude = latitude;
    selectedDeliveryLongitude = longitude;
    deliveryCost = quotedCost ?? _deliveryCostEstimate(distanceMeters);
    selectedDeliveryRouteGeometry = List<List<double>>.unmodifiable(
      routeGeometry.map((point) => List<double>.unmodifiable(point)),
    );
    selectedDeliveryDurationMinutes = durationMinutes;
    selectedDeliveryRouteIsFallback = routeIsFallback;
    notifyListeners();
  }

  void clearConfirmedDeliveryLocation() {
    selectedDeliveryDistanceMeters = null;
    selectedDeliveryLatitude = null;
    selectedDeliveryLongitude = null;
    deliveryCost = 0;
    selectedDeliveryRouteGeometry = const [];
    selectedDeliveryDurationMinutes = null;
    selectedDeliveryRouteIsFallback = false;
    notifyListeners();
  }

  double _deliveryCostEstimate(int distanceMeters) {
    final delivery = _map(pricing['delivery']);
    final perKm = _toDouble(delivery['cost_per_km'], 50);
    return (distanceMeters / 1000) * perKm;
  }

  Future<bool> tableIsAvailable({
    required int tableNumber,
    required DateTime reservationTime,
    int durationMinutes = 60,
  }) async {
    final tables = await loadReservationTables(
      reservationTime: reservationTime,
      durationMinutes: durationMinutes,
    );
    final table =
        tables.where((item) => item.number == tableNumber).firstOrNull;
    return table?.isAvailable == true;
  }

  Future<List<ReservationTable>> loadReservationTables({
    DateTime? reservationTime,
    int durationMinutes = 60,
  }) async {
    final data = _map(await api.get('/public/reservations/tables', query: {
      if (reservationTime != null)
        'reservation_time': reservationTime.toIso8601String(),
      'duration_minutes': durationMinutes,
    }));
    final raw = data['tables'];
    final next = raw is List
        ? raw
            .whereType<Map>()
            .map((item) =>
                ReservationTable.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <ReservationTable>[];
    reservationTables
      ..clear()
      ..addAll(next);
    final livePricing = _map(data['pricing_info']);
    if (livePricing.isNotEmpty) {
      pricing = {
        ...pricing,
        'reservation': {
          ..._map(pricing['reservation']),
          ...livePricing,
        },
      };
    }
    notifyListeners();
    return List.unmodifiable(reservationTables);
  }

  void confirmReservation({
    required int tableNumber,
    required bool isVip,
    required String reservationTime,
    required int seatsCount,
    int durationMinutes = 60,
    String notes = '',
  }) {
    selectedTableNumber = tableNumber;
    selectedTableIsVip = isVip;
    selectedReservationTime = reservationTime;
    selectedSeatsCount = seatsCount;
    reservationDurationMinutes = durationMinutes;
    reservationNotes = notes;
    final reservation = _map(pricing['reservation']);
    final vipExtra = _toDouble(
      reservation['vip_extra_cost'] ?? reservation['vip_table_extra_cost'],
      50,
    );
    final freeSeats = _toInt(
      reservation['free_seats'] ?? reservation['free_seats_count'],
      4,
    );
    final perSeat = _toDouble(reservation['cost_per_extra_seat'], 20);
    reservationExtra = (isVip ? vipExtra : 0) +
        ((seatsCount - freeSeats).clamp(0, seatsCount) * perSeat);
    notifyListeners();
  }

  Future<void> markNotificationRead(String id) async {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index == -1 || notifications[index].isRead) return;
    await api.put('/customer/notifications/$id/read');
    notifications[index].isRead = true;
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await api.put('/customer/notifications/read-all');
    for (final item in notifications) {
      item.isRead = true;
    }
    notifyListeners();
  }

  Product? productById(String id) {
    for (final product in productsCatalog) {
      if (product.id == id) return product;
    }
    return null;
  }

  int loyaltyPointsForAmount(double amount) => (amount / 10).floor();
  int requiredLoyaltyPoints(double amount) => (amount / 10).ceil();

  Future<OrderRecord> completeOrder(
    PaymentMethod paymentMethod, {
    String? phone,
    String? pinCode,
  }) async {
    if (!isAuthenticated) throw const ApiException('سجّل الدخول لإكمال الطلب.');
    if (cartItems.isEmpty) throw const ApiException('السلة فارغة.');
    if (!restaurant.isOpen) throw const ApiException('المطعم مغلق الآن.');
    _validateOrderContext();
    _setBusy(true);
    try {
      final checkoutFingerprint = _checkoutFingerprint();
      if (_pendingOrderId != null &&
          _storage.pendingOrderFingerprint != checkoutFingerprint) {
        await _clearPendingOrder();
      }
      String orderId;
      Map<String, dynamic>? orderJson;
      if (_pendingOrderId != null) {
        orderId = _pendingOrderId!;
      } else {
        final created =
            _map(await api.post('/customer/orders', body: _orderPayload()));
        orderJson = _map(created['order']);
        orderId = '${orderJson['id']}';
        if (orderId == 'null' || orderId.isEmpty) {
          throw const ApiException('تعذر قراءة رقم الطلب الجديد من الخادم.');
        }
        _pendingOrderId = orderId;
        await _storage.savePendingOrder(
          id: orderId,
          fingerprint: checkoutFingerprint,
        );
      }

      final paymentBody = <String, dynamic>{
        'method': switch (paymentMethod) {
          PaymentMethod.cash => 'cash',
          PaymentMethod.syriatelCash => 'syriatel_cash',
          PaymentMethod.shamCash => 'sham_cash',
          PaymentMethod.loyaltyPoints => 'loyalty_points',
        },
        if (paymentMethod == PaymentMethod.syriatelCash ||
            paymentMethod == PaymentMethod.shamCash) ...{
          'phone': phone?.trim() ?? currentUser.phone,
          'pin_code': pinCode?.trim() ?? '',
        },
        if (paymentMethod == PaymentMethod.loyaltyPoints)
          'points_required': requiredLoyaltyPoints(orderGrandTotal),
        if (paymentMethod == PaymentMethod.cash)
          'notes': language == AppLanguage.ar
              ? 'دفع نقدي عند الاستلام'
              : 'Cash on delivery / pickup',
      };
      try {
        await api.post('/customer/orders/$orderId/pay', body: paymentBody);
      } on ApiException catch (error) {
        if (error.statusCode == 404 && orderJson == null) {
          await _clearPendingOrder();
        }
        rethrow;
      }
      await _clearPendingOrder();
      _cart.clear();
      await _saveCart();
      resetOrderFlow(notify: false);
      await refreshCustomerData(
        silent: true,
        announceNotifications: false,
      );
      return orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => OrderRecord.fromJson(orderJson ?? {'id': orderId}),
      );
    } finally {
      _setBusy(false);
    }
  }

  String _checkoutFingerprint() => jsonEncode({
        'type': currentOrderType.name,
        'items': cartItems
            .map((item) => [
                  item.product.itemType.name,
                  item.product.referenceId,
                  item.quantity,
                ])
            .toList(growable: false),
        'delivery': currentOrderType == OrderType.delivery
            ? [selectedDeliveryLatitude, selectedDeliveryLongitude]
            : null,
        'reservation': currentOrderType == OrderType.reservation
            ? [selectedTableNumber, selectedReservationTime, selectedSeatsCount]
            : null,
      });

  Future<void> _clearPendingOrder() async {
    _pendingOrderId = null;
    await _storage.clearPendingOrder();
  }

  void _validateOrderContext() {
    for (final item in cartItems) {
      if (item.product.referenceId == null || !item.product.isAvailable) {
        throw const ApiException(
            'تحتوي السلة على عنصر لم يعد متاحًا. حدّث القائمة وأعد إضافته.');
      }
    }
    final missingDeliveryAddress = selectedDeliveryAddressAr?.isEmpty ?? true;
    if (currentOrderType == OrderType.delivery &&
        (missingDeliveryAddress ||
            selectedDeliveryLatitude == null ||
            selectedDeliveryLongitude == null)) {
      throw const ApiException('حدد موقع التوصيل على الخريطة أولًا.');
    }
    if (currentOrderType == OrderType.reservation &&
        (selectedTableNumber == null || selectedReservationTime == null)) {
      throw const ApiException('أكد الطاولة وموعد الحجز أولًا.');
    }
  }

  Map<String, dynamic> _orderPayload() {
    final payload = <String, dynamic>{
      'type': switch (currentOrderType) {
        OrderType.ordinary => 'normal',
        OrderType.delivery => 'delivery',
        OrderType.reservation => 'reservation',
      },
      'notes': orderNotes.trim(),
      'items': cartItems
          .map((item) => {
                'item_type': item.product.itemType.name,
                'reference_id': item.product.referenceId,
                'quantity': item.quantity,
              })
          .toList(),
    };
    if (currentOrderType == OrderType.delivery) {
      payload.addAll({
        'delivery_address': selectedDeliveryAddressAr,
        'latitude': selectedDeliveryLatitude,
        'longitude': selectedDeliveryLongitude,
      });
    }
    if (currentOrderType == OrderType.reservation) {
      payload.addAll({
        'table_number': selectedTableNumber,
        'table_type': selectedTableIsVip ? 'vip' : 'normal',
        'seats_count': selectedSeatsCount,
        'reservation_time': selectedReservationTime,
        'duration_minutes': reservationDurationMinutes,
        'special_notes': reservationNotes,
      });
    }
    return payload;
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final data = _map(await api.delete('/customer/orders/$orderId'));
    await refreshCustomerData(silent: true);
    notifyListeners();
    return _map(data['refund']);
  }

  Future<OrderType> prepareReorder(String orderId) async {
    final data = _map(await api.get('/customer/orders/$orderId'));
    final order = OrderRecord.fromJson(_map(data['order']));
    final nextCart = <String, CartItem>{};
    for (final oldItem in order.items) {
      final product = productsCatalog
          .where((candidate) =>
              candidate.id == oldItem.product.id &&
              candidate.itemType == oldItem.product.itemType &&
              candidate.isAvailable)
          .firstOrNull;
      if (product == null) continue;
      nextCart['${product.itemType.name}:${product.id}'] = CartItem(
        product: product,
        quantity: oldItem.quantity.clamp(1, product.maxQuantity),
        note: oldItem.note,
      );
    }
    if (nextCart.isEmpty) {
      throw const ApiException(
          'لا توجد عناصر متاحة حاليًا من هذا الطلب لإضافتها إلى السلة.');
    }
    _cart
      ..clear()
      ..addAll(nextCart);
    currentOrderType = order.type;
    orderNotes = order.notes;
    resetOrderFlow(notify: false);
    currentOrderType = order.type;
    orderNotes = order.notes;
    await _saveCart();
    notifyListeners();
    return order.type;
  }

  Future<void> reportUnavailable(Product product) async {
    final productId = product.referenceId;
    if (!isAuthenticated ||
        product.itemType != CatalogItemType.product ||
        productId == null ||
        reportedUnavailableProductIds.contains(productId)) {
      return;
    }
    await api.post('/customer/products/$productId/report-unavailable');
    reportedUnavailableProductIds.add(productId);
    notifyListeners();
  }

  Future<void> saveAddress(
    SavedAddress address, {
    required String currentPassword,
  }) async {
    if (!address.hasAddress || !address.isPinned) {
      throw const ApiException(
        'يجب كتابة وصف العنوان وتثبيت موقعه على الخريطة قبل الحفظ.',
      );
    }
    final data = _map(await api.put(
      '/customer/saved-addresses/${address.type.name}',
      body: {
        ...address.toJson(),
        'current_password': currentPassword,
      },
    ));
    await _replaceSavedAddressesSnapshot(data['addresses']);
    notifyListeners();
  }

  Future<void> clearAddress(
    SavedAddressType type, {
    required String currentPassword,
  }) async {
    final data = _map(await api.delete(
      '/customer/saved-addresses/${type.name}',
      body: {'current_password': currentPassword},
    ));
    await _replaceSavedAddressesSnapshot(data['addresses']);
    notifyListeners();
  }

  Future<void> syncPendingSavedAddresses({
    required String currentPassword,
  }) async {
    final addresses = savedAddresses
        .where((address) => address.hasAddress && address.isPinned)
        .map((address) => address.toJson())
        .toList(growable: false);
    final data = _map(await api.put('/customer/saved-addresses', body: {
      'addresses': addresses,
      'current_password': currentPassword,
    }));
    await _replaceSavedAddressesSnapshot(data['addresses']);
    notifyListeners();
  }

  Future<void> _mergeSavedAddressesSnapshot(dynamic raw) async {
    final remote = _parseSavedAddresses(raw);
    final owner = _storage.savedAddressesOwner;
    final customerId = currentUser.id;
    final legacyCache = owner == null;
    var pendingMigration = false;

    for (final type in SavedAddressType.values) {
      final index = savedAddresses.indexWhere((item) => item.type == type);
      if (index == -1) continue;
      final serverAddress = remote[type];
      final cachedAddress = savedAddresses[index];
      if (serverAddress != null) {
        savedAddresses[index] = serverAddress;
      } else if (legacyCache &&
          cachedAddress.hasAddress &&
          cachedAddress.isPinned) {
        pendingMigration = true;
      } else {
        savedAddresses[index] = SavedAddress(type: type);
      }
    }

    hasPendingSavedAddressMigration = pendingMigration;
    await _cacheSavedAddresses();
    if (!pendingMigration && customerId != null) {
      await _storage.writeSavedAddressesOwner(customerId);
    }
  }

  Future<void> _replaceSavedAddressesSnapshot(dynamic raw) async {
    final remote = _parseSavedAddresses(raw);
    for (final type in SavedAddressType.values) {
      final index = savedAddresses.indexWhere((item) => item.type == type);
      if (index != -1) {
        savedAddresses[index] = remote[type] ?? SavedAddress(type: type);
      }
    }
    hasPendingSavedAddressMigration = false;
    await _cacheSavedAddresses();
    if (currentUser.id != null) {
      await _storage.writeSavedAddressesOwner(currentUser.id!);
    }
  }

  Map<SavedAddressType, SavedAddress> _parseSavedAddresses(dynamic raw) {
    if (raw is! List) return const {};
    return {
      for (final item in raw.whereType<Map>())
        SavedAddress.fromJson(Map<String, dynamic>.from(item)).type:
            SavedAddress.fromJson(Map<String, dynamic>.from(item)),
    };
  }

  Future<void> _cacheSavedAddresses() => _storage.writeSavedAddresses(
        jsonEncode(savedAddresses.map((item) => item.toJson()).toList()),
      );

  Future<void> _restoreSavedAddresses() async {
    var raw = await _storage.readSavedAddresses();
    final legacyRaw = _storage.legacySavedAddresses;
    final isLegacy = (raw == null || raw.isEmpty) &&
        legacyRaw != null &&
        legacyRaw.isNotEmpty;
    if (isLegacy) raw = legacyRaw;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded.whereType<Map>()) {
        final address = SavedAddress.fromJson(Map<String, dynamic>.from(item));
        final index = savedAddresses
            .indexWhere((current) => current.type == address.type);
        if (index != -1) savedAddresses[index] = address;
      }
      if (isLegacy) {
        await _storage.writeSavedAddresses(
          jsonEncode(savedAddresses.map((item) => item.toJson()).toList()),
        );
        await _storage.clearLegacySavedAddresses();
      }
    } on FormatException {
      await _storage.clearSavedAddresses();
      await _storage.clearLegacySavedAddresses();
    }
  }

  Future<void> rateDriver({
    required int deliveryId,
    required int rating,
    String feedback = '',
  }) async {
    await api.post('/customer/delivery/$deliveryId/rate', body: {
      'rating': rating,
      'feedback': feedback.trim(),
    });
    await refreshCustomerData(silent: true);
    notifyListeners();
  }

  Future<void> rateProduct({
    required String orderId,
    required int productId,
    required int rating,
    String comment = '',
  }) async {
    await api.post('/customer/orders/$orderId/products/$productId/rate', body: {
      'rating': rating,
      'comment': comment.trim(),
    });
    await refreshCustomerData(silent: true);
    notifyListeners();
  }

  void deleteCancelledOrder(String orderId) {
    // Laravel intentionally keeps cancelled orders as immutable history.
  }

  Future<Map<String, dynamic>> sendAiMessage(String message) async {
    final endpoint = isAuthenticated ? '/customer/ai/chat' : '/public/ai/chat';
    final data = _map(await api.post(endpoint, body: {
      'message': message.trim(),
      if (aiConversationId != null) 'conversation_id': aiConversationId,
    }));
    aiConversationId = _toInt(data['conversation_id']) == 0
        ? aiConversationId
        : _toInt(data['conversation_id']);
    return data;
  }

  void resetOrderFlow({bool notify = true}) {
    highlightedProductId = null;
    selectedDriver = null;
    selectedDeliveryAddressAr = null;
    selectedDeliveryAddressEn = null;
    selectedDeliveryDistanceMeters = null;
    selectedDeliveryLatitude = null;
    selectedDeliveryLongitude = null;
    deliveryCost = 0;
    selectedDeliveryRouteGeometry = const [];
    selectedDeliveryDurationMinutes = null;
    selectedDeliveryRouteIsFallback = false;
    selectedTableNumber = null;
    selectedTableIsVip = false;
    selectedReservationTime = null;
    selectedSeatsCount = 2;
    reservationDurationMinutes = 60;
    reservationNotes = '';
    reservationExtra = 0;
    orderNotes = '';
    currentOrderType = OrderType.ordinary;
    if (notify) notifyListeners();
  }

  Future<void> _saveCart() async {
    await _storage.writeCartSnapshot(
      jsonEncode(cartItems.map((item) => item.toJson()).toList()),
    );
  }

  void _restoreCart() {
    final raw = _storage.cartSnapshot;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded.whereType<Map>()) {
        final id = '${entry['id']}';
        final type = '${entry['item_type']}';
        final product = productsCatalog.where((item) {
          return item.id == id &&
              item.itemType.name == type &&
              item.isAvailable;
        }).firstOrNull;
        if (product == null) continue;
        final quantity =
            _toInt(entry['quantity'], 1).clamp(1, product.maxQuantity);
        _cart['$type:$id'] = CartItem(
          product: product,
          quantity: quantity,
          note: (entry['note'] ?? '').toString(),
        );
      }
    } catch (_) {
      unawaited(_storage.clearCartSnapshot());
    }
  }

  void _setBusy(bool value) {
    final wasBusy = isBusy;
    if (value) {
      _busyOperations += 1;
    } else if (_busyOperations > 0) {
      _busyOperations -= 1;
    }
    isBusy = _busyOperations > 0;
    if (wasBusy != isBusy) notifyListeners();
  }

  String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Map<String, dynamic>? _mapOrNull(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  int _toInt(dynamic value, [int fallback = 0]) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  double _toDouble(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

  @override
  void dispose() {
    _sync.dispose();
    _notificationEvents.close();
    api.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
