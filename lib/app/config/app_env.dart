/// Базовый URL API. По умолчанию — прод (`https://api.anti-toxic.ru`).
/// Локально / эмулятор: `--dart-define=API_BASE_URL=http://127.0.0.1:8000`
/// или `http://10.0.2.2:8000`.
abstract final class AppEnv {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.anti-toxic.ru',
  );
}
