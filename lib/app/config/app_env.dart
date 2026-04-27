/// Сборка: `--dart-define=API_BASE_URL=…` (локально `http://127.0.0.1:8000` или эмулятор `http://10.0.2.2:8000`;
/// прод: см. README — `https://api.anti-toxic.ru`).
abstract final class AppEnv {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
