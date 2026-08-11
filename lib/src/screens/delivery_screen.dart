import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../core/app_constants.dart';
import '../app_state.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _mapController = MapController();
  final _address = TextEditingController();
  LatLng? _selected;
  List<LatLng> _routePoints = const [];
  bool _routeIsFallback = false;
  int? _routeDurationMinutes;
  bool _quoting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    _address.text = state.selectedDeliveryAddressAr ?? _address.text;
    if (_selected == null &&
        state.selectedDeliveryLatitude != null &&
        state.selectedDeliveryLongitude != null) {
      _selected = LatLng(
        state.selectedDeliveryLatitude!,
        state.selectedDeliveryLongitude!,
      );
    }
    if (_routePoints.isEmpty &&
        state.selectedDeliveryRouteGeometry.isNotEmpty) {
      _routePoints = _routePointsFrom(state.selectedDeliveryRouteGeometry);
      _routeIsFallback = state.selectedDeliveryRouteIsFallback;
      _routeDurationMinutes = state.selectedDeliveryDurationMinutes;
    }
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  LatLng _restaurantPoint(AppState state) => LatLng(
        state.restaurant.latitude ?? 35.5317,
        state.restaurant.longitude ?? 35.7901,
      );

  Future<void> _useMyLocation() async {
    final state = AppStateScope.of(context);
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
      state.clearConfirmedDeliveryLocation();
      setState(() {
        _selected = point;
        _routePoints = const [];
        _routeDurationMinutes = null;
        _routeIsFallback = false;
      });
      _mapController.move(point, 16);
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _confirm() async {
    final point = _selected;
    if (point == null || _address.text.trim().isEmpty) {
      showMessage(
          context,
          tr(context,
              ar: 'حدد نقطة على الخريطة وأدخل وصف العنوان',
              en: 'Select a map point and enter the address'));
      return;
    }
    setState(() => _quoting = true);
    final state = AppStateScope.of(context);
    try {
      final quote = await state.quoteDelivery(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      final route = quote['route'] is Map
          ? Map<String, dynamic>.from(quote['route'] as Map)
          : <String, dynamic>{};
      final routeGeometry = _routeGeometryFrom(route['geometry']);
      state.confirmDeliveryLocation(
        addressAr: _address.text.trim(),
        addressEn: _address.text.trim(),
        distanceMeters: (quote['distance_meters'] as num?)?.toInt() ?? 0,
        latitude: point.latitude,
        longitude: point.longitude,
        quotedCost: (quote['delivery_cost'] as num?)?.toDouble() ?? 0,
        routeGeometry: routeGeometry,
        durationMinutes: (route['duration_minutes'] as num?)?.toInt(),
        routeIsFallback: route['is_fallback'] == true,
      );
      setState(() {
        _routePoints = _routePointsFrom(routeGeometry);
        _routeDurationMinutes = (route['duration_minutes'] as num?)?.toInt();
        _routeIsFallback = route['is_fallback'] == true;
      });
      if (mounted) {
        showMessage(
            context,
            _routeIsFallback
                ? tr(context,
                    ar:
                        'تعذّر الوصول إلى خدمة الطرق؛ استُخدم تقدير احتياطي واضح.',
                    en:
                        'Road routing is unavailable; a clearly marked fallback estimate was used.')
                : tr(context,
                    ar: 'تم حفظ الموقع ورسم الطريق وحساب أجور التوصيل',
                    en: 'Location, road route, and delivery fee confirmed'));
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _applySavedAddress(SavedAddress address) async {
    _address.text = address.displayAddress;
    if (!address.isPinned) {
      showMessage(
        context,
        tr(context,
            ar: 'تم إدخال وصف العنوان. حدّد موقعه على الخريطة لإكمال الطلب.',
            en: 'Address filled in. Pin it on the map to continue.'),
      );
      return;
    }
    final point = LatLng(address.latitude!, address.longitude!);
    setState(() {
      _selected = point;
      _quoting = true;
    });
    _mapController.move(point, 16);
    final state = AppStateScope.of(context);
    try {
      final quote = await state.quoteDelivery(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      final route = quote['route'] is Map
          ? Map<String, dynamic>.from(quote['route'] as Map)
          : <String, dynamic>{};
      final routeGeometry = _routeGeometryFrom(route['geometry']);
      state.confirmDeliveryLocation(
        addressAr: address.address,
        addressEn: address.address,
        distanceMeters: (quote['distance_meters'] as num?)?.toInt() ?? 0,
        latitude: point.latitude,
        longitude: point.longitude,
        quotedCost: (quote['delivery_cost'] as num?)?.toDouble() ?? 0,
        routeGeometry: routeGeometry,
        durationMinutes: (route['duration_minutes'] as num?)?.toInt(),
        routeIsFallback: route['is_fallback'] == true,
      );
      setState(() {
        _routePoints = _routePointsFrom(routeGeometry);
        _routeDurationMinutes = (route['duration_minutes'] as num?)?.toInt();
        _routeIsFallback = route['is_fallback'] == true;
      });
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final center = _restaurantPoint(state);
    return TazaShell(
      titleAr: 'طلب توصيل',
      titleEn: 'Delivery order',
      registered: state.isAuthenticated,
      showBack: true,
      bottomContent: _DeliveryBottomBar(state: state),
      body: ListView(
        children: [
          const SectionHeader(
            titleAr: 'حدد موقعك واحصل على التكلفة',
            titleEn: 'Set your location and see the fee',
            subtitleAr:
                'اختر النقطة بدقة، أضف وصفًا يساعد السائق، ثم احسب المسافة والأجور.',
            subtitleEn:
                'Pin your address, add a useful note, then calculate distance and fee.',
          ),
          const SizedBox(height: 14),
          if (state.savedAddresses.any((address) => address.hasAddress)) ...[
            _SavedAddressPicker(
              addresses: state.savedAddresses
                  .where((address) => address.hasAddress)
                  .toList(growable: false),
              onSelected: _applySavedAddress,
            ),
            const SizedBox(height: 14),
          ],
          TazaCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x226FB7FF),
                  child: Icon(Icons.delivery_dining_rounded,
                      color: TazaColors.info),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context,
                            ar: 'يُسند السائق بعد تأكيد الطلب',
                            en: 'Driver is assigned after confirmation'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(tr(context,
                          ar: 'ستصلك بياناته وتحديثات الطريق عبر الإشعارات.',
                          en: 'Driver details and progress arrive through notifications.')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height:
                (MediaQuery.sizeOf(context).height * .37).clamp(270.0, 360.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selected ?? center,
                  initialZoom: 13,
                  onTap: (_, point) {
                    state.clearConfirmedDeliveryLocation();
                    setState(() {
                      _selected = point;
                      _routePoints = const [];
                      _routeDurationMinutes = null;
                      _routeIsFallback = false;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: ApiConfig.mapTileUrl,
                    userAgentPackageName: AppConstants.mapUserAgent,
                  ),
                  if (_routePoints.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 6,
                          color: _routeIsFallback
                              ? TazaColors.accent
                              : TazaColors.info,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: [
                    Marker(
                      point: center,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.restaurant_rounded,
                          size: 38, color: TazaColors.danger),
                    ),
                    if (_selected != null)
                      Marker(
                        point: _selected!,
                        width: 48,
                        height: 48,
                        child: const Icon(Icons.location_pin,
                            size: 44, color: TazaColors.info),
                      ),
                  ]),
                  const RichAttributionWidget(attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _useMyLocation,
              icon: const Icon(Icons.my_location_rounded),
              label: Text(tr(context,
                  ar: 'استخدم موقعي الحالي', en: 'Use my current location')),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            minLines: 1,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.home_work_outlined),
              hintText: tr(context,
                  ar: 'وصف العنوان: الشارع، البناء، نقطة دالة',
                  en: 'Address: street, building, landmark'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _quoting ? null : _confirm,
              icon: _quoting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: Text(tr(context,
                  ar: 'تأكيد الموقع وحساب التكلفة',
                  en: 'Confirm location and calculate fee')),
            ),
          ),
          const SizedBox(height: 18),
          _DeliverySummary(state: state),
          if (_routeDurationMinutes != null) ...[
            const SizedBox(height: 10),
            TazaCard(
              child: Row(
                children: [
                  Icon(
                    _routeIsFallback
                        ? Icons.warning_amber_rounded
                        : Icons.route_rounded,
                    color: _routeIsFallback
                        ? TazaColors.accent
                        : TazaColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _routeIsFallback
                          ? tr(context,
                              ar: 'المسار تقدير احتياطي مؤقت',
                              en: 'Temporary fallback route estimate')
                          : tr(context,
                              ar: 'مسار طرق فعلي معتمد',
                              en: 'Confirmed road route'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                      '${_routeDurationMinutes!} ${tr(context, ar: 'د', en: 'min')}'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

List<List<double>> _routeGeometryFrom(dynamic raw) {
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

List<LatLng> _routePointsFrom(List<List<double>> geometry) => geometry
    .where((point) => point.length >= 2)
    .map((point) => LatLng(point[1], point[0]))
    .toList(growable: false);

class _SavedAddressPicker extends StatelessWidget {
  const _SavedAddressPicker({
    required this.addresses,
    required this.onSelected,
  });

  final List<SavedAddress> addresses;
  final ValueChanged<SavedAddress> onSelected;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              tr(context,
                  ar: 'اختر من عناوينك المحفوظة', en: 'Choose a saved address'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: addresses
                .map((address) => ActionChip(
                      avatar: Icon(
                        address.type == SavedAddressType.home
                            ? Icons.home_rounded
                            : address.type == SavedAddressType.work
                                ? Icons.work_rounded
                                : Icons.place_rounded,
                        size: 18,
                      ),
                      label: Text(address.type == SavedAddressType.home
                          ? tr(context, ar: 'البيت', en: 'Home')
                          : address.type == SavedAddressType.work
                              ? tr(context, ar: 'العمل', en: 'Work')
                              : tr(context, ar: 'عنوان آخر', en: 'Other')),
                      onPressed: () => onSelected(address),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DeliverySummary extends StatelessWidget {
  const _DeliverySummary({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      child: Column(
        children: [
          _line(
              context,
              tr(context, ar: 'المسافة', en: 'Distance'),
              state.selectedDeliveryDistanceMeters == null
                  ? '—'
                  : '${(state.selectedDeliveryDistanceMeters! / 1000).toStringAsFixed(2)} km'),
          _line(context, tr(context, ar: 'أجور التوصيل', en: 'Delivery fee'),
              formatCurrency(state.deliveryCost)),
          const Divider(),
          _line(context, tr(context, ar: 'الإجمالي', en: 'Total'),
              formatCurrency(state.orderGrandTotal),
              bold: true),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                  color: bold ? TazaColors.accent : null)),
        ],
      ),
    );
  }
}

class _DeliveryBottomBar extends StatelessWidget {
  const _DeliveryBottomBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, ar: 'الإجمالي', en: 'Total')),
                    Text(formatCurrency(state.orderGrandTotal),
                        style: const TextStyle(
                            color: TazaColors.accent,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: state.selectedDeliveryLatitude == null
                    ? null
                    : () => Navigator.pushNamed(context, AppRoutes.payment),
                child: Text(tr(context, ar: 'إلى الدفع', en: 'Payment')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
