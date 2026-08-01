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
  bool isRead;
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
    this.latitude,
    this.longitude,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        type: SavedAddressType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => SavedAddressType.other,
        ),
        address: (json['address'] ?? '').toString(),
        latitude: json['latitude'] == null ? null : _number(json['latitude']),
        longitude:
            json['longitude'] == null ? null : _number(json['longitude']),
      );

  final SavedAddressType type;
  final String address;
  final double? latitude;
  final double? longitude;

  bool get hasAddress => address.trim().isNotEmpty;
  bool get isPinned => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'address': address.trim(),
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
    this.discount = 0,
    this.deliveryAddress,
    this.deliveryId,
    this.canRateDriver = false,
    this.deliveryDistanceMeters,
    this.deliveryCost = 0,
    this.driver,
    this.tableNumber,
    this.isVipTable = false,
    this.seatsCount,
    this.reservationTimeLabel,
    this.loyaltyAwarded = 0,
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
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
    final payment = json['payment'] is Map<String, dynamic>
        ? json['payment'] as Map<String, dynamic>
        : null;
    return OrderRecord(
      id: '${json['id']}',
      type: _orderType('${json['type']}'),
      status: _orderStatus('${json['status']}'),
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
      discount: _number(json['discount']),
      deliveryAddress: delivery?['delivery_address']?.toString(),
      deliveryId: delivery == null ? null : _integer(delivery['id']),
      canRateDriver: delivery != null &&
          _boolean(delivery['can_be_rated']) &&
          delivery['driver_rating'] == null &&
          driverJson != null,
      deliveryDistanceMeters: _integer(delivery?['distance_meters']),
      deliveryCost: _number(delivery?['delivery_cost']),
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
  final double discount;
  final String? deliveryAddress;
  final int? deliveryId;
  final bool canRateDriver;
  final int? deliveryDistanceMeters;
  final double deliveryCost;
  final DriverProfile? driver;
  final int? tableNumber;
  final bool isVipTable;
  final int? seatsCount;
  final String? reservationTimeLabel;
  final int loyaltyAwarded;

  bool get canCancel => status == OrderStatus.pending;
  bool get canDelete => false;
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
  final Map<String, dynamic> websiteContent;

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
