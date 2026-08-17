import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taza041_flutter_customer_mobile/src/core/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('preferences are owned and restored through AppStorage', () async {
    final storage = AppStorage();
    await storage.initialize();

    await storage.writeLanguage('en');
    await storage.writeTheme(false);
    await storage.writeCartSnapshot('[{"id":1}]');
    await storage.writePublicSnapshot('{"revision":"1"}');
    await storage.savePendingOrder(id: '42', fingerprint: 'checkout-v1');
    await storage.writeCustomerStateOwner(19);

    expect(storage.languageCode, 'en');
    expect(storage.isDarkMode, isFalse);
    expect(storage.cartSnapshot, '[{"id":1}]');
    expect(storage.publicSnapshot, '{"revision":"1"}');
    expect(storage.pendingOrderId, '42');
    expect(storage.pendingOrderFingerprint, 'checkout-v1');
    expect(storage.customerStateOwner, 19);
  });

  test('pending checkout metadata is cleared atomically', () async {
    final storage = AppStorage();
    await storage.initialize();
    await storage.savePendingOrder(id: '7', fingerprint: 'fingerprint');

    await storage.clearPendingOrder();

    expect(storage.pendingOrderId, isNull);
    expect(storage.pendingOrderFingerprint, isNull);
  });

  test('customer state ownership can be cleared when the session ends',
      () async {
    final storage = AppStorage();
    await storage.initialize();
    await storage.writeCustomerStateOwner(8);

    await storage.clearCustomerStateOwner();

    expect(storage.customerStateOwner, isNull);
  });
}
