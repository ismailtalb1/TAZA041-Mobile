import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/models.dart';

void main() {
  test('reservation tables use the shared server catalogue fields', () {
    final table = ReservationTable.fromJson({
      'number': 5,
      'name': 'T5',
      'type': 'vip',
      'max_seats': 10,
      'duration_minutes': 60,
      'is_available': false,
    });

    expect(table.number, 5);
    expect(table.isVip, isTrue);
    expect(table.maxSeats, 10);
    expect(table.durationMinutes, 60);
    expect(table.isAvailable, isFalse);
  });

  test('delivery order parses every unified customer status step', () {
    final order = OrderRecord.fromJson({
      'id': 41,
      'type': 'delivery',
      'status': 'completed',
      'items': [],
      'total_price': 100,
      'final_price': 120,
      'delivery': {'status': 'picked_up'},
      'customer_status': {
        'key': 'picked_up',
        'label_ar': 'استلم السائق الطلب',
        'label_en': 'Picked up by driver',
        'current_index': 6,
        'is_cancelled': false,
        'steps': [
          {'key': 'pending', 'label_ar': 'معلق', 'label_en': 'Pending'},
          {'key': 'confirmed', 'label_ar': 'مؤكد', 'label_en': 'Confirmed'},
          {'key': 'ready', 'label_ar': 'تجهيز', 'label_en': 'Preparing'},
          {'key': 'completed', 'label_ar': 'جاهز', 'label_en': 'Ready'},
          {
            'key': 'awaiting_driver',
            'label_ar': 'انتظار',
            'label_en': 'Awaiting driver'
          },
          {'key': 'assigned', 'label_ar': 'السائق', 'label_en': 'Assigned'},
          {'key': 'picked_up', 'label_ar': 'استلام', 'label_en': 'Picked up'},
          {
            'key': 'in_delivery',
            'label_ar': 'الطريق',
            'label_en': 'On the way'
          },
          {'key': 'delivered', 'label_ar': 'تسليم', 'label_en': 'Delivered'},
        ],
      },
    });

    expect(order.customerStatusKey, 'picked_up');
    expect(order.customerStatusLabelEn, 'Picked up by driver');
    expect(order.timelineSteps, hasLength(9));
    expect(order.timelineIndex, 6);
    expect(order.status, OrderStatus.inProgress);
  });

  test('completed reservation exposes the table-ready terminal state', () {
    final order = OrderRecord.fromJson({
      'id': 42,
      'type': 'reservation',
      'status': 'completed',
      'items': [],
      'total_price': 100,
      'final_price': 100,
      'reservation': {'status': 'completed', 'table_number': 5},
      'customer_status': {
        'key': 'reservation_completed',
        'label_ar': 'الطاولة جاهزة',
        'label_en': 'Table ready',
        'current_index': 5,
        'is_cancelled': false,
        'steps': [],
      },
    });

    expect(order.customerStatusKey, 'reservation_completed');
    expect(order.status, OrderStatus.completed);
  });

  test('restaurant profile uses the live address and today hours', () {
    final restaurant = RestaurantProfile.fromJson({
      'address': 'Latakia',
      'today_hours': {
        'open': '10:00',
        'close': '23:30',
        'is_closed': false,
      },
    });

    expect(restaurant.address, 'Latakia');
    expect(
      restaurant.todayHoursLabel(closedLabel: 'Closed today'),
      '10:00 – 23:30',
    );
  });
}
