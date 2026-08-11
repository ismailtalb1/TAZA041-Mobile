import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/api_client.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android emulator uses the host loopback alias by default', () {
    expect(ApiConfig.baseUrl, 'http://10.0.2.2:8000/api');
  });

  test('relative asset paths use the configured API origin', () {
    expect(
      ApiConfig.assetUrl('storage/products/example.jpg'),
      'http://10.0.2.2:8000/storage/products/example.jpg',
    );
  });

  test('absolute asset URLs remain unchanged', () {
    const absolute = 'https://cdn.example.com/products/example.jpg';
    expect(ApiConfig.assetUrl(absolute), absolute);
  });

  test('production endpoints must be remote HTTPS URLs', () {
    expect(
        ApiConfig.isValidProductionBase('https://api.taza041.com/api'), isTrue);
    expect(
        ApiConfig.isValidProductionBase('http://api.taza041.com/api'), isFalse);
    expect(
        ApiConfig.isValidProductionBase('https://localhost:8000/api'), isFalse);
  });
}
