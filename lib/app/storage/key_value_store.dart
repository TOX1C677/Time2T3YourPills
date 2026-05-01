/// Абстракция локального KV-хранилища (снимки JSON, outbox, метаданные).
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);

  /// Удалить все ключи с заданным префиксом (смена аккаунта / полный сброс кэша).
  Future<void> removeKeysWithPrefix(String prefix);
}
