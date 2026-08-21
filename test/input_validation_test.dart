import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/core/input_validation.dart';

void main() {
  group('CustomerInputValidation', () {
    test('accepts names and rejects numeric names', () {
      expect(CustomerInputValidation.isFullName('محمد الأحمد'), isTrue);
      expect(CustomerInputValidation.isFullName('John Smith'), isTrue);
      expect(CustomerInputValidation.isFullName('123456'), isFalse);
      expect(CustomerInputValidation.isFullName('محمد123'), isFalse);
    });

    test('requires a 10-digit phone beginning with 09', () {
      expect(CustomerInputValidation.isPhone('0912345678'), isTrue);
      expect(CustomerInputValidation.formatPhone('0912345678'),
          '09 12 345 678');
      expect(CustomerInputValidation.isPhone('09 12 345 678'), isTrue);
      expect(CustomerInputValidation.isPhone('912345678'), isFalse);
      expect(CustomerInputValidation.isPhone('+963912345678'), isFalse);
      expect(CustomerInputValidation.isPhone('09123456789'), isFalse);
      expect(CustomerInputValidation.isPhone('09 1234 5678'), isFalse);
    });

    test('validates email, passwords and safe text', () {
      expect(CustomerInputValidation.isEmail('user@example.com'), isTrue);
      expect(CustomerInputValidation.isEmail('user@invalid'), isFalse);
      expect(CustomerInputValidation.isStrongPassword('Secure123'), isTrue);
      expect(CustomerInputValidation.isStrongPassword('12345678'), isFalse);
      expect(CustomerInputValidation.isSafeText('عنوان صحيح', required: true),
          isTrue);
      expect(CustomerInputValidation.isSafeText('\u0007', required: true),
          isFalse);
    });
  });
}
