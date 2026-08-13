import 'package:flutter/material.dart';

import 'api_client.dart';

enum AppLanguage {
  ar('ar'),
  en('en');

  const AppLanguage(this.code);
  final String code;
}

enum OrderType { ordinary, delivery, reservation }

enum OrderStatus { pending, inProgress, confirmed, completed, cancelled }

enum ProductCategory { sandwich, meal, drink, offer }

enum CatalogItemType { product, offer }

enum PaymentMethod { cash, syriatelCash, shamCash, loyaltyPoints }

double _number(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

int _integer(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

bool _boolean(dynamic value, [bool fallback = false]) {
  if (value == true || value == 1 || value == '1' || value == 'true') {
    return true;
  }
  if (value == false || value == 0 || value == '0' || value == 'false') {
    return false;
  }
  return fallback;
}

ProductCategory _category(dynamic raw, {bool offer = false}) {
  if (offer) return ProductCategory.offer;
  return switch ('$raw'.toLowerCase()) {
    'sandwich' || 'sandwiches' => ProductCategory.sandwich,
    'drink' || 'drinks' => ProductCategory.drink,
    _ => ProductCategory.meal,
  };
}

class Product {
  const Product({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.category,
    required this.price,
    required this.rating,
    required this.ratingCount,
    this.oldPrice,
    this.isFeatured = false,
    this.placeholderLabel,
    this.imageUrl,
    this.isAvailable = true,
    this.maxQuantity = 99,
    this.itemType = CatalogItemType.product,
  });

  factory Product.fromProductJson(Map<String, dynamic> json) => Product(
        id: '${json['id']}',
        nameAr: (json['name_ar'] ?? json['name'] ?? 'منتج').toString(),
        nameEn: (json['name_en'] ?? json['name'] ?? 'Product').toString(),
        descriptionAr:
            (json['description_ar'] ?? json['description'] ?? '').toString(),
        descriptionEn:
            (json['description_en'] ?? json['description'] ?? '').toString(),
        category: _category(json['category']),
        price: _number(json['price']),
        rating: _number(json['average_rating']),
        ratingCount: _integer(json['rating_count']),
        imageUrl: ApiConfig.assetUrl(json['image_url']?.toString()),
        isAvailable: _boolean(json['is_available'], true),
        maxQuantity:
            _integer(json['max_quantity'] ?? json['stock_quantity'], 99),
      );

  factory Product.fromOfferJson(Map<String, dynamic> json) => Product(
        id: '${json['id']}',
        nameAr: (json['name_ar'] ?? json['name'] ?? 'عرض').toString(),
        nameEn: (json['name_en'] ?? json['name'] ?? 'Offer').toString(),
        descriptionAr:
            (json['description_ar'] ?? json['description'] ?? '').toString(),
        descriptionEn:
            (json['description_en'] ?? json['description'] ?? '').toString(),
        category: ProductCategory.offer,
        price: _number(json['offer_price']),
        rating: _number(json['average_rating']),
        ratingCount: _integer(json['rating_count']),
        oldPrice: _number(json['original_price']) == 0
            ? null
            : _number(json['original_price']),
        isFeatured: true,
        imageUrl: ApiConfig.assetUrl(json['image_url']?.toString()),
        isAvailable: _boolean(json['is_currently_active'], true),
        maxQuantity:
            _integer(json['max_quantity'] ?? json['max_available'], 99),
        itemType: CatalogItemType.offer,
      );

  final String id;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final ProductCategory category;
  final double price;
  final double rating;
  final int ratingCount;
  final double? oldPrice;
  final bool isFeatured;
  final String? placeholderLabel;
  final String? imageUrl;
  final bool isAvailable;
  final int maxQuantity;
  final CatalogItemType itemType;

  int? get referenceId => int.tryParse(id);
}

class CartItem {
  CartItem({
    required this.product,
    required this.quantity,
    this.note = '',
    this.canRate = false,
  });

  final Product product;
  int quantity;
  String note;
  final bool canRate;

  double get subtotal => product.price * quantity;

  Map<String, dynamic> toJson() => {
        'id': product.id,
        'item_type': product.itemType.name,
        'quantity': quantity,
        'note': note,
      };
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.messageAr,
    required this.messageEn,
    required this.timeLabelAr,
    required this.timeLabelEn,
    required this.icon,
    this.type = 'general',
    this.data = const {},
    this.isRead = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final type = '${json['type']}';
    return NotificationItem(
      id: '${json['id']}',
      titleAr: (json['title'] ?? 'إشعار').toString(),
      titleEn: (json['title_en'] ?? json['title'] ?? 'Notification').toString(),
      messageAr: (json['message'] ?? '').toString(),
      messageEn: (json['message_en'] ?? json['message'] ?? '').toString(),
      timeLabelAr: (json['created_at_human'] ?? '').toString(),
      timeLabelEn: (json['created_at_human'] ?? '').toString(),
      icon: _notificationIcon(type),
      type: type,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      isRead: _boolean(json['is_read']),
    );
  }

  final String id;
  final String titleAr;
  final String titleEn;
  final String messageAr;
  final String messageEn;
  final String timeLabelAr;
  final String timeLabelEn;
  final IconData icon;
  final String type;
  final Map<String, dynamic> data;
  bool isRead;

  bool get isOrderUpdate =>
      type.contains('order') ||
      type.contains('delivery') ||
      type.contains('reservation') ||
      type.contains('payment');
  bool get isCatalogUpdate =>
      type.contains('offer') ||
      type.contains('meal') ||
      type.contains('product');
  String? get linkedOrderId =>
      (data['order_id'] ?? data['delivery_order_id'])?.toString();
  String? get linkedCatalogId =>
      (data['offer_id'] ?? data['product_id'])?.toString();
}

IconData _notificationIcon(String type) {
  if (type.contains('payment')) return Icons.payments_outlined;
  if (type.contains('offer')) return Icons.local_offer_outlined;
  if (type.contains('delivery')) return Icons.delivery_dining_outlined;
  if (type.contains('order')) return Icons.receipt_long_outlined;
  return Icons.notifications_none_rounded;
}

class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.rating,
    required this.priceHintAr,
    required this.priceHintEn,
    this.placeholderLabel,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final double rating;
  final String priceHintAr;
  final String priceHintEn;
  final String? placeholderLabel;
}

