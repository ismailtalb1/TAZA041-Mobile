import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taza041_flutter_customer_mobile/src/api_client.dart';

void main() {
  test('401 expires a session while 403 keeps the authenticated session', () {
    expect(const ApiException('unauthorized', statusCode: 401).isUnauthorized,
        isTrue);
    expect(const ApiException('forbidden', statusCode: 403).isUnauthorized,
        isFalse);
    expect(
        const ApiException('forbidden', statusCode: 403).isForbidden, isTrue);
  });

  test('GET retries one transient server failure and then succeeds', () async {
    var calls = 0;
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api',
      httpClient: MockClient((_) async {
        calls += 1;
        if (calls == 1) {
          return http.Response(
            jsonEncode({'success': false, 'message': 'temporary'}),
            503,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'ready': true},
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await client.get('/health') as Map<String, dynamic>;

    expect(result['ready'], isTrue);
    expect(calls, 2);
  });

  test('POST is never retried to avoid duplicate mutations', () async {
    var calls = 0;
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api',
      httpClient: MockClient((_) async {
        calls += 1;
        return http.Response(
          jsonEncode({'success': false, 'message': 'temporary'}),
          503,
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.post('/orders', body: {'item': 1}),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });

  test('null query values are omitted from the request', () async {
    late Uri requestUri;
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api',
      httpClient: MockClient((request) async {
        requestUri = request.url;
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      }),
    );
    addTearDown(client.dispose);

    await client.get('/catalog', query: {'page': 2, 'cursor': null});

    expect(requestUri.queryParameters, {'page': '2'});
  });

  test('DELETE sends the password confirmation body', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'addresses': []}
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);

    await client.delete('/customer/saved-addresses/home', body: {
      'current_password': 'secret',
    });

    expect(captured.method, 'DELETE');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {'current_password': 'secret'});
  });

  test('multipart upload sends idea text and optional image together',
      () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'suggestion': {'id': 41}
            },
          }),
          201,
        );
      }),
    );
    addTearDown(client.dispose);

    await client.uploadMultipart(
      '/customer/meal-suggestion',
      fields: {'suggestion_text': 'New seasonal meal idea'},
      bytes: const [0x89, 0x50, 0x4E, 0x47],
      filename: 'idea.png',
    );

    final body = utf8.decode(captured.bodyBytes, allowMalformed: true);
    expect(captured.method, 'POST');
    expect(captured.headers['content-type'], contains('multipart/form-data'));
    expect(body, contains('suggestion_text'));
    expect(body, contains('New seasonal meal idea'));
    expect(body, contains('filename="idea.png"'));
  });
}
