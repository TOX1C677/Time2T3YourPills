import 'package:dio/dio.dart';

/// Продовый API для Android-клиента (единственный хост, без `dart-define` и без локальных URL).
///
/// **Все HTTP к API** идут через [Dio] в [AuthSession]: основной экземпляр и отдельный для
/// `POST /v1/auth/refresh` (без рекурсии интерсепторов). Пути вида `/v1/...`.
///
/// Остальной код использует только `auth.dio` или методы [AuthSession] (`login`, `register`,
/// `fetchInviteCode`, …). Синк таблеток/профиля/outbox — [ApiRemoteDataSource] → тот же `_auth.dio`.
/// Прямых `Dio()`, `http`, `Uri.https` к своему API в `lib/` нет.
abstract final class AppEnv {
  static const String apiBaseUrl = 'https://api.anti-toxic.ru';

  static String get _apiOrigin => apiBaseUrl.replaceAll(RegExp(r'/$'), '');

  /// [BaseOptions] для любого клиентского [Dio] к этому API.
  static BaseOptions get dioBaseOptions => BaseOptions(
        baseUrl: _apiOrigin,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
}
