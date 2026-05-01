import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/config/app_env.dart';

/// Сессия API: JWT и роль. Уведомляет [GoRouter] через [refreshListenable].
class AuthSession extends ChangeNotifier {
  AuthSession() {
    _dio = Dio(AppEnv.dioBaseOptions);
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
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onError: (err, handler) async {
          if (err.response?.statusCode != 401) {
            return handler.next(err);
          }
          final path = err.requestOptions.path;
          if (path.contains('/v1/auth/login') ||
              path.contains('/v1/auth/register') ||
              path.contains('/v1/auth/refresh') ||
              path.contains('/v1/auth/logout')) {
            return handler.next(err);
          }
          try {
            await refreshTokens();
            final clone = await _dio.fetch(err.requestOptions);
            return handler.resolve(clone);
          } catch (_) {
            return handler.next(err);
          }
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
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final role = json['role'];
    final email = json['email'];
    _accessToken = access is String ? access : access?.toString();
    _refreshToken = refresh is String ? refresh : refresh?.toString();
    _role = role is String ? role : role?.toString();
    _email = email is String ? email : email?.toString();
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

  /// Обновление пары токенов без рекурсии через основной [Dio].
  Future<void> refreshTokens() async {
    final rt = _refreshToken ?? await _storage.read(key: _kRefresh);
    if (rt == null || rt.isEmpty) {
      throw StateError('No refresh token');
    }
    final plain = Dio(AppEnv.dioBaseOptions);
    final res = await plain.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refresh_token': rt},
    );
    _applyTokenResponse(res.data!);
    await _persistTokens();
    notifyListeners();
  }

  Future<void> _clearLocalAuth() async {
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

  Future<void> logout() async {
    final rt = _refreshToken ?? await _storage.read(key: _kRefresh);
    if (rt != null && rt.isNotEmpty) {
      try {
        await _dio.post<void>('/v1/auth/logout', data: {'refresh_token': rt});
      } catch (_) {}
    }
    await _clearLocalAuth();
  }

  /// Безвозвратное удаление аккаунта на сервере и очистка локальных токенов.
  Future<void> deleteAccount() async {
    await _dio.delete<void>('/v1/users/me');
    await _clearLocalAuth();
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
