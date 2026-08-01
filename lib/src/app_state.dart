import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'mock_data.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? apiClient}) : api = apiClient ?? ApiClient();

  static const _languageKey = 'taza_language';
  static const _themeKey = 'taza_theme_dark';
  static const _cartKey = 'taza_cart';
  static const _pendingOrderKey = 'taza_pending_order_id';
  static const _savedAddressesKey = 'taza_saved_addresses';

  final ApiClient api;
  SharedPreferences? _preferences;

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

  int? selectedTableNumber;
  bool selectedTableIsVip = false;
  String? selectedReservationTime;
  int selectedSeatsCount = 2;
  int reservationDurationMinutes = 60;
  String reservationNotes = '';
  double reservationExtra = 0;
  int? aiConversationId;
  String? _pendingOrderId;

  List<CartItem> get cartItems => _cart.values.toList(growable: false);
  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartSubtotal =>
      _cart.values.fold(0, (sum, item) => sum + item.subtotal);
  double get extrasTotal => deliveryCost + reservationExtra;
  double get orderGrandTotal => cartSubtotal + extrasTotal;
  int get unreadNotifications =>
      notifications.where((item) => !item.isRead).length;

  Future<void> initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      language = (_preferences?.getString(_languageKey) ?? 'ar') == 'en'
          ? AppLanguage.en
          : AppLanguage.ar;
      isDarkMode = _preferences?.getBool(_themeKey) ?? true;
      _pendingOrderId = _preferences?.getString(_pendingOrderKey);
      _restoreSavedAddresses();
      await api.restoreToken();
      await loadPublicData(silent: true);
      _restoreCart();
      if (api.hasToken) {
        try {
          await refreshCustomerData(silent: true);
          isAuthenticated = true;
        } on ApiException catch (error) {
          if (error.isUnauthorized) await _clearSession();
        }
      }
    } finally {
      isInitializing = false;
      notifyListeners();
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
      final grouped = _map(_map(responses[2])['grouped']);
      for (final group in grouped.values) {
        final products = _map(group)['products'];
        if (products is List) {
          catalog.addAll(products.whereType<Map>().map(
                (item) =>
                    Product.fromProductJson(Map<String, dynamic>.from(item)),
              ));
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
      isOnline = true;
      usingFallback = false;
      lastError = null;
    } on ApiException catch (error) {
      isOnline = false;
      usingFallback = true;
      lastError = error.message;
      if (productsCatalog.isEmpty) {
        productsCatalog.addAll(products.map(_disabledFallback));
      }
      if (!silent) rethrow;
    } finally {
      if (!silent) _setBusy(false);
    }
  }

  Product _disabledFallback(Product product) => Product(
        id: product.id,
        nameAr: product.nameAr,
        nameEn: product.nameEn,
        descriptionAr: product.descriptionAr,
        descriptionEn: product.descriptionEn,
        category: product.category,
        price: product.price,
        rating: product.rating,
        ratingCount: product.ratingCount,
        oldPrice: product.oldPrice,
        isFeatured: product.isFeatured,
        placeholderLabel: product.placeholderLabel,
        isAvailable: false,
        itemType: product.category == ProductCategory.offer
            ? CatalogItemType.offer
            : CatalogItemType.product,
      );

  void toggleLanguage() {
    language = language == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar;
    _preferences?.setString(_languageKey, language.code);
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    _preferences?.setBool(_themeKey, isDarkMode);
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
      await refreshCustomerData(silent: true);
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
      await refreshCustomerData(silent: true);
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

  Future<void> refreshCustomerData({bool silent = false}) async {
    if (!api.hasToken) return;
    if (!silent) _setBusy(true);
    try {
      final responses = await Future.wait<dynamic>([
        api.get('/customer/profile'),
        api.get('/customer/notifications'),
        api.get('/customer/orders'),
      ]);
      final profile = _map(responses[0]);
      currentUser = AppUser.fromJson(
        _map(profile['customer']),
        loyalty: _mapOrNull(profile['loyalty']),
      );
      final notificationList = _map(responses[1])['notifications'];
      notifications
        ..clear()
        ..addAll(
          notificationList is List
              ? notificationList.whereType<Map>().map((item) =>
                  NotificationItem.fromJson(Map<String, dynamic>.from(item)))
              : const <NotificationItem>[],
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
    orders.clear();
    _cart.clear();
    await _saveCart();
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
    String? currentPassword,
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
        if (newPassword?.isNotEmpty ?? false)
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
    String? currentPassword,
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
  }) {
    selectedDeliveryAddressAr = addressAr;
    selectedDeliveryAddressEn = addressEn;
    selectedDeliveryDistanceMeters = distanceMeters;
    selectedDeliveryLatitude = latitude;
    selectedDeliveryLongitude = longitude;
    deliveryCost = quotedCost ?? _deliveryCostEstimate(distanceMeters);
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
    final data = _map(await api.get(
      '/public/reservations/table/$tableNumber/availability',
      query: {
        'reservation_time': reservationTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'live': 1,
      },
    ));
    return data['is_available'] == true || data['available'] == true;
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
    final vipExtra = _toDouble(reservation['vip_table_extra_cost'], 50);
    final freeSeats = _toInt(reservation['free_seats_count'], 0);
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
        await _preferences?.setString(_pendingOrderKey, orderId);
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
      await api.post('/customer/orders/$orderId/pay', body: paymentBody);
      _pendingOrderId = null;
      await _preferences?.remove(_pendingOrderKey);
      _cart.clear();
      await _saveCart();
      resetOrderFlow(notify: false);
      await refreshCustomerData(silent: true);
      return orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => OrderRecord.fromJson(orderJson ?? {'id': orderId}),
      );
    } finally {
      _setBusy(false);
    }
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

  Future<void> cancelOrder(String orderId) async {
    await api.delete('/customer/orders/$orderId');
    await refreshCustomerData(silent: true);
    notifyListeners();
  }

  Future<void> saveAddress(SavedAddress address) async {
    final index =
        savedAddresses.indexWhere((item) => item.type == address.type);
    if (index == -1) return;
    savedAddresses[index] = address;
    await _preferences?.setString(
      _savedAddressesKey,
      jsonEncode(savedAddresses.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }

  void _restoreSavedAddresses() {
    final raw = _preferences?.getString(_savedAddressesKey);
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
    } on FormatException {
      _preferences?.remove(_savedAddressesKey);
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
    selectedTableNumber = null;
    selectedTableIsVip = false;
    selectedReservationTime = null;
    selectedSeatsCount = 2;
    reservationDurationMinutes = 60;
    reservationNotes = '';
    reservationExtra = 0;
    currentOrderType = OrderType.ordinary;
    if (notify) notifyListeners();
  }

  Future<void> _saveCart() async {
    await _preferences?.setString(
      _cartKey,
      jsonEncode(cartItems.map((item) => item.toJson()).toList()),
    );
  }

  void _restoreCart() {
    final raw = _preferences?.getString(_cartKey);
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
      _preferences?.remove(_cartKey);
    }
  }

  void _setBusy(bool value) {
    isBusy = value;
    notifyListeners();
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
