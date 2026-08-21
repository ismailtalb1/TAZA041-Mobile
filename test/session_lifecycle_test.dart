import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taza041_flutter_customer_mobile/src/api_client.dart';
import 'package:taza041_flutter_customer_mobile/src/app_state.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('an old unauthorized response cannot clear a newer login token',
      () async {
    final requestStarted = Completer<void>();
    final finishOldRequest = Completer<void>();
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api',
      httpClient: MockClient((request) async {
        requestStarted.complete();
        await finishOldRequest.future;
        return http.Response(
          jsonEncode({'success': false, 'message': 'Unauthenticated'}),
          401,
        );
      }),
    );
    final state = AppState(apiClient: api)..isAuthenticated = true;
    addTearDown(state.dispose);
    await api.saveToken('old-token');

    final pendingRefresh = state.refreshOrdersLive();
    await requestStarted.future;
    await api.saveToken('new-token');
    finishOldRequest.complete();
    await pendingRefresh;

    expect(api.token, 'new-token');
    expect(state.isAuthenticated, isTrue);
  });

  test('changing the password keeps the verified mobile session', () async {
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api',
      httpClient: MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'customer': {
                  'id': 7,
                  'name': 'Mobile Customer',
                  'email': 'mobile@example.test',
                  'loyalty_points': 0,
                },
                'loyalty': {'points_balance': 0},
              },
            }),
            200,
          )),
    );
    final state = AppState(apiClient: api)..isAuthenticated = true;
    addTearDown(state.dispose);
    await api.saveToken('current-mobile-token');

    await state.updateProfile(
      fullName: 'Mobile Customer',
      email: 'mobile@example.test',
      phone: '0912345678',
      currentPassword: 'OldPassword123',
      newPassword: 'NewPassword456',
      newPasswordConfirmation: 'NewPassword456',
    );

    expect(api.token, 'current-mobile-token');
    expect(state.isAuthenticated, isTrue);
  });
}
