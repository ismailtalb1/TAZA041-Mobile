import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  ApiConfig._();

  static const String _definedBase = String.fromEnvironment('TAZA_API_BASE');
  static const String mapTileUrl = String.fromEnvironment(
    'TAZA_MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static String get baseUrl {
    if (_definedBase.trim().isNotEmpty) {
      return _definedBase.trim().replaceFirst(RegExp(r'/$'), '');
    }
    if (kIsWeb) {
      final uri = Uri.base;
      final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1';
      if (isLocal && uri.port != 8000) return 'http://${uri.host}:8000/api';
      return '${uri.origin}/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static bool get hasSecureProductionEndpoint =>
      _definedBase.trim().isNotEmpty &&
      isValidProductionBase(_definedBase.trim());

  static bool isValidProductionBase(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.host != 'localhost' &&
        uri.host != '127.0.0.1';
  }

  static String assetUrl(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final apiUri = Uri.parse(baseUrl);
    final origin = '${apiUri.scheme}://${apiUri.authority}';
    return '$origin/${trimmed.replaceFirst(RegExp(r'^/+'), '')}';
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isTransient =>
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
    String? baseUrl,
  })  : _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/$'), ''),
        _http = httpClient ?? http.Client(),
        _storage = secureStorage ?? const FlutterSecureStorage();

  static const _tokenKey = 'taza_customer_token';
  final http.Client _http;
  final FlutterSecureStorage _storage;
  final String _baseUrl;
  final Map<String, Future<dynamic>> _inFlightGets = {};
  String? _token;
  int _tokenRevision = 0;

  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> restoreToken() async {
    _token = await _storage.read(key: _tokenKey);
    _tokenRevision++;
  }

  Future<void> saveToken(String value) async {
    _tokenRevision++;
    _token = value;
    await _storage.write(key: _tokenKey, value: value);
  }

  Future<bool> clearToken({String? expectedToken}) async {
    if (expectedToken != null && _token != expectedToken) return false;
    final revision = ++_tokenRevision;
    _token = null;
    await _storage.delete(key: _tokenKey);
    if (revision != _tokenRevision && _token != null) {
      await _storage.write(key: _tokenKey, value: _token!);
    }
    return true;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    final key = '${_token ?? 'guest'}|$path|${jsonEncode(query ?? const {})}';
    final running = _inFlightGets[key];
    if (running != null) return running;
    final future = request('GET', path, query: query);
    _inFlightGets[key] = future;
    unawaited(future.then<void>(
      (_) {
        if (identical(_inFlightGets[key], future)) _inFlightGets.remove(key);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_inFlightGets[key], future)) _inFlightGets.remove(key);
      },
    ));
    return future;
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      request('POST', path, body: body);

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      request('PUT', path, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) =>
      request('DELETE', path, body: body);

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final queryParameters = query == null
        ? null
        : <String, String>{
            for (final entry in query.entries)
              if (entry.value != null) entry.key: '${entry.value}',
          };
    final uri = Uri.parse('$_baseUrl${_normalizePath(path)}')
        .replace(queryParameters: queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (hasToken) 'Authorization': 'Bearer $_token',
    };

    final attempts = method == 'GET' ? 2 : 1;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await _send(
          method,
          uri,
          headers: headers,
          encodedBody: body == null ? null : jsonEncode(body),
          timeout: timeout,
        );
        return _decode(response);
      } on ApiException catch (error) {
        if (attempt == attempts || !error.isTransient) rethrow;
      } on TimeoutException {
        if (attempt == attempts) {
          throw const ApiException('انتهت مهلة الاتصال، حاول مرة أخرى.');
        }
      } on http.ClientException {
        if (attempt == attempts) {
          throw const ApiException(
              'تعذر الاتصال بالخادم. تحقق من الإنترنت وعنوان الـ API.');
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 180 * attempt));
    }
    throw const ApiException('تعذر تنفيذ الطلب.');
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    required String? encodedBody,
    required Duration timeout,
  }) {
    final request = switch (method) {
      'POST' => _http.post(uri, headers: headers, body: encodedBody),
      'PUT' => _http.put(uri, headers: headers, body: encodedBody),
      'DELETE' => _http.delete(uri, headers: headers, body: encodedBody),
      _ => _http.get(uri, headers: headers),
    };
    return request.timeout(timeout);
  }

  Future<dynamic> uploadImage(
    String path, {
    required List<int> bytes,
    required String filename,
    String? currentPassword,
  }) =>
      uploadMultipart(
        path,
        fields: {
          if (currentPassword?.isNotEmpty ?? false)
            'current_password': currentPassword!,
        },
        bytes: bytes,
        filename: filename,
      );

  Future<dynamic> uploadMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<int>? bytes,
    String? filename,
    String fileField = 'image',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl${_normalizePath(path)}'),
    );
    request.headers['Accept'] = 'application/json';
    if (hasToken) request.headers['Authorization'] = 'Bearer $_token';
    request.fields.addAll(fields);
    if (bytes != null && filename != null && filename.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
      );
    }
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return _decode(await http.Response.fromStream(streamed));
    } on TimeoutException {
      throw const ApiException(
          'استغرق رفع الصورة وقتًا طويلًا. حاول مرة أخرى.');
    } on http.ClientException {
      throw const ApiException('تعذر رفع الصورة بسبب مشكلة في الاتصال.');
    }
  }

  dynamic _decode(http.Response response) {
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) payload = decoded;
    } on FormatException {
      payload = null;
    }
    final success = response.statusCode >= 200 && response.statusCode < 300;
    if (!success || payload?['success'] == false) {
      final rawErrors = payload?['errors'];
      throw ApiException(
        payload?['message']?.toString() ??
            'تعذر تنفيذ الطلب (${response.statusCode}).',
        statusCode: response.statusCode,
        errors: rawErrors is Map<String, dynamic> ? rawErrors : null,
      );
    }
    return payload?.containsKey('data') == true ? payload!['data'] : payload;
  }

  String _normalizePath(String path) => path.startsWith('/') ? path : '/$path';

  void dispose() => _http.close();
}
