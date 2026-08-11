import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/app_state.dart';
import 'package:taza041_flutter_customer_mobile/src/models.dart';

void main() {
  test('delivery route is parsed from the shared Laravel order payload', () {
    final order = OrderRecord.fromJson({
      'id': 41,
      'type': 'delivery',
      'status': 'pending',
      'items': const [],
      'delivery': {
        'id': 7,
        'status': 'pending',
        'distance_meters': 2829,
        'delivery_cost': 141.45,
        'route': {
          'provider': 'osrm',
          'is_fallback': false,
          'duration_minutes': 5,
          'geometry': [
            [35.7901, 35.5317],
            [35.8000, 35.5400],
          ],
        },
      },
    });

    expect(order.deliveryRouteGeometry, hasLength(2));
    expect(order.deliveryRouteGeometry.first, [35.7901, 35.5317]);
    expect(order.deliveryDurationMinutes, 5);
    expect(order.deliveryRouteIsFallback, isFalse);
    expect(order.deliveryStatus, 'pending');
    expect(order.status, OrderStatus.confirmed);
    expect(order.canCancel, isTrue);
  });

  test(
      'delivery status overrides the completed kitchen state for live tracking',
      () {
    final onTheWay = OrderRecord.fromJson({
      'id': 42,
      'type': 'delivery',
      'status': 'completed',
      'items': const [],
      'delivery': {'id': 8, 'status': 'in_delivery'},
    });
    final delivered = OrderRecord.fromJson({
      'id': 42,
      'type': 'delivery',
      'status': 'completed',
      'items': const [],
      'delivery': {'id': 8, 'status': 'delivered'},
    });

    expect(onTheWay.status, OrderStatus.inProgress);
    expect(delivered.status, OrderStatus.completed);
  });

  test('selecting another point invalidates the previous confirmed quote', () {
    final state = AppState();
    addTearDown(state.dispose);
    state.confirmDeliveryLocation(
      addressAr: 'شارع الزراعة',
      addressEn: 'Agriculture Street',
      distanceMeters: 2829,
      latitude: 35.54,
      longitude: 35.8,
      quotedCost: 141.45,
      durationMinutes: 5,
      routeGeometry: const [
        [35.7901, 35.5317],
        [35.8, 35.54],
      ],
    );

    state.clearConfirmedDeliveryLocation();

    expect(state.selectedDeliveryLatitude, isNull);
    expect(state.selectedDeliveryDistanceMeters, isNull);
    expect(state.selectedDeliveryRouteGeometry, isEmpty);
    expect(state.selectedDeliveryDurationMinutes, isNull);
    expect(state.deliveryCost, 0);
  });
}