class AppUser {
  AppUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.loyaltyPoints,
    this.loyaltyTier = 'bronze',
    this.loyaltyMultiplier = 1.0,
    this.loyaltyProgress = 0,
    this.pointsToNextTier,
    this.loyaltyTiers = const [],
    this.birthDate,
    this.bio = '',
    this.city = '',
    this.imageLabel = 'Profile Image',
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json,
      {Map<String, dynamic>? loyalty}) {
    final loyaltyMap = loyalty ??
        (json['loyalty'] is Map<String, dynamic>
            ? json['loyalty'] as Map<String, dynamic>
            : null);
    final birth = json['date_of_birth']?.toString();
    return AppUser(
      id: _integer(json['id']),
      fullName: (json['name'] ?? json['full_name'] ?? 'ضيف TAZA').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      loyaltyPoints: _integer(
        loyaltyMap?['points_balance'] ??
            loyaltyMap?['points'] ??
            json['loyalty_points'],
      ),
      loyaltyTier:
          (loyaltyMap?['tier'] ?? json['loyalty_tier'] ?? 'bronze').toString(),
      loyaltyMultiplier: _number(
        loyaltyMap?['earning_multiplier'] ??
            (loyaltyMap?['earning_info'] is Map
                ? (loyaltyMap?['earning_info'] as Map)['current_multiplier']
                : null) ??
            1,
      ),
      loyaltyProgress: _number(loyaltyMap?['tier_progress']),
      pointsToNextTier: loyaltyMap?['points_to_next_tier'] == null
          ? null
          : _integer(loyaltyMap?['points_to_next_tier']),
      loyaltyTiers: loyaltyMap?['tier_catalog'] is List
          ? (loyaltyMap!['tier_catalog'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const [],
      birthDate: birth == null ? null : DateTime.tryParse(birth),
      city: (json['address'] ?? json['city'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      imageLabel: (json['name'] ?? 'Profile Image').toString(),
      avatarUrl: ApiConfig.assetUrl(
          (json['avatar_url'] ?? json['avatar'])?.toString()),
    );
  }

  int? id;
  String fullName;
  String email;
  String phone;
  int loyaltyPoints;
  String loyaltyTier;
  double loyaltyMultiplier;
  double loyaltyProgress;
  int? pointsToNextTier;
  List<Map<String, dynamic>> loyaltyTiers;
  DateTime? birthDate;
  String bio;
  String city;
  String imageLabel;
  String? avatarUrl;
}

enum SavedAddressType { home, work, other }

class SavedAddress {
  const SavedAddress({
    required this.type,
    this.address = '',
    this.details = '',
    this.latitude,
    this.longitude,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        type: SavedAddressType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => SavedAddressType.other,
        ),
        address: (json['address'] ?? '').toString(),
        details: (json['details'] ?? '').toString(),
        latitude: json['latitude'] == null ? null : _number(json['latitude']),
        longitude:
            json['longitude'] == null ? null : _number(json['longitude']),
      );

  final SavedAddressType type;
  final String address;
  final String details;
  final double? latitude;
  final double? longitude;

  bool get hasAddress => address.trim().isNotEmpty;
  bool get isPinned => latitude != null && longitude != null;
  String get displayAddress => [address.trim(), details.trim()]
      .where((value) => value.isNotEmpty)
      .join(' - ');

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'address': address.trim(),
        'details': details.trim(),
        'latitude': latitude,
        'longitude': longitude,
      };
}

class OrderRecord {
  OrderRecord({
    required this.id,
    required this.type,
    required this.status,
    required this.items,
    required this.createdAtLabelAr,
    required this.createdAtLabelEn,
    required this.paymentMethod,
    required this.baseTotal,
    required this.finalTotal,
    this.notes = '',
    this.discount = 0,
    this.deliveryAddress,
    this.deliveryId,
    this.deliveryStatus,
    this.canRateDriver = false,
    this.deliveryDistanceMeters,
    this.deliveryCost = 0,
    this.deliveryRouteGeometry = const [],
    this.deliveryDurationMinutes,
    this.deliveryRouteIsFallback = false,
    this.driver,
    this.tableNumber,
    this.isVipTable = false,
    this.seatsCount,
    this.reservationTimeLabel,
    this.reservationStatus,
    this.customerStatusKey = '',
    this.customerStatusLabelAr = '',
    this.customerStatusLabelEn = '',
    this.timelineSteps = const [],
    this.timelineIndex = 0,
    this.customerStatusCancelled = false,
    this.loyaltyAwarded = 0,
    this.canCancel = false,
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    final type = _orderType('${json['type']}');
    final rawItems = json['items'] is List ? json['items'] as List : const [];
    final delivery = json['delivery'] is Map<String, dynamic>
        ? json['delivery'] as Map<String, dynamic>
        : null;
    final reservation = json['reservation'] is Map<String, dynamic>
        ? json['reservation'] as Map<String, dynamic>
        : null;
    final driverJson = delivery?['driver'] is Map<String, dynamic>
        ? delivery!['driver'] as Map<String, dynamic>
        : null;
    final route = delivery?['route'] is Map
        ? Map<String, dynamic>.from(delivery!['route'] as Map)
        : const <String, dynamic>{};
    final payment = json['payment'] is Map<String, dynamic>
        ? json['payment'] as Map<String, dynamic>
        : null;
    final customerStatus = json['customer_status'] is Map
        ? Map<String, dynamic>.from(json['customer_status'] as Map)
        : const <String, dynamic>{};
    final rawTimeline = customerStatus['steps'] is List
        ? customerStatus['steps'] as List
        : const [];
    final fallbackStatus = _effectiveOrderStatus(
      type,
      '${json['status']}',
      delivery?['status']?.toString(),
      reservation?['status']?.toString(),
    );
    return OrderRecord(
      id: '${json['id']}',
      type: type,
      status: _unifiedOrderStatus(customerStatus, fallbackStatus),
      items: rawItems.whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        final isOffer = item['item_type'] == 'offer';
        return CartItem(
          product: Product(
            id: '${item['reference_id'] ?? item['id']}',
            nameAr: (item['name'] ?? 'عنصر').toString(),
            nameEn: (item['name'] ?? 'Item').toString(),
            descriptionAr: '',
            descriptionEn: '',
            category: isOffer ? ProductCategory.offer : ProductCategory.meal,
            price: _number(item['unit_price']),
            rating: 0,
            ratingCount: 0,
            imageUrl: ApiConfig.assetUrl(item['image_url']?.toString()),
            itemType: isOffer ? CatalogItemType.offer : CatalogItemType.product,
          ),
          quantity: _integer(item['quantity'], 1),
          canRate: !isOffer && _boolean(item['can_rate_meal']),
        );
      }).toList(),
      createdAtLabelAr: (json['created_at'] ?? '').toString(),
      createdAtLabelEn: (json['created_at'] ?? '').toString(),
      paymentMethod: _paymentMethod(payment?['method']),
      baseTotal: _number(json['total_price']),
      finalTotal: _number(json['final_price']),
      notes: (json['notes'] ?? '').toString(),
      discount: _number(json['discount']),
      deliveryAddress: delivery?['delivery_address']?.toString(),
      deliveryId: delivery == null ? null : _integer(delivery['id']),
      deliveryStatus: delivery?['status']?.toString(),
      canRateDriver: delivery != null &&
          _boolean(delivery['can_be_rated']) &&
          delivery['driver_rating'] == null &&
          driverJson != null,
      deliveryDistanceMeters: _integer(delivery?['distance_meters']),
      deliveryCost: _number(delivery?['delivery_cost']),
      deliveryRouteGeometry: _routeGeometry(route['geometry']),
      deliveryDurationMinutes: route['duration_minutes'] == null
          ? null
          : _integer(route['duration_minutes']),
      deliveryRouteIsFallback: _boolean(route['is_fallback']),
      driver: driverJson == null
          ? null
          : DriverProfile(
              id: '${driverJson['id']}',
              nameAr: (driverJson['name'] ?? 'السائق').toString(),
              nameEn: (driverJson['name'] ?? 'Driver').toString(),
              descriptionAr: (driverJson['phone'] ?? '').toString(),
              descriptionEn: (driverJson['phone'] ?? '').toString(),
              rating: _number(driverJson['rating']),
              priceHintAr: '',
              priceHintEn: '',
            ),
      tableNumber:
          reservation == null ? null : _integer(reservation['table_number']),
      isVipTable: reservation?['table_type'] == 'vip',
      seatsCount:
          reservation == null ? null : _integer(reservation['seats_count']),
      reservationTimeLabel:
          reservation?['reservation_time_formatted']?.toString() ??
              reservation?['reservation_time']?.toString(),
      reservationStatus: reservation?['status']?.toString(),
      customerStatusKey: (customerStatus['key'] ?? '').toString(),
      customerStatusLabelAr: (customerStatus['label_ar'] ?? '').toString(),
      customerStatusLabelEn: (customerStatus['label_en'] ?? '').toString(),
      timelineSteps: rawTimeline
          .whereType<Map>()
          .map((step) =>
              OrderTimelineStep.fromJson(Map<String, dynamic>.from(step)))
          .toList(growable: false),
      timelineIndex: _integer(customerStatus['current_index']),
      customerStatusCancelled: _boolean(customerStatus['is_cancelled']),
      canCancel: _orderStatus('${json['status']}') == OrderStatus.pending,
    );
  }

  final String id;
  final OrderType type;
  OrderStatus status;
  final List<CartItem> items;
  final String createdAtLabelAr;
  final String createdAtLabelEn;
  final PaymentMethod paymentMethod;
  final double baseTotal;
  final double finalTotal;
  final String notes;
  final double discount;
  final String? deliveryAddress;
  final int? deliveryId;
  final String? deliveryStatus;
  final bool canRateDriver;
  final int? deliveryDistanceMeters;
  final double deliveryCost;
  final List<List<double>> deliveryRouteGeometry;
  final int? deliveryDurationMinutes;
  final bool deliveryRouteIsFallback;
  final DriverProfile? driver;
  final int? tableNumber;
  final bool isVipTable;
  final int? seatsCount;
  final String? reservationTimeLabel;
  final String? reservationStatus;
  final String customerStatusKey;
  final String customerStatusLabelAr;
  final String customerStatusLabelEn;
  final List<OrderTimelineStep> timelineSteps;
  final int timelineIndex;
  final bool customerStatusCancelled;
  final int loyaltyAwarded;
  final bool canCancel;
  bool get canDelete => false;
}

class OrderTimelineStep {
  const OrderTimelineStep({
    required this.key,
    required this.labelAr,
    required this.labelEn,
  });

  factory OrderTimelineStep.fromJson(Map<String, dynamic> json) =>
      OrderTimelineStep(
        key: (json['key'] ?? '').toString(),
        labelAr: (json['label_ar'] ?? json['label_en'] ?? '').toString(),
        labelEn: (json['label_en'] ?? json['label_ar'] ?? '').toString(),
      );

  final String key;
  final String labelAr;
  final String labelEn;
}

class ReservationTable {
  const ReservationTable({
    required this.number,
    required this.name,
    required this.type,
    required this.maxSeats,
    required this.durationMinutes,
    this.isAvailable,
  });

  factory ReservationTable.fromJson(Map<String, dynamic> json) =>
      ReservationTable(
        number: _integer(json['number']),
        name: (json['name'] ?? 'T${json['number']}').toString(),
        type: (json['type'] ?? 'normal').toString(),
        maxSeats: _integer(json['max_seats'], 10),
        durationMinutes: _integer(json['duration_minutes'], 60),
        isAvailable: json['is_available'] == null
            ? null
            : _boolean(json['is_available']),
      );

  final int number;
  final String name;
  final String type;
  final int maxSeats;
  final int durationMinutes;
  final bool? isAvailable;

  bool get isVip => type == 'vip';
}

List<List<double>> _routeGeometry(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<List>()
      .map((point) {
        if (point.length < 2 || point[0] is! num || point[1] is! num) {
          return const <double>[];
        }
        return <double>[
          (point[0] as num).toDouble(),
          (point[1] as num).toDouble()
        ];
      })
      .where((point) => point.length == 2)
      .toList(growable: false);
}

OrderType _orderType(String raw) => switch (raw) {
      'delivery' => OrderType.delivery,
      'reservation' => OrderType.reservation,
      _ => OrderType.ordinary,
    };

OrderStatus _orderStatus(String raw) => switch (raw) {
      'confirmed' => OrderStatus.confirmed,
      'ready' || 'in_progress' || 'preparing' => OrderStatus.inProgress,
      'completed' || 'delivered' => OrderStatus.completed,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.pending,
    };

OrderStatus _effectiveOrderStatus(
  OrderType type,
  String orderStatus,
  String? deliveryStatus,
  String? reservationStatus,
) {
  final subtype = switch (type) {
    OrderType.delivery => deliveryStatus,
    OrderType.reservation => reservationStatus,
    OrderType.ordinary => null,
  };
  if (subtype == 'cancelled' || subtype == 'no_show') {
    return OrderStatus.cancelled;
  }
  if ((type == OrderType.delivery && subtype == 'delivered') ||
      (type == OrderType.reservation && subtype == 'completed')) {
    return OrderStatus.completed;
  }
  if (type == OrderType.delivery &&
      const ['pending', 'assigned', 'picked_up', 'in_delivery']
          .contains(subtype)) {
    return subtype == 'pending'
        ? OrderStatus.confirmed
        : OrderStatus.inProgress;
  }
  if (type == OrderType.reservation &&
      const ['pending', 'confirmed', 'seated'].contains(subtype)) {
    return subtype == 'pending' ? OrderStatus.pending : OrderStatus.inProgress;
  }
  return _orderStatus(orderStatus);
}

OrderStatus _unifiedOrderStatus(
  Map<String, dynamic> customerStatus,
  OrderStatus fallback,
) {
  final key = customerStatus['key']?.toString();
  if (key == null || key.isEmpty) return fallback;
  if (_boolean(customerStatus['is_cancelled']) || key == 'no_show') {
    return OrderStatus.cancelled;
  }
  if (const ['completed', 'delivered', 'reservation_completed'].contains(key)) {
    return OrderStatus.completed;
  }
  if (key == 'pending') return OrderStatus.pending;
  if (key == 'confirmed') return OrderStatus.confirmed;
  return OrderStatus.inProgress;
}

PaymentMethod _paymentMethod(dynamic raw) => switch ('$raw') {
      'syriatel_cash' => PaymentMethod.syriatelCash,
      'sham_cash' => PaymentMethod.shamCash,
      'loyalty_points' => PaymentMethod.loyaltyPoints,
      _ => PaymentMethod.cash,
    };

class RestaurantProfile {
  const RestaurantProfile({
    this.name = 'TAZA 041',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.address = '',
    this.about = '',
    this.logoUrl = '',
    this.isOpen = true,
    this.latitude,
    this.longitude,
    this.todayHours = const {},
    this.websiteContent = const {},
  });

  factory RestaurantProfile.fromJson(Map<String, dynamic> json) =>
      RestaurantProfile(
        name: (json['name'] ?? 'TAZA 041').toString(),
        phone: (json['phone'] ?? '').toString(),
        whatsapp: (json['whatsapp'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        address: (json['address'] ?? '').toString(),
        about: (json['about_text'] ?? '').toString(),
        logoUrl: ApiConfig.assetUrl(json['logo_url']?.toString()),
        isOpen: _boolean(json['is_open_now'] ?? json['is_open'], true),
        latitude: json['latitude'] == null ? null : _number(json['latitude']),
        longitude:
            json['longitude'] == null ? null : _number(json['longitude']),
        todayHours: json['today_hours'] is Map
            ? Map<String, dynamic>.from(json['today_hours'] as Map)
            : const {},
        websiteContent: json['website_content'] is Map
            ? Map<String, dynamic>.from(json['website_content'] as Map)
            : const {},
      );

  final String name;
  final String phone;
  final String whatsapp;
  final String email;
  final String address;
  final String about;
  final String logoUrl;
  final bool isOpen;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> todayHours;
  final Map<String, dynamic> websiteContent;

  String todayHoursLabel({required String closedLabel}) {
    if (todayHours.isEmpty) return '';
    if (_boolean(todayHours['is_closed'])) return closedLabel;
    final open = todayHours['open']?.toString().trim() ?? '';
    final close = todayHours['close']?.toString().trim() ?? '';
    if (open.isEmpty || close.isEmpty) return '';
    return '$open – $close';
  }

  String content(String key, String fallback) {
    final value = websiteContent[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}

class MenuRouteArgs {
  const MenuRouteArgs({required this.orderType, this.highlightProductId});

  final OrderType orderType;
  final String? highlightProductId;
}
