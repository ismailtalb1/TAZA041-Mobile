import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taza041_flutter_customer_mobile/src/api_client.dart';
import 'package:taza041_flutter_customer_mobile/src/app_state.dart';
import 'package:taza041_flutter_customer_mobile/src/core/reservation_time.dart';

void main() {
  final noon = DateTime(2026, 8, 21, 12);

  test('a past morning clock remains today instead of rolling to tomorrow', () {
    final selected = reservationDateTimeForToday(
      hour12: 10,
      minute: 0,
      isPm: false,
      now: noon,
    );

    expect(selected, DateTime(2026, 8, 21, 10));
    expect(isReservationTimeBookable(selected, now: noon), isFalse);
  });

  test('a later clock today is bookable', () {
    final selected = reservationDateTimeForToday(
      hour12: 2,
      minute: 30,
      isPm: true,
      now: noon,
    );

    expect(selected, DateTime(2026, 8, 21, 14, 30));
    expect(isReservationTimeBookable(selected, now: noon), isTrue);
  });

  test('the default clock is rounded up after now', () {
    expect(
      defaultReservationTime(now: DateTime(2026, 8, 21, 12, 3)),
      DateTime(2026, 8, 21, 12, 10),
    );
  });

  test('final confirmation checks the selected table availability endpoint',
      () async {
    late Uri requestedUri;
    final state = AppState(
      apiClient: ApiClient(
        baseUrl: 'https://api.example.test/api',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'is_available': true},
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(state.dispose);

    final available = await state.tableIsAvailable(
      tableNumber: 5,
      reservationTime: DateTime(2026, 8, 21, 14, 30),
    );

    expect(available, isTrue);
    expect(requestedUri.path, '/api/public/reservations/table/5/availability');
    expect(requestedUri.queryParameters['duration_minutes'], '60');
    expect(requestedUri.queryParameters['live'], '1');
  });
}
