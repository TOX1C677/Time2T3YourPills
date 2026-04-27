import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/config/app_env.dart';

/// Сессия API: JWT и роль. Уведомляет [GoRouter] через [refreshListenable].
class AuthSession extends ChangeNotifier {
  AuthSession() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.apiBaseUrl.replaceAll(RegExp(r'/$'), ''),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = _accessToken;
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          return handler.next(options);
        },
      ),
    );
  }

  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kRole = 'auth.role';
  static const _kEmail = 'auth.email';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final Dio _dio;

  String? _accessToken;
  String? _refreshToken;
  String? _role;
  String? _email;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  String? get role => _role;

  String? get email => _email;

  Dio get dio => _dio;

  Future<void> restore() async {
    _accessToken = await _storage.read(key: _kAccess);
    _refreshToken = await _storage.read(key: _kRefresh);
    _role = await _storage.read(key: _kRole);
    _email = await _storage.read(key: _kEmail);
    notifyListeners();
  }

  Future<void> _persistTokens() async {
    if (_accessToken != null) {
      await _storage.write(key: _kAccess, value: _accessToken!);
    } else {
      await _storage.delete(key: _kAccess);
    }
    if (_refreshToken != null) {
      await _storage.write(key: _kRefresh, value: _refreshToken!);
    } else {
      await _storage.delete(key: _kRefresh);
    }
    if (_role != null) {
      await _storage.write(key: _kRole, value: _role!);
    } else {
      await _storage.delete(key: _kRole);
    }
    if (_email != null) {
      await _storage.write(key: _kEmail, value: _email!);
    } else {
      await _storage.delete(key: _kEmail);
    }
  }

  void _applyTokenResponse(Map<String, dynamic> json) {
    _accessToken = json['access_token'] as String?;
    _refreshToken = json['refresh_token'] as String?;
    _role = json['role'] as String?;
    _email = json['email'] as String?;
  }

  Future<void> login({required String email, required String password}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    _applyTokenResponse(res.data!);
    await _persistTokens();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {
        'email': email.trim(),
        'password': password,
        'display_name': displayName.trim(),
        'role': role,
      },
    );
    _applyTokenResponse(res.data!);
    await _persistTokens();
    notifyListeners();
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _role = null;
    _email = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kRole);
    await _storage.delete(key: _kEmail);
    notifyListeners();
  }

  Future<String> fetchInviteCode() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/patients/me/invite-code');
    return res.data!['token'] as String;
  }

  Future<void> linkPatientByToken(String token) async {
    await _dio.post<Map<String, dynamic>>(
      '/v1/caregiver/link-patient',
      data: {'token': token.trim()},
    );
  }

}
