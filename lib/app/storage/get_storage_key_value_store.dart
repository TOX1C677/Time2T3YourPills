import 'package:get_storage/get_storage.dart';

import 'key_value_store.dart';

class GetStorageKeyValueStore implements KeyValueStore {
  GetStorageKeyValueStore([GetStorage? storage]) : _box = storage ?? GetStorage();

  final GetStorage _box;

  @override
  Future<String?> read(String key) async {
    final v = _box.read(key);
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  @override
  Future<void> write(String key, String value) async {
    await _box.write(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _box.remove(key);
  }
}
