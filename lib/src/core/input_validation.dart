import 'package:flutter/services.dart';

final class CustomerInputValidation {
  static final RegExp _namePattern = RegExp(
    r"^[\p{L}\p{M}]+(?:[ '’.-][\p{L}\p{M}]+)*$",
    unicode: true,
  );
  static final RegExp _emailPattern = RegExp(
    r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$",
    caseSensitive: false,
  );
  static final RegExp _controlCharacters =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static String normalizeName(String? value) =>
      (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizePhone(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');

  static String formatPhone(String? value) {
    final digits = normalizePhone(value);
    if (digits.isEmpty) return '';
    final subscriber = (digits.startsWith('09') ? digits.substring(2) : digits)
        .substringSafe(0, 8);
    final groups = <String>['09'];
    if (subscriber.isNotEmpty) {
      groups.add(subscriber.substringSafe(0, 2));
    }
    if (subscriber.length > 2) {
      groups.add(subscriber.substringSafe(2, 5));
    }
    if (subscriber.length > 5) {
      groups.add(subscriber.substringSafe(5, 8));
    }
    return groups.join(' ');
  }

  static bool isFullName(String? value) {
    final name = normalizeName(value);
    return name.length >= 2 && name.length <= 100 && _namePattern.hasMatch(name);
  }

  static bool isEmail(String? value) {
    final email = (value ?? '').trim();
    return email.isNotEmpty && email.length <= 254 && _emailPattern.hasMatch(email);
  }

  static bool isPhone(String? value) {
    final phone = (value ?? '').trim();
    return RegExp(r'^09\d{8}$').hasMatch(phone) ||
        RegExp(r'^09 \d{2} \d{3} \d{3}$').hasMatch(phone);
  }

  static bool isIdentifier(String? value) => isEmail(value) || isPhone(value);

  static bool isStrongPassword(String? value) {
    final password = value ?? '';
    return password.length >= 8 &&
        password.length <= 128 &&
        RegExp(r'\p{L}', unicode: true).hasMatch(password) &&
        RegExp(r'\p{N}', unicode: true).hasMatch(password);
  }

  static bool isSafeText(
    String? value, {
    bool required = false,
    int min = 1,
    int max = 500,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return !required;
    return text.length >= min &&
        text.length <= max &&
        !_controlCharacters.hasMatch(text) &&
        _letterOrNumber.hasMatch(text);
  }

  static final List<TextInputFormatter> phoneFormatters = [
    SyrianPhoneInputFormatter(),
  ];

  static List<TextInputFormatter> limited(int length) => [
        LengthLimitingTextInputFormatter(length),
      ];
}

final class SyrianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return TextEditingValue.empty;

    final formatted = CustomerInputValidation.formatPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

extension on String {
  String substringSafe(int start, int end) {
    if (length <= start) return '';
    return substring(start, end > length ? length : end);
  }
}
